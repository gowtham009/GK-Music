param(
  [Parameter(Mandatory = $true)]
  [string] $ResourceGroup,

  [Parameter(Mandatory = $true)]
  [string] $Location,

  [Parameter(Mandatory = $true)]
  [string] $NamePrefix,

  [Parameter(Mandatory = $true)]
  [string] $JwtSecret,

  [string] $ImageTag = "latest",

  [string] $PostgresSuperPassword = "postgres",

  [string] $MinioRootUser = "minioadmin",

  [string] $MinioRootPassword = "minioadmin",

  [string] $MinioBucket = "gk-music"
)

$ErrorActionPreference = "Stop"

function Require-Command([string] $cmd) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    throw "Required command not found on PATH: $cmd"
  }
}

Require-Command "az"

function Wait-JobExecutionSucceeded(
  [string] $JobName,
  [string] $ExecutionName,
  [int] $TimeoutSec = 600
) {
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  while ((Get-Date) -lt $deadline) {
    $status = (az containerapp job execution show -g $ResourceGroup -n $JobName --job-execution-name $ExecutionName --query properties.status -o tsv).Trim()
    if ($status -eq "Succeeded") { return }
    if ($status -eq "Failed") { throw "Job execution failed: $JobName / $ExecutionName" }
    Start-Sleep -Seconds 5
  }
  throw "Timed out waiting for job execution: $JobName / $ExecutionName"
}

if ($JwtSecret.Length -lt 32) {
  throw "JwtSecret must be at least 32 characters (you passed $($JwtSecret.Length))."
}

$prefix = ($NamePrefix.ToLower() -replace "[^a-z0-9]", "")
if ($prefix.Length -lt 3) {
  throw "NamePrefix becomes too short after sanitizing. Use something like 'gkmusic'."
}

$suffix = (Get-Random -Minimum 10000 -Maximum 99999)
$acrName = ($prefix + $suffix)
if ($acrName.Length -gt 50) { $acrName = $acrName.Substring(0, 50) }

$envName = ($prefix + "-env-" + $suffix)
if ($envName.Length -gt 32) { $envName = $envName.Substring(0, 32) }

Write-Host "Resource group: $ResourceGroup ($Location)"
az group create -n $ResourceGroup -l $Location -o none

Write-Host "Creating ACR: $acrName"
az acr create -g $ResourceGroup -n $acrName --sku Basic --admin-enabled true -o none

$acrLoginServer = (az acr show -g $ResourceGroup -n $acrName --query loginServer -o tsv).Trim()
$acrUsername = (az acr credential show -g $ResourceGroup -n $acrName --query username -o tsv).Trim()
$acrPassword = (az acr credential show -g $ResourceGroup -n $acrName --query "passwords[0].value" -o tsv).Trim()

Write-Host "Creating Container Apps environment: $envName"
az containerapp env create -g $ResourceGroup -n $envName -l $Location -o none

Write-Host "Building/pushing service images in ACR (this runs in Azure via az acr build)"
az acr build -r $acrName -t "discovery-service:$ImageTag" -f "discovery-service/Dockerfile" . -o none
az acr build -r $acrName -t "api-gateway:$ImageTag" -f "api-gateway/Dockerfile" . -o none
az acr build -r $acrName -t "auth-service:$ImageTag" -f "auth-service/Dockerfile" . -o none
az acr build -r $acrName -t "user-service:$ImageTag" -f "user-service/Dockerfile" . -o none
az acr build -r $acrName -t "music-service:$ImageTag" -f "music-service/Dockerfile" . -o none

Write-Host "Creating postgres (internal TCP ingress on 5432)"
az containerapp create -g $ResourceGroup -n "postgres" `
  --environment $envName `
  --image "postgres:16" `
  --ingress internal --transport tcp --target-port 5432 `
  --min-replicas 1 --max-replicas 1 `
  --env-vars "POSTGRES_PASSWORD=$PostgresSuperPassword" `
  -o none

Write-Host "Initializing Postgres roles and databases (auth/user/music)"
$dbInitCmd = @"
set -e
export PGPASSWORD='$PostgresSuperPassword'
until pg_isready -h postgres -U postgres >/dev/null 2>&1; do
  echo 'waiting for postgres...'
  sleep 2
