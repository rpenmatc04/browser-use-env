"""Utility helpers used by DockerStarting tests.

The goal of these helpers is to provide deterministic checks that verify the
Docker image contains a functional development environment for this repository.
The corresponding tests exercise these helpers to ensure that the container has
installed the project in editable mode, that the console scripts are registered
and that the Python runtime matches the minimum requirements.
"""

from __future__ import annotations

import json
import platform
import shutil
import sys
from dataclasses import dataclass
from importlib import import_module
from importlib.metadata import entry_points, version
from typing import Any, Dict, List, Tuple

PROJECT_NAME = "browser-use"


@dataclass(frozen=True)
class CheckResult:
    """Represents the outcome of a lightweight environment check."""

    name: str
    passed: bool
    details: str


def python_runtime() -> Tuple[int, int, int]:
    """Return the active Python version as a ``(major, minor, micro)`` tuple."""

    info = sys.version_info
    return info.major, info.minor, info.micro


def is_browser_use_importable() -> bool:
    """Return ``True`` if the local ``browser_use`` package can be imported."""

    try:
        import_module("browser_use")
    except ModuleNotFoundError:
        return False
    else:
        return True


def browser_use_version() -> str:
    """Return the installed project version.

    The helper defers to ``importlib.metadata`` so that it works for both
    editable installs as well as wheel based installations.
    """

    return version(PROJECT_NAME)


def registered_console_scripts() -> List[str]:
    """Return console scripts provided by the project."""

    scripts: List[str] = []
    for ep in entry_points(group="console_scripts"):
        if ep.name.startswith("browser"):
            scripts.append(ep.name)
    return sorted(set(scripts))


def uv_available() -> bool:
    """Return ``True`` if ``uv`` is present on the ``PATH``."""

    return shutil.which("uv") is not None


def collect_environment_report() -> Dict[str, Any]:
    """Gather diagnostic information for the Docker validation tests."""

    report: Dict[str, Any] = {
        "python_version": python_runtime(),
        "platform": platform.platform(),
        "browser_use_importable": is_browser_use_importable(),
        "browser_use_version": browser_use_version(),
        "console_scripts": registered_console_scripts(),
        "uv_available": uv_available(),
    }
    return report


def run_checks() -> List[CheckResult]:
    """Execute a suite of environment checks and return the outcomes."""

    major, minor, _ = python_runtime()
    checks = [
        CheckResult(
            name="python-version",
            passed=major == 3 and minor >= 11,
            details="Python 3.11+ is required",
        ),
        CheckResult(
            name="browser-use-import",
            passed=is_browser_use_importable(),
            details="The browser_use package must be importable",
        ),
        CheckResult(
            name="uv-cli",
            passed=uv_available(),
            details="uv should be installed for dependency management",
        ),
        CheckResult(
            name="console-scripts",
            passed=set(registered_console_scripts()).issuperset({"browseruse", "browser-use"}),
            details="Expected console scripts are missing",
        ),
    ]
    return checks


def main() -> Dict[str, Any]:
    """Return a structured summary that is easy to assert in tests."""

    summary = {
        "report": collect_environment_report(),
        "checks": run_checks(),
    }
    return summary


if __name__ == "__main__":
    # The script prints a JSON report which can be helpful when debugging a
    # Docker image manually. The Docker validation entrypoint uses ``pytest``
    # instead so that individual failures are easier to triage.
    output = main()
    json_report = {
        "report": output["report"],
        "checks": [check.__dict__ for check in output["checks"]],
    }
    print(json.dumps(json_report, indent=2))
