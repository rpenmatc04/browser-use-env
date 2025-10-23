#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${1:-browser-use-env:gold}"
EXTRA_PYTEST_ARGS=("${@:2}")

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)

echo "[gold-standard] Building image '$IMAGE_TAG' using $REPO_ROOT/Dockerfile" >&2
docker build -t "$IMAGE_TAG" -f "$REPO_ROOT/Dockerfile" "$REPO_ROOT"

PYTEST_CMD=("uv" "run" "pytest" "--numprocesses" "auto" "--ignore=tests/ci/test_radio_buttons.py" "tests/ci")
if ((${#EXTRA_PYTEST_ARGS[@]} > 0)); then
  PYTEST_CMD+=("${EXTRA_PYTEST_ARGS[@]}")
fi

printf '[gold-standard] Running command in container: %q ' "${PYTEST_CMD[@]}"
printf '\n'

docker run --rm \
  --user root \
  --entrypoint /bin/bash \
  "$IMAGE_TAG" \
  -lc "cd /app && ${PYTEST_CMD[*]}"
