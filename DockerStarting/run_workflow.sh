#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DATASET_DIR="$ROOT_DIR/DockerStarting"

read -r -d '' USAGE <<'USAGE'
Usage: run_workflow.sh [--start-only N]

Build each Dockerfile in DockerStarting/ and run its default command.
The optional --start-only flag limits execution to a specific perturbed
Dockerfile number (1-5). Without the flag the script processes the gold
image followed by every perturbed variant.
USAGE

if [[ ${1:-} == "--help" ]]; then
  echo "$USAGE"
  exit 0
fi

if [[ ${1:-} == "--start-only" ]]; then
  if [[ -z ${2:-} ]]; then
    echo "error: --start-only requires a Dockerfile number" >&2
    exit 1
  fi
  if [[ ! ${2} =~ ^[1-5]$ ]]; then
    echo "error: --start-only expects a value between 1 and 5" >&2
    exit 1
  fi
  TARGETS=("start${2}")
else
  TARGETS=("gold" "start1" "start2" "start3" "start4" "start5")
fi

declare -A RESULTS=()

for target in "${TARGETS[@]}"; do
  file="$DATASET_DIR/Dockerfile.${target}"
  tag="browser-use-${target}"
  echo "==> Building ${file}" >&2
  if ! docker build -f "$file" -t "$tag" "$ROOT_DIR"; then
    RESULTS["$target"]="build failed"
    continue
  fi

  echo "==> Running ${tag}" >&2
  if docker run --rm "$tag"; then
    RESULTS["$target"]="passed"
  else
    RESULTS["$target"]="tests failed"
  fi
  echo >&2
done

echo "Summary:" >&2
for target in "${TARGETS[@]}"; do
  result=${RESULTS[$target]:-"not run"}
  printf '  %-7s %s\n' "$target" "$result"
done
