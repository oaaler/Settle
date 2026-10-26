# CI/CD

| Workflow | When it runs | What it does |
|---|---|---|
| `ci.yml` | push to `main`, every PR | **API server:** swift-format lint and tests. **Web:** checks the generated API types match `openapi.yaml`, then prettier, svelte-check, vitest and build. **Images (main only):** publishes `ghcr.io/oaaler/settle-api` and `settle-web` (`latest` + short SHA). **SettleCore (Linux):** swift-format lint plus tests in `swift:6.4.1-noble`. **iOS app:** on `macos-26` with Xcode 26.6, runs SettleCore tests, generates the project with XcodeGen, builds and tests on a simulator. **Calibration tools:** ruff, and checks that the Swift test fixtures match `curve.json`. |
| `codeql.yml` | push, PR, weekly | CodeQL `security-and-quality` scans for Swift, TypeScript, Python and GitHub Actions |
| `sonarqube.yml` | push to `main` | SonarQube scan using repo secrets `SONAR_URL` and `SONAR_KEY` (the token). Project key `Settle` is set in `sonar-project.properties` |
| `release.yml` | tag `v*` or run manually | Archives, signs and uploads to **TestFlight** |
| Dependabot | weekly / monthly | Updates GitHub Actions (pinned to SHAs), Swift packages (engine and server), npm, Docker base images and the Python tools |

## Local development

- **Web demo:** `podman compose up --build`, then open http://localhost:8080. For hot reload, run `cd web && npm run dev` (it forwards `/api` to `localhost:8080`, or to `$SETTLE_API`).
- **API contract:** edit `Server/Sources/SettleAPI/openapi.yaml`, then run `cd web && npm run gen:api`. The Swift side regenerates at build time.

- **Engine (any OS):** `cd Packages/SettleCore && swift test`. On Linux without a native toolchain:
  `podman run --rm -v "$PWD:/src:Z" -w /src/Packages/SettleCore swift:6.4.1-noble swift test`
- **App (macOS only):** `brew install xcodegen && cd App && xcodegen generate && open Settle.xcodeproj`.
  The `.xcodeproj` is generated and git-ignored; edit `App/project.yml` instead.
- **Calibration:** `pip install -r tools/calibrate/requirements.txt && python3 tools/calibrate/calibrate.py`,
  then `python3 tools/calibrate/export_fixtures.py`. Copy the new constants into `AgeCurve.v1`.

## Setting up TestFlight releases (one-time)

1. Join the Apple Developer Program and create the app in App Store Connect with bundle ID `com.oaaler.settle` (change it in `App/project.yml` if you want a different one).
2. App Store Connect → Users and Access → Integrations → **App Store Connect API** → create a key with the **App Manager** role. Download the `.p8` file; it can only be downloaded once.
3. GitHub → Settings → Environments → create **`testflight`** (optionally require your approval). Add these secrets:
   - `APP_STORE_CONNECT_KEY_ID`
   - `APP_STORE_CONNECT_ISSUER_ID`
   - `APP_STORE_CONNECT_KEY_P8_BASE64`: the output of `base64 -w0 AuthKey_XXXX.p8`
   - `APPLE_TEAM_ID`
4. Push a tag (`git tag v0.1.0 && git push --tags`). The build number is the workflow run number.
