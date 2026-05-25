# Azure Container Apps deployment (GK Music)

This folder contains a pragmatic deployment path for this repo to **Azure Container Apps** using **Azure CLI**.

What it creates:
- Resource group
- Azure Container Registry (ACR)
- Container Apps environment
- Container Apps for: `postgres`, `minio`, `discovery-service`, `auth-service`, `user-service`, `music-service`, `api-gateway`

## Prereqs

- Azure CLI (`az`) installed
- You are logged in: `az login`
- Permission to create resources in your subscription

## Deploy

From repo root:

```powershell
./infra/azure/containerapps/deploy.ps1 -ResourceGroup gk-music-rg -Location eastus -NamePrefix gkmusic -JwtSecret "replace-with-a-32+char-secret"
```

After the script finishes, it prints the API Gateway URL.

Notes:
- This is a **dev/demo** deployment. `postgres` and `minio` run as containers (not managed services) and are exposed publicly where needed.
- The `JWT_SECRET` must match across gateway + services.

