"""Run the input/output cases from ../tests.toml without installing software."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import tomllib


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shell", default="pwsh", help="pwsh or powershell (5.1)")
    parser.add_argument("--case", action="append", help="Run only the named case; repeatable")
    arguments = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    with (root / "tests.toml").open("rb") as stream:
        suite = tomllib.load(stream)
    cases = suite["tests"]
    identifiers = [case["id"] for case in cases]
    if len(identifiers) != len(set(identifiers)):
        parser.error("tests.toml contains duplicate test IDs")
    if arguments.case:
        missing = set(arguments.case) - set(identifiers)
        if missing:
            parser.error("Unknown cases: " + ", ".join(sorted(missing)))
        cases = [case for case in cases if case["id"] in arguments.case]
    shell = shutil.which(arguments.shell)
    if shell is None:
        parser.error(f"PowerShell executable not found: {arguments.shell}")

    with tempfile.TemporaryDirectory(prefix="dotfiles-tests-") as directory:
        # Windows TEMP may use an 8.3 user name; PowerShell resolves script paths
        # to their long names. Canonicalize fixtures before comparing paths.
        temporary = Path(directory).resolve()
        data_path = temporary / "suite.json"
        data_path.write_text(json.dumps(cases, ensure_ascii=False), encoding="utf-8")
        process = subprocess.run(
            [shell, "-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
             "-File", str(root / "tests" / "helpers.ps1"), "-SuitePath", str(data_path),
             "-RepositoryRoot", str(root), "-TemporaryRoot", str(temporary)],
            cwd=root,
            capture_output=True,
            encoding="utf-8",
            errors="replace",
            timeout=120,
        )
        if process.returncode != 0:
            print(process.stdout, end="")
            print(process.stderr, end="", file=sys.stderr)
            return process.returncode
        marker = "DOTFILES_TEST_RESULTS="
        payload = next((line[len(marker):] for line in process.stdout.splitlines()
                        if line.startswith(marker)), None)
        if payload is None:
            print("Test helper returned no results.", file=sys.stderr)
            print(process.stdout, end="")
            print(process.stderr, end="", file=sys.stderr)
            return 1
        results = json.loads(payload)

    failures = 0
    for case, result in zip(cases, results, strict=True):
        actual = result.get("output")
        expected = case["expected"].get("output")
        expected_error = case["expected"].get("error")
        error = result.get("error")
        passed = (error == expected_error and actual == expected)
        print(f"{'PASS' if passed else 'FAIL'} {case['id']}")
        if not passed:
            failures += 1
            if error:
                print(f"  Error: {error}")
            print("  Input:    " + json.dumps(case.get("input", {}), ensure_ascii=False))
            print("  Expected: " + json.dumps(expected, ensure_ascii=False))
            print("  Actual:   " + json.dumps(actual, ensure_ascii=False))
            if expected_error:
                print("  Expected error: " + expected_error)
    print(f"{len(cases) - failures}/{len(cases)} passed ({arguments.shell}); no programs installed.")
    return int(failures > 0)


if __name__ == "__main__":
    raise SystemExit(main())
