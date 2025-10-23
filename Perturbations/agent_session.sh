#!/usr/bin/env bash
set -euo pipefail

if [[ ${1:-} == "" ]]; then
  echo "Usage: $0 <image> [session-id]" >&2
  exit 1
fi

IMAGE="$1"
SESSION_ID="${2:-$(date +%Y%m%d-%H%M%S)}"
LOG_ROOT="$(cd "$(dirname "$0")" && pwd)/sessions"
LOG_DIR="$LOG_ROOT/$SESSION_ID"
CONTAINER_NAME="swe-agent-${SESSION_ID}"

mkdir -p "$LOG_DIR"

# Ensure no stale container with the same name exists.
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

echo "[agent-session] starting container $CONTAINER_NAME from image $IMAGE"
docker run -d --name "$CONTAINER_NAME" \
  --user root \
  --workdir /app \
  "$IMAGE" tail -f /dev/null >/dev/null

cleanup() {
  echo "[agent-session] stopping container $CONTAINER_NAME"
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  echo "[agent-session] logs stored in $LOG_DIR"
}
trap cleanup EXIT

attempt=1

echo "[agent-session] connected to $CONTAINER_NAME"
echo "[agent-session] type 'test' to run uv run pytest --numprocesses auto tests/ci"
echo "[agent-session] type 'exit' or press Ctrl-D to end the session"

while true; do
  if ! read -rp "swe-agent> " CMD; then
    echo
    break
  fi

  [[ -z "$CMD" ]] && continue

  if [[ "$CMD" == "exit" ]]; then
    break
  fi

  LOG_FILE="$LOG_DIR/command_${attempt}.log"
  echo "\$ $CMD" | tee "$LOG_FILE" >/dev/null

  if [[ "$CMD" == "test" ]]; then
    docker exec "$CONTAINER_NAME" bash -lc "set -euo pipefail; cd /app; uv run pytest --numprocesses auto tests/ci" \
      > >(tee -a "$LOG_FILE") \
      2> >(tee -a "$LOG_FILE" >&2) || true
  else
    docker exec "$CONTAINER_NAME" bash -lc "cd /app; $CMD" \
      > >(tee -a "$LOG_FILE") \
      2> >(tee -a "$LOG_FILE" >&2) || true
  fi

  ((attempt++))
done
