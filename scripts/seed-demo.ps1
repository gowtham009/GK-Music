$ErrorActionPreference = "Stop"

function New-SilentWavBytes {
  param(
    [int]$Seconds = 2,
    [int]$SampleRate = 44100,
    [int]$BitsPerSample = 16,
    [int]$Channels = 1
  )

  if ($Seconds -lt 1) { throw "Seconds must be >= 1" }
  if ($BitsPerSample -ne 16) { throw "Only 16-bit PCM supported" }
  if ($Channels -ne 1 -and $Channels -ne 2) { throw "Channels must be 1 or 2" }

  $bytesPerSample = $BitsPerSample / 8
  $blockAlign = $Channels * $bytesPerSample
  $byteRate = $SampleRate * $blockAlign
  $numSamples = $SampleRate * $Seconds
  $dataSize = $numSamples * $blockAlign

  $ms = New-Object System.IO.MemoryStream
  $bw = New-Object System.IO.BinaryWriter($ms)

  # RIFF header
  $bw.Write([Text.Encoding]::ASCII.GetBytes("RIFF"))
  $bw.Write([int] (36 + $dataSize))
  $bw.Write([Text.Encoding]::ASCII.GetBytes("WAVE"))

  # fmt chunk
  $bw.Write([Text.Encoding]::ASCII.GetBytes("fmt "))
  $bw.Write([int]16)              # PCM fmt chunk size
  $bw.Write([int16]1)             # PCM
  $bw.Write([int16]$Channels)
  $bw.Write([int]$SampleRate)
  $bw.Write([int]$byteRate)
  $bw.Write([int16]$blockAlign)
  $bw.Write([int16]$BitsPerSample)

  # data chunk
  $bw.Write([Text.Encoding]::ASCII.GetBytes("data"))
  $bw.Write([int]$dataSize)

  # Write silence (zeros)
  $silence = New-Object byte[] $dataSize
  $bw.Write($silence)

  $bw.Flush()
  $bytes = $ms.ToArray()
  $bw.Dispose()
  $ms.Dispose()
  return $bytes
}

function Ensure-DockerComposeUp {
  docker compose up -d | Out-Null
}

function Invoke-External {
  param(
    [Parameter(Mandatory = $true)]
    [string]$File,
    [Parameter(Mandatory = $true)]
    [string[]]$Args
  )
  & $File @Args
  if ($LASTEXITCODE -ne 0) {
    throw "Command failed ($LASTEXITCODE): $File $($Args -join ' ')"
  }
}

function Wait-ForHttpOk {
  param(
    [string]$Url,
    [int]$TimeoutSeconds = 120
  )
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    try {
      $code = (curl.exe -sS -o NUL -w "%{http_code}" $Url)
      if ($code -eq "200") { return }
    } catch {
      # ignore
    }
    Start-Sleep -Seconds 2
  }
  throw "Timed out waiting for HTTP 200: $Url"
}

function Wait-ForGatewayAuthRoute {
  param(
    [int]$TimeoutSeconds = 120
  )
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $body = '{"email":"_probe@gkmusic.local","password":"password123"}'
  while ((Get-Date) -lt $deadline) {
    try {
      $code = (curl.exe -sS -o NUL -w "%{http_code}" -H "Content-Type: application/json" -X POST -d $body "http://localhost:8080/auth/login")
      if ($code -ne "503" -and $code -ne "000") { return }
    } catch {
      # ignore
    }
    Start-Sleep -Seconds 2
  }
  throw "Timed out waiting for gateway to route /auth/** (no longer 503)"
}

