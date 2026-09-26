#!/usr/bin/env python3
"""Generate the SARIF files for every experiment step into files/sarif/."""
import hashlib
import json
import os
import sys

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "files", "sarif")

RESULTS = {
    "E1": ("eslint", "src/a.ts", 1, "Sample eslint finding E1"),
    "E2": ("eslint", "src/a.ts", 2, "Sample eslint finding E2"),
    "H1": ("hadolint", "Dockerfile", 1, "Sample hadolint finding H1"),
    "H2": ("hadolint", "Dockerfile", 2, "Sample hadolint finding H2"),
    "P1": ("probe", "README.md", 1, "Sample probe finding P1"),
}
VERSIONS = {"eslint": "9.0.0", "hadolint": "2.12.0", "probe": "0.0.1"}


def fingerprint(rule, path, line):
    return hashlib.sha256(f"{rule}|{path}|{line}".encode()).hexdigest() + ":1"


def result(rule):
    _, path, line, text = RESULTS[rule]
    return {
        "ruleId": rule,
        "level": "warning",
        "message": {"text": text},
        "locations": [
            {
                "physicalLocation": {
                    "artifactLocation": {"uri": path, "uriBaseId": "%SRCROOT%"},
                    "region": {"startLine": line},
                }
            }
        ],
        "partialFingerprints": {"primaryLocationLineHash": fingerprint(rule, path, line)},
    }


def run(tool, rules, automation_id, declared=None):
    declared = declared or rules
    return {
        "tool": {
            "driver": {
                "name": tool,
                "version": VERSIONS[tool],
                "rules": [
                    {"id": r, "shortDescription": {"text": f"Rule {r}"}} for r in sorted(declared)
                ],
            }
        },
        "automationDetails": {"id": automation_id},
        "results": [result(r) for r in rules],
    }


def sarif(runs):
    return {
        "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
        "version": "2.1.0",
        "runs": runs,
    }


LINT = "datamitsu-lint/"
STEPS = {
    "S1": [run("eslint", ["E1", "E2"], LINT), run("hadolint", ["H1", "H2"], LINT)],
    "S2": [run("eslint", ["E1", "E2"], LINT)],
    "S3": [run("eslint", ["E1"], LINT)],
    "S4": [run("eslint", ["E1", "E2"], "cat-a/")],
    "S5": [run("hadolint", ["H1", "H2"], "cat-b/")],
    "S6": [run("eslint", ["E1", "E2"], "cat-a/")],
    "S6b": [run("hadolint", ["H1"], "cat-a/")],
    "S7": [run("eslint", ["E1"], LINT), run("eslint", ["E2"], LINT)],
    "S7b": [run("eslint", ["E1", "E2"], "cat-a/"), run("eslint", ["E1"], "cat-c/")],
    "S8": [run("probe", ["P1"], "probe-noslash")],
    "S9": [run("eslint", ["E1"], "cat-a/", declared=["E1", "E2"])],
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for step in sys.argv[1:] or STEPS:
        with open(os.path.join(OUT, f"{step}.sarif.json"), "w") as f:
            json.dump(sarif(STEPS[step]), f, indent=2)
            f.write("\n")
        print(step)