done

psql -h postgres -U postgres -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='auth'" | grep -q 1 || psql -h postgres -U postgres -d postgres -c "CREATE ROLE auth LOGIN PASSWORD 'auth';"
psql -h postgres -U postgres -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='user'" | grep -q 1 || psql -h postgres -U postgres -d postgres -c "CREATE ROLE \\"user\\" LOGIN PASSWORD 'user';"
psql -h postgres -U postgres -d postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='music'" | grep -q 1 || psql -h postgres -U postgres -d postgres -c "CREATE ROLE music LOGIN PASSWORD 'music';"

psql -h postgres -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='authdb'" | grep -q 1 || psql -h postgres -U postgres -d postgres -c "CREATE DATABASE authdb OWNER auth;"
psql -h postgres -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='userdb'" | grep -q 1 || psql -h postgres -U postgres -d postgres -c "CREATE DATABASE userdb OWNER \\"user\\";"
psql -h postgres -U postgres -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='musicdb'" | grep -q 1 || psql -h postgres -U postgres -d postgres -c "CREATE DATABASE musicdb OWNER music;"
"@.Trim()

# Use a one-off job so we don't need interactive exec.
az containerapp job create -g $ResourceGroup -n "db-init" `
  --environment $envName `
  --trigger-type Manual `
  --replica-timeout 600 `
  --replica-retry-limit 3 `
  --replica-completion-count 1 `
  --parallelism 1 `
  --image "postgres:16" `
  --command "/bin/sh" `
  --args "-c" $dbInitCmd `
  -o none

$dbExecName = (az containerapp job start -g $ResourceGroup -n "db-init" --query name -o tsv).Trim()
Wait-JobExecutionSucceeded -JobName "db-init" -ExecutionName $dbExecName -TimeoutSec 600

Write-Host "Creating minio (external HTTP ingress on 9000)"
az containerapp create -g $ResourceGroup -n "minio" `
  --environment $envName `
  --image "minio/minio:RELEASE.2024-06-11T03-13-30Z" `
  --ingress external --transport http --target-port 9000 --allow-insecure true `
  --min-replicas 1 --max-replicas 1 `
  --env-vars "MINIO_ROOT_USER=$MinioRootUser" "MINIO_ROOT_PASSWORD=$MinioRootPassword" `
  --command "minio" `
  --args "server" "/data" "--console-address" ":9001" `
  -o none

$minioFqdn = (az containerapp show -g $ResourceGroup -n "minio" --query properties.configuration.ingress.fqdn -o tsv).Trim()
if (-not $minioFqdn) { throw "Could not resolve MinIO FQDN from containerapp show output." }

Write-Host "Initializing MinIO bucket: $MinioBucket"
$minioInitCmd = @"
set -e
echo "Waiting for MinIO at http://minio ..."
until mc alias set local "http://minio" "$MinioRootUser" "$MinioRootPassword" >/dev/null 2>&1; do
  sleep 2
done
mc mb --ignore-existing "local/$MinioBucket"
"@.Trim()

az containerapp job create -g $ResourceGroup -n "minio-init" `
  --environment $envName `
  --trigger-type Manual `
  --replica-timeout 300 `
  --replica-retry-limit 3 `
  --replica-completion-count 1 `
  --parallelism 1 `
  --image "minio/mc:RELEASE.2024-06-12T14-34-03Z" `
  --command "/bin/sh" `
  --args "-c" $minioInitCmd `
  -o none

$minioExecName = (az containerapp job start -g $ResourceGroup -n "minio-init" --query name -o tsv).Trim()
Wait-JobExecutionSucceeded -JobName "minio-init" -ExecutionName $minioExecName -TimeoutSec 300

# In Container Apps, HTTP ingress is reached via port 80/443. Call by app name, no port.
$eurekaUrl = "http://discovery-service/eureka"

Write-Host "Creating discovery-service (internal HTTP ingress on 8761)"
az containerapp create -g $ResourceGroup -n "discovery-service" `
  --environment $envName `
  --image "$acrLoginServer/discovery-service:$ImageTag" `
  --ingress internal --transport http --target-port 8761 `
  --registry-server $acrLoginServer --registry-username $acrUsername --registry-password $acrPassword `
  --min-replicas 1 --max-replicas 1 `
  -o none