function Upload-ToMinio {
  param(
    [string]$LocalDir,
    [string]$Bucket,
    [string]$Prefix
  )

  $localDirAbs = (Resolve-Path $LocalDir).Path
  $prefixNorm = $Prefix.Trim("/")

  # Use the existing minio-init service (minio/mc image) but override entrypoint for custom commands.
  $cmd = @'
set -eu
mc alias set local http://minio:9000 $MINIO_ACCESS_KEY $MINIO_SECRET_KEY >/dev/null
mc mb --ignore-existing local/__BUCKET__ >/dev/null
# Copy contents of /seed into the prefix (not a nested /seed directory)
mc cp --recursive /seed/* local/__BUCKET__/__PREFIX__/ >/dev/null
'@
  $cmd = $cmd.Replace("__BUCKET__", $Bucket).Replace("__PREFIX__", $prefixNorm)

  Invoke-External "docker" @(
    "compose","run","--rm",
    "-v","${localDirAbs}:/seed:ro",
    "-e","MINIO_ACCESS_KEY=minioadmin",
    "-e","MINIO_SECRET_KEY=minioadmin",
    "--entrypoint","sh",
    "minio-init",
    "-c",$cmd
  ) | Out-Null
}

function Seed-MusicDbSongs {
  param(
    [array]$Songs
  )

  $values = ($Songs | ForEach-Object {
    $id = $_.id
    $title = $_.title.Replace("'", "''")
    $artist = $_.artist.Replace("'", "''")
    $album = $_.album.Replace("'", "''")
    $duration = [int]$_.duration_seconds
    $objectKey = $_.object_key.Replace("'", "''")
    "('$id','$title','$artist','$album',$duration,'$objectKey')"
  }) -join ",`n"

  $sql = @"
insert into songs (id, title, artist, album, duration_seconds, object_key)
values
$values
on conflict (id) do update set
  title = excluded.title,
  artist = excluded.artist,
  album = excluded.album,
  duration_seconds = excluded.duration_seconds,
  object_key = excluded.object_key;
"@

  Invoke-External "docker" @("compose","exec","-T","postgres","psql","-U","postgres","-d","musicdb","-v","ON_ERROR_STOP=1","-c",$sql) | Out-Null
}

function Get-OrCreateDemoUserToken {
  param(
    [string]$Email,
    [string]$Password,
    [string]$DisplayName
  )

  $registerBody = @{ email = $Email; password = $Password; displayName = $DisplayName } | ConvertTo-Json
  try {
    $resp = Invoke-RestMethod -Uri "http://localhost:8080/auth/register" -Method Post -ContentType "application/json" -Body $registerBody
    return $resp.accessToken
  } catch {
    # If already exists, login instead.
    $loginBody = @{ email = $Email; password = $Password } | ConvertTo-Json
    $resp2 = Invoke-RestMethod -Uri "http://localhost:8080/auth/login" -Method Post -ContentType "application/json" -Body $loginBody
    return $resp2.accessToken
  }
}

function Demo-Flow {
  param(
    [string]$Token
  )

  $headers = @{ Authorization = "Bearer $Token" }

  # Ensure profile exists
  Invoke-RestMethod -Uri "http://localhost:8080/users/me" -Headers $headers -Method Get | Out-Null

  # List songs, create playlist, favorite first song
  $songsPage = Invoke-RestMethod -Uri "http://localhost:8080/music/songs?page=0&size=20" -Headers $headers -Method Get
  $seedSong = $songsPage.content | Where-Object { $_.title -eq "Sample Track 1" } | Select-Object -First 1
  if (-not $seedSong) { throw "Seed song not found (expected title 'Sample Track 1')" }
  $firstSongId = $seedSong.id

  $pl = Invoke-RestMethod -Uri "http://localhost:8080/playlists" -Headers $headers -Method Post -ContentType "application/json" -Body (@{ name = "My Playlist" } | ConvertTo-Json)
  Invoke-RestMethod -Uri "http://localhost:8080/playlists/$($pl.id)/items/$firstSongId" -Headers $headers -Method Post | Out-Null
  try {
    Invoke-RestMethod -Uri "http://localhost:8080/favorites/$firstSongId" -Headers $headers -Method Post | Out-Null
  } catch {
    # Ignore if already favorited
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode.value__ -eq 409) {
      # no-op
    } else {
      throw
    }
  }

  # Return a presigned stream URL for the first song
  $stream = Invoke-RestMethod -Uri "http://localhost:8080/music/songs/$firstSongId/stream-url" -Headers $headers -Method Get
  return @{
    firstSongId = $firstSongId
    streamUrl = $stream.url
    playlistId = $pl.id
  }
}

Ensure-DockerComposeUp
Wait-ForHttpOk -Url "http://localhost:8761/eureka/apps" -TimeoutSeconds 120
Wait-ForHttpOk -Url "http://localhost:8080/actuator/health" -TimeoutSeconds 120
Wait-ForHttpOk -Url "http://localhost:8083/music/health" -TimeoutSeconds 180
Wait-ForGatewayAuthRoute -TimeoutSeconds 120

$tmp = Join-Path $env:TEMP ("gk-music-seed-" + [Guid]::NewGuid().ToString("n"))
New-Item -ItemType Directory -Path $tmp | Out-Null

try {
  $seedPrefix = "seed"
  $songs = @(
    @{ id = "11111111-1111-1111-1111-111111111111"; title = "Sample Track 1"; artist = "GK Music"; album = "Seed"; duration_seconds = 2; object_key = "$seedPrefix/sample-1.wav" },
    @{ id = "22222222-2222-2222-2222-222222222222"; title = "Sample Track 2"; artist = "GK Music"; album = "Seed"; duration_seconds = 2; object_key = "$seedPrefix/sample-2.wav" },
    @{ id = "33333333-3333-3333-3333-333333333333"; title = "Sample Track 3"; artist = "GK Music"; album = "Seed"; duration_seconds = 2; object_key = "$seedPrefix/sample-3.wav" },
    @{ id = "44444444-4444-4444-4444-444444444444"; title = "Sample Track 4"; artist = "GK Music"; album = "Seed"; duration_seconds = 2; object_key = "$seedPrefix/sample-4.wav" },
    @{ id = "55555555-5555-5555-5555-555555555555"; title = "Sample Track 5"; artist = "GK Music"; album = "Seed"; duration_seconds = 2; object_key = "$seedPrefix/sample-5.wav" }
  )

  # Create local wav files
  $i = 1
  foreach ($s in $songs) {
    $bytes = New-SilentWavBytes -Seconds 2
    $path = Join-Path $tmp ("sample-$i.wav")
    [System.IO.File]::WriteAllBytes($path, $bytes)
    $i++
  }

  Upload-ToMinio -LocalDir $tmp -Bucket "gk-music" -Prefix $seedPrefix
  Seed-MusicDbSongs -Songs $songs

  $token = Get-OrCreateDemoUserToken -Email "demo@gkmusic.local" -Password "password123" -DisplayName "Demo"
  $result = Demo-Flow -Token $token

  "Seed complete."
  "Gateway URL: http://localhost:8080"
  "Demo user: demo@gkmusic.local / password123"
  "First song stream URL (presigned): $($result.streamUrl)"
  "Playlist ID: $($result.playlistId)"
} finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
