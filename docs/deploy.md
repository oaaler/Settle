# Deploying the web demo

Two containers, both published to GHCR by CI on every push to `main`:

| Image | What | Listens on |
|---|---|---|
| `ghcr.io/oaaler/settle-api` | Stateless sleep-model API | 8080 (internal only) |
| `ghcr.io/oaaler/settle-web` | nginx serving the static frontend; forwards `/api` to the API container | 8080 |

The browser only ever talks to the web container, so there's one public hostname and no CORS. Nothing is stored: there's no database and no volumes.

## On your server

```yaml
# compose.yaml
services:
  api:
    image: ghcr.io/oaaler/settle-api:latest
    restart: unless-stopped
    read_only: true
  web:
    image: ghcr.io/oaaler/settle-web:latest
    depends_on: [api]
    restart: unless-stopped
    ports:
      - "127.0.0.1:8088:8080"   # put your reverse proxy (TLS) in front of this
    # environment:
    #   API_UPSTREAM: http://api:8080   # change if the API service has another name
```

```sh
docker compose pull && docker compose up -d
```

Point your reverse proxy at `127.0.0.1:8088`. To update, run `pull` + `up -d` again, or pin a `sha-xxxxxxx` tag for reproducible deploys.

If `pull` is denied, the GHCR packages are still private: open each package on GitHub → *Package settings* → *Change visibility* → Public (or `docker login ghcr.io` with a token that has `read:packages`).

## What the web container sends

Headers: a strict CSP (`default-src 'self'`), `X-Content-Type-Options`, `Referrer-Policy: no-referrer` and a restrictive `Permissions-Policy`. Hashed assets are cached for a year; `index.html` uses `no-cache`. No analytics or cookies.
