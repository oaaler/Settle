# Settle

An iPhone sleep-schedule app for parents of babies aged **0–24 months**. It predicts the next nap and bedtime from a simple **sleep-pressure model**, fitted to each baby.

[![CI](https://github.com/oaaler/Settle/actions/workflows/ci.yml/badge.svg)](https://github.com/oaaler/Settle/actions/workflows/ci.yml)
[![CodeQL](https://github.com/oaaler/Settle/actions/workflows/codeql.yml/badge.svg)](https://github.com/oaaler/Settle/actions/workflows/codeql.yml)

> Not medical advice. Settle gives general sleep-timing estimates and does not diagnose anything.

## Layout

| Path | What |
|---|---|
| `Packages/SettleCore` | The prediction engine: pure Swift with no dependencies, tested on Linux and macOS |
| `App/` | The SwiftUI iOS app. `project.yml` is the XcodeGen spec |
| `tools/calibrate` | Python tools that fit the model's settings to published sleep norms |
| `docs/research` | The sleep-science basis and calibration results |
| `SPEC.md` | Product spec |
| `docs/ci.md` | CI/CD, local setup and TestFlight secrets |

## Quick start

```sh
# Engine tests (any OS with Swift 6)
cd Packages/SettleCore && swift test

# App (macOS + Xcode)
brew install xcodegen
cd App && xcodegen generate && open Settle.xcodeproj
```
