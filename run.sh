#!/usr/bin/env bash
# Builds and launches Pyno.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
./scripts/build-app.sh
open dist/Pyno.app
