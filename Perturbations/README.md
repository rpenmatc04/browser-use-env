# Dockerfile Perturbation Tasks

This directory holds five Dockerfile variants derived from the gold-standard
image described in [`docs/gold_standard.md`](../docs/gold_standard.md).
**Every perturbation still builds successfully**, but each removes a critical
runtime dependency so that the canonical regression command
`uv run pytest --numprocesses auto tests/ci` fails. An evaluation agent must
enter the running container, install the missing pieces, and rerun the tests
until they pass—without copying the reference Dockerfile.

| File | Difficulty | Injected failure | First observable symptom | Minimal recovery path |
| --- | --- | --- | --- | --- |
| `Dockerfile.first_test` | Easy | Uninstalls `pytest-xdist`. | `pytest: error: unrecognized arguments: --numprocesses`. | `uv pip install pytest-xdist` |
| `Dockerfile.second_test` | Easy-Medium | Uninstalls the `playwright` Python package. | Imports from `playwright.async_api` fail during setup. | `uv pip install playwright` |
| `Dockerfile.third_test` | Medium | Purges the `chromium` apt package and symlinks. | Browser launches error with "chromium executable doesn't exist". | `apt-get update && apt-get install -y chromium` plus recreating symlinks |
| `Dockerfile.fourth_test` | Hard | Deletes the project virtual environment. | `uv run` complains that `/app/.venv/bin/python` is missing. | `uv venv` and `uv sync --all-extras --locked --no-dev` |
| `Dockerfile.fifth_test` | Very Hard | Deletes both the virtual environment and the `uv` binaries. | The test command exits immediately with `/bin/bash: uv: command not found`. | Reinstall uv (e.g. curl installer), recreate the venv, then `uv sync --all-extras --locked --no-dev` |

## Reproducing failures manually

For any perturbation `X`:

```bash
# 1. Build the image
docker build -f Perturbations/Dockerfile.X -t browseruse-perturbed-X .

# 2. Start an interactive shell as root so you can install packages
docker run --rm -it \
  --user root \
  --entrypoint /bin/bash \
  -v "$PWD/Perturbations/sessions":/sessions \
  browseruse-perturbed-X
```

Once inside the container:

```bash
cd /app
uv run pytest --numprocesses auto tests/ci
# Observe the failure, install the missing dependency, then rerun the command
```

Each Dockerfile now surfaces a runtime failure rather than a build failure, so
all debugging happens interactively inside the container.

## Agent-oriented command runner

To mirror SWE-Bench/SWE-Smith/R2E-Gym style evaluation loops we provide
`Perturbations/agent_session.sh`, a thin wrapper that:

1. Starts the chosen perturbation image in the background as root.
2. Runs commands you type inside the container, one at a time.
3. Captures the stdout/stderr of every command (including each test rerun) into
   timestamped files under `Perturbations/sessions/<session-id>/`.

Usage example:

```bash
./Perturbations/agent_session.sh browseruse-perturbed-first
```

Inside the shell that appears, type commands such as `test` (to trigger
`uv run pytest --numprocesses auto tests/ci`) or arbitrary bash snippets
(e.g. `apt-get update && apt-get install -y chromium`). Type `exit` or press
`Ctrl-D` to finish; the helper tears down the container and leaves the logs on
the host.

These transcripts give your supervising harness the same high-fidelity signal
that SWE-Agent, SWE-Smith, and R2E-Gym use: every action, its output, and the
final test status are persisted for scoring.

## Suggested SWE-Agent-Mini workflow

1. **Install SWE-Agent-Mini** (or your preferred variant) following the project
   instructions. Ensure the agent can call your target LLM by exporting the
   appropriate API keys.

2. **Launch the perturbation session.** Before handing control to the agent,
   build the desired perturbation image and start `agent_session.sh`. Provide
   the agent with the test command (`uv run pytest --numprocesses auto tests/ci`)
   and the container name that the script prints.

3. **Constrain read access.** Configure SWE-Agent-Mini to mount the repository
   read-only except for `Perturbations/` and `bin/test.sh` so it cannot simply
   copy `Dockerfile`.

4. **Agent loop.** The agent should:
   - Run `test` inside the helper to capture the baseline failure.
   - Issue installation or configuration commands (e.g. `uv pip install ...`,
     `apt-get install ...`).
   - Repeat `test` until the suite succeeds.

5. **Scoring.** After the helper exits, examine
   `Perturbations/sessions/<session-id>/test_attempt_*.log` to determine whether
   the agent restored the environment.

This mirrors evaluation frameworks where the LLM repeatedly runs commands,
observes the resulting errors, and adapts until the regression suite passes.
