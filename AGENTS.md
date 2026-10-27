# Handoff for coding agents

Read this first, then `SPEC.md`, `GLOSSARY.md` and `docs/research/sleep-science.md`.

## What we're building

**Settle** is an iPhone sleep-schedule app for parents, competing with Napper. Scope: babies **0–24 months only**. It predicts the next nap and bedtime from a two-process **sleep-pressure model**: pressure builds while awake and clears while asleep, and a body-clock threshold strengthens between 8 and 16 weeks. An age curve (`AgeCurve.v1`) is fitted to published sleep norms.

**Current phase: a web demo that proves the science.** The iOS app (`App/`) is **paused** until the owner signs off on the demo. The sign-off test is the owner's visual judgement, not a data backtest. Don't add new research.

| Part | Path | Stack |
|---|---|---|
| Engine | `Packages/SettleCore` | Pure Swift, no dependencies. `SleepPressureModel`, `Predictor`, `Simulator`, `DayPlanner` |
| API | `Server/` | Swift 6, Hummingbird 2, swift-openapi-generator. The contract is `Server/Sources/SettleAPI/openapi.yaml` (OpenAPI first) |
| Web | `web/` | Svelte 5, Vite, TypeScript, Tailwind 4, openapi-fetch, hand-rolled SVG charts. Two views: model showcase and try-a-day |
| Calibration | `tools/calibrate` | Python reference model plus a fitting script; exports the parity fixtures used by the Swift tests |
| iOS | `App/` | SwiftUI with XcodeGen; built only in CI (macOS runners) |

Decisions already made, so don't reopen them:
- Stateless, with no accounts and no tracking. Users enter data manually.
- English, with the browser's local time format; the theme follows the system.
- The UI shows model output only: no research ranges and no tuning sliders.
- Terms come from `GLOSSARY.md`, e.g. "sleep window" and "day plan".

## Setup

```sh
git clone https://github.com/oaaler/Settle.git && cd Settle
```

**Engine and API tests.** Any machine with Swift 6.4 works; on Linux without Swift, use podman:
```sh
podman run --rm -v "$PWD:/src:Z" -w /src/Packages/SettleCore docker.io/library/swift:6.4.1-noble swift test
podman run --rm -v "$PWD:/src:Z" -w /src/Server            docker.io/library/swift:6.4.1-noble swift test
```
If you get a module-cache error, delete the `.build` directory.

**Run the API locally** on :8080:
```sh
podman run --rm -v "$PWD:/src:Z" -w /src/Server -p 8080:8080 docker.io/library/swift:6.4.1-noble swift run SettleServer
# or the published image:
podman run --rm -p 8080:8080 ghcr.io/oaaler/settle-api:latest
curl localhost:8080/api/health
```

**Web, with hot reload.** Needs Node 24. Vite forwards `/api` to `$SETTLE_API` (default `http://localhost:8080`):
```sh
cd web && npm ci
npm run dev                 # http://localhost:5173
npm run check && npm test && npm run format:check   # what CI runs
npm run gen:api             # after editing openapi.yaml; CI fails if api-schema.d.ts drifts
```

**Both containers, built from source:** `podman compose up --build`, then open http://localhost:8080.

## Deployment (podman Quadlets)

The owner deploys with **podman Quadlets**. The units are in `deploy/quadlet/`:
- `settle.network`: a private network.
- `settle-api.container`: not published.
- `settle-web.container`: nginx on `127.0.0.1:8088`; it forwards `/api` to `http://settle-api:8080`.

Put the TLS reverse proxy in front of port 8088.

```sh
mkdir -p ~/.config/containers/systemd
cp deploy/quadlet/* ~/.config/containers/systemd/
systemctl --user daemon-reload
systemctl --user start settle-web          # pulls in settle-api and the network
loginctl enable-linger "$USER"             # keep running after logout
podman auto-update                         # or: systemctl --user enable --now podman-auto-update.timer
```

To check the units without installing them, run `QUADLET_UNIT_DIRS=deploy/quadlet /usr/lib/systemd/user-generators/podman-user-generator --user --dryrun`.

CI publishes `:latest` and `:sha-xxxxxxx` images to GHCR on every push to `main`, and both packages are public. Pin a `sha-` tag in the `.container` files if you need deploys you can reproduce.

## CI and conventions

GitHub Actions runs `ci.yml` with these jobs:
- core-linux
- server
- web
- ios on macos-26
- calibration: ruff checks, plus a fixture-drift check
- images: GHCR, `main` only

`codeql.yml` and `sonarqube.yml` (on push to `main`) also run. Dependabot covers every ecosystem in the repo.

- Pin GitHub Actions to a full commit SHA.
- Formatting: swift-format (line length 140), prettier, and ruff (line length 140).
- When you change the model, update the Python reference first. Then run `tools/calibrate/export_fixtures.py`, then make Swift match it. A parity test enforces this.
- Never commit secrets. These include `.gh_token`, `*.p8` and provisioning files.

## Known limits and possible next work

The free-running simulation gets some things wrong. At around 7 months it can put a late nap near 18:00–21:00 and give a night of about 9 h. This is a calibration limit (see `sleep-science.md` §6).

The planned v2 changes are an age-varying `gap`, a second circadian harmonic, and a free-run anchored to the wake time the parent enters. Wait for the owner to ask before starting v2 or iOS work.
