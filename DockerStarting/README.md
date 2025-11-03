# DockerStarting Dataset

This directory contains a gold-standard Dockerfile and five perturbed variants
that exercise different types of setup mistakes. The `example_program.py`
module and the accompanying pytest suite validate whether a container provides a
fully functional Browser Use development environment.

## Workflow

Run the helper script to build each Dockerfile and execute its default command:

```bash
./DockerStarting/run_workflow.sh
```

The script prints a summary that highlights which images succeeded, failed to
build, or surfaced test errors. To focus on a single perturbed Dockerfile, pass
`--start-only` with a number from 1 to 5:

```bash
./DockerStarting/run_workflow.sh --start-only 3
```

The gold Dockerfile installs dependencies using `uv` and executes
`pytest -c DockerStarting/pytest.ini`. The perturbed variants intentionally omit
dependencies, switch tooling, or misconfigure the command to provide a
progressively harder repair challenge.
