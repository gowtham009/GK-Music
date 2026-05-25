# GK Music (Wynk-like) — Spring Boot Microservices

This repository is a working microservices backend for a Wynk Music–style application (authentication, user profile, song catalog, search, playlists, favorites, play history) with local infrastructure and production-style observability (metrics, tracing, dashboards, alerts).

## Architecture (modules)

- `discovery-service` — Eureka service discovery (`:8761`)
- `api-gateway` — Spring Cloud Gateway entrypoint + JWT verification (`:8080`)
- `auth-service` — Register/login + JWT minting (PostgreSQL + Flyway) (`:8081`)
- `user-service` — User profile (PostgreSQL + Flyway), secured by JWT (`:8082`)
- `music-service` — Songs, search, playlists, favorites, play history; MinIO presigned stream URLs (PostgreSQL + Flyway) (`:8083`)

## Features (functional)

- Auth
  - `POST /auth/register` → creates an auth user + returns JWT
  - `POST /auth/login` → returns JWT
- Users
  - `GET /users/me` → returns (and auto-creates) profile for current JWT subject
  - `PUT /users/me` → updates display name
- Music
  - `GET /music/songs` and `GET /music/songs/{id}`
  - `GET /music/songs/{id}/stream-url` → presigned MinIO URL
  - `GET /search?q=...`
  - Playlists: `GET/POST /playlists`, `GET /playlists/{id}`, `POST /playlists/{id}/items/{songId}`, `DELETE /playlists/{id}`
  - Favorites: `GET /favorites`, `POST/DELETE /favorites/{songId}`
  - Playback history: `POST /music/songs/{id}/play`, `GET /music/recently-played`

## Observability (metrics, traces, alerts)

- Spring Boot Actuator + Micrometer Prometheus metrics on each service: `/actuator/prometheus`
- Distributed tracing via Micrometer Tracing → OTLP export (Tempo)
- Prometheus scrapes all services and evaluates alert rules
- Grafana is provisioned with Prometheus + Tempo datasources and an overview dashboard
- Alertmanager is included with a placeholder receiver config (customize for email/Slack/webhook)

## Quick start (Docker Compose)

Prerequisites:
- Docker + Docker Compose

Run:
- `docker compose up --build`

URLs:
- API Gateway: `http://localhost:8080`
- Eureka: `http://localhost:8761`
- Grafana: `http://localhost:3000` (anonymous admin enabled for local)
- Prometheus: `http://localhost:9090`
- Alertmanager: `http://localhost:9093`
- MinIO: `http://localhost:9001` (user/pass `minioadmin` / `minioadmin`)

## API usage (example)

1) Register:
- `POST http://localhost:8080/auth/register`
  - Body:
    - `{"email":"me@example.com","password":"password123","displayName":"Me"}`

2) Use the returned token:
- `Authorization: Bearer <accessToken>`

3) Call secured endpoints:
- `GET http://localhost:8080/users/me`
- `GET http://localhost:8080/music/songs`
- `GET http://localhost:8080/search?q=sample`

## Configuration knobs

Common env vars used by services:
- `EUREKA_URL` (default `http://localhost:8761/eureka`)
- `JWT_SECRET` (shared HMAC secret across gateway + resource services)
- `OTLP_ENDPOINT` (default `http://localhost:4318/v1/traces`)

Databases (Compose defaults):
- Auth DB: `AUTH_DB_URL`, `AUTH_DB_USER`, `AUTH_DB_PASSWORD`
- User DB: `USER_DB_URL`, `USER_DB_USER`, `USER_DB_PASSWORD`
- Music DB: `MUSIC_DB_URL`, `MUSIC_DB_USER`, `MUSIC_DB_PASSWORD`

MinIO (music-service):
- `MINIO_URL`, `MINIO_ACCESS_KEY`, `MINIO_SECRET_KEY`, `MINIO_BUCKET`

## Notes / Next steps

- Replace symmetric `JWT_SECRET` with an OAuth2 Authorization Server + JWKS for production.
- Add rate-limits and request validation at the gateway.
- Add a real log pipeline (e.g., Promtail → Loki) if you want centralized logs beyond console output.
- Wire `infra/alertmanager/alertmanager.yml` to Slack/email/webhooks for real alert delivery.

