#!/usr/bin/env bash
set -euo pipefail

# Check if perturbation number is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <perturbation_number> [extra_pytest_args...]" >&2
    echo "Example: $0 1" >&2
    echo "Example: $0 2 -v" >&2
    exit 1
fi

PERTURBATION_NUM="$1"
EXTRA_PYTEST_ARGS=("${@:2}")

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)
PERTURBATION_DIR="$REPO_ROOT/Perturbations"

# Check if perturbation Dockerfile exists
PERTURBATION_DOCKERFILE="$PERTURBATION_DIR/Dockerfile.${PERTURBATION_NUM}"
if [ ! -f "$PERTURBATION_DOCKERFILE" ]; then
    echo "Error: Perturbation Dockerfile not found: $PERTURBATION_DOCKERFILE" >&2
    echo "Available perturbations:" >&2
    ls -1 "$PERTURBATION_DIR"/Dockerfile.* 2>/dev/null | sed 's|.*/Dockerfile\.||' | sort -n || echo "  None found"
    exit 1
fi

IMAGE_TAG="browser-use-env:perturbation-${PERTURBATION_NUM}"

echo "[perturbation-${PERTURBATION_NUM}] Building image '$IMAGE_TAG' using $PERTURBATION_DOCKERFILE" >&2
docker build -t "$IMAGE_TAG" -f "$PERTURBATION_DOCKERFILE" "$REPO_ROOT"

PYTEST_CMD=("uv" "run" "pytest" "--numprocesses" "auto" "--ignore=tests/ci/test_radio_buttons.py" "--ignore=tests/ci/test_cloud_browser.py" "tests/ci")
if ((${#EXTRA_PYTEST_ARGS[@]} > 0)); then
  PYTEST_CMD+=("${EXTRA_PYTEST_ARGS[@]}")
fi

printf '[perturbation-%s] Running command in container: %q ' "$PERTURBATION_NUM" "${PYTEST_CMD[@]}"
printf '\n'

docker run --rm \
  --user root \
  --entrypoint /bin/bash \
  "$IMAGE_TAG" \
  -lc "cd /app && ${PYTEST_CMD[*]}"

