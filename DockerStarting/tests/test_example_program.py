"""Tests that validate the helper utilities used by the Docker scenarios."""

from __future__ import annotations

from importlib.metadata import PackageNotFoundError, version
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - Python <3.11 fallback
    import tomli as tomllib  # type: ignore[no-redef]

from DockerStarting import example_program as program


def test_python_runtime_meets_minimum_version() -> None:
    major, minor, _ = program.python_runtime()
    assert major == 3 and minor >= 11


def test_browser_use_package_is_importable() -> None:
    assert program.is_browser_use_importable()


def _expected_version() -> str:
    try:
        return version(program.PROJECT_NAME)
    except PackageNotFoundError:
        pyproject = Path(__file__).resolve().parents[2] / "pyproject.toml"
        data = tomllib.loads(pyproject.read_text())
        return data["project"]["version"]


def test_browser_use_version_matches_metadata() -> None:
    assert program.browser_use_version() == _expected_version()


def test_expected_console_scripts_are_registered() -> None:
    scripts = program.registered_console_scripts()
    assert {"browseruse", "browser-use"}.issubset(set(scripts))


def test_uv_is_available_on_path() -> None:
    assert program.uv_available()


def test_main_returns_successful_checks() -> None:
    summary = program.main()
    results = summary["checks"]
    assert results, "expected at least one check to run"
    assert all(check.passed for check in results)