Write-Host "Creating auth-service (internal HTTP ingress on 8081)"
az containerapp create -g $ResourceGroup -n "auth-service" `
  --environment $envName `
  --image "$acrLoginServer/auth-service:$ImageTag" `
  --ingress internal --transport http --target-port 8081 `
  --registry-server $acrLoginServer --registry-username $acrUsername --registry-password $acrPassword `
  --min-replicas 1 --max-replicas 1 `
  --env-vars `
    "EUREKA_URL=$eurekaUrl" `
    "EUREKA_INSTANCE_HOSTNAME=auth-service" `
    "EUREKA_INSTANCE_NONSECUREPORT=80" `
    "AUTH_DB_URL=jdbc:postgresql://postgres:5432/authdb" `
    "AUTH_DB_USER=auth" `
    "AUTH_DB_PASSWORD=auth" `
    "JWT_SECRET=$JwtSecret" `
  -o none

Write-Host "Creating user-service (internal HTTP ingress on 8082)"
az containerapp create -g $ResourceGroup -n "user-service" `
  --environment $envName `
  --image "$acrLoginServer/user-service:$ImageTag" `
  --ingress internal --transport http --target-port 8082 `
  --registry-server $acrLoginServer --registry-username $acrUsername --registry-password $acrPassword `
  --min-replicas 1 --max-replicas 1 `
  --env-vars `
    "EUREKA_URL=$eurekaUrl" `
    "EUREKA_INSTANCE_HOSTNAME=user-service" `
    "EUREKA_INSTANCE_NONSECUREPORT=80" `
    "USER_DB_URL=jdbc:postgresql://postgres:5432/userdb" `
    "USER_DB_USER=user" `
    "USER_DB_PASSWORD=user" `
    "JWT_SECRET=$JwtSecret" `
  -o none

Write-Host "Creating music-service (internal HTTP ingress on 8083)"
az containerapp create -g $ResourceGroup -n "music-service" `
  --environment $envName `
  --image "$acrLoginServer/music-service:$ImageTag" `
  --ingress internal --transport http --target-port 8083 `
  --registry-server $acrLoginServer --registry-username $acrUsername --registry-password $acrPassword `
  --min-replicas 1 --max-replicas 1 `
  --env-vars `
    "EUREKA_URL=$eurekaUrl" `
    "EUREKA_INSTANCE_HOSTNAME=music-service" `
    "EUREKA_INSTANCE_NONSECUREPORT=80" `
    "MUSIC_DB_URL=jdbc:postgresql://postgres:5432/musicdb" `
    "MUSIC_DB_USER=music" `
    "MUSIC_DB_PASSWORD=music" `
    "JWT_SECRET=$JwtSecret" `
    "MINIO_URL=http://$minioFqdn" `
    "MINIO_ACCESS_KEY=$MinioRootUser" `
    "MINIO_SECRET_KEY=$MinioRootPassword" `
    "MINIO_BUCKET=$MinioBucket" `
  -o none

Write-Host "Creating api-gateway (external HTTP ingress on 8080)"
az containerapp create -g $ResourceGroup -n "api-gateway" `
  --environment $envName `
  --image "$acrLoginServer/api-gateway:$ImageTag" `
  --ingress external --transport http --target-port 8080 --allow-insecure true `
  --registry-server $acrLoginServer --registry-username $acrUsername --registry-password $acrPassword `
  --min-replicas 1 --max-replicas 1 `
  --env-vars `
    "EUREKA_URL=$eurekaUrl" `
    "EUREKA_INSTANCE_HOSTNAME=api-gateway" `
    "EUREKA_INSTANCE_NONSECUREPORT=80" `
    "JWT_SECRET=$JwtSecret" `
  --query properties.configuration.ingress.fqdn -o tsv

$gatewayFqdn = (az containerapp show -g $ResourceGroup -n api-gateway --query properties.configuration.ingress.fqdn -o tsv).Trim()
Write-Host ""
Write-Host "Done."
Write-Host "API Gateway URL (HTTP): http://$gatewayFqdn"
