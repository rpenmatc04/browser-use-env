# Gold-standard Docker workflow

This repository keeps the upstream `browser-use` Docker build intact, so the
file is still named `Dockerfile` and the image defaults to the tag `browseruse`.
Renaming the Git repository to `browser-use-env` does **not** require any
changes to the Dockerfile itself—the build context already copies the current
project directory regardless of its name. You can choose whatever image tag you
prefer when you run `docker build`.

## TL;DR command sequence

```bash
# Build and test with the helper script (defaults to the tag browser-use-env:gold)
./bin/run_gold_standard.sh
```

Pass a custom image tag or extra pytest flags if you need them:

```bash
./bin/run_gold_standard.sh my-custom-tag -k "watchdog"
```

The script always performs two steps in order:

1. `docker build -t <tag> -f Dockerfile .` – builds the gold-standard image
   from the root `Dockerfile`, rebuilding every layer so you validate the fully
   supported stack.
2. `docker run --rm --entrypoint /bin/bash <tag> -lc "cd /app && uv run pytest
   --numprocesses auto tests/ci …"` – enters the container, switches to `/app`,
   and runs the canonical CI suite with optional extra pytest arguments.

## Running everything manually

If you would rather type the commands yourself:

```bash
# Build the image
TAG=browser-use-env:gold
docker build -t "$TAG" .

# Run the tests inside the container
docker run --rm -it \
  --entrypoint /bin/bash \
  "$TAG" \
  -lc "cd /app && uv run pytest --numprocesses auto tests/ci"
```

You can rerun the `docker run …` line as many times as you need without
rebuilding the image. Add pytest flags at the end of the command to filter or
adjust the run.

## Troubleshooting tips

- **`uv run` says the interpreter is missing** – ensure you are invoking the
  command through the container, not on the host. Inside the image the project
  virtual environment lives at `/app/.venv` and is prepared during the build.
- **PyPI packages fail to download** – rerun the build once network access is
  restored. The Dockerfile installs everything from scratch, so transient
  network problems during the image build can surface as `pip`/`uv` download
  errors.
- **Chromium launch errors** – confirm you are on the gold-standard image. The
  perturbation Dockerfiles intentionally remove Chromium or related bindings to
  create benchmark tasks.

## When to move on to perturbations

Only start on the images under `Perturbations/` after the gold-standard build
and test sequence succeeds. Those variants are expected to build successfully
but fail at runtime so that an evaluation agent can repair the environment from
inside the container.
