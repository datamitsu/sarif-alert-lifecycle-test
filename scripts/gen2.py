#!/usr/bin/env python3
"""Generate SARIF for the follow-up steps: A (alert merge key) and B (analysis deletion).

A uploads are cumulative (A2 repeats A1's results, A3 repeats A1 and A2) so that a later
upload into merge-test/ never marks an earlier variant's results as fixed.
"""
import hashlib
import json
import os
import sys

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "files", "sarif")


def h(s):
    return hashlib.sha256(s.encode()).hexdigest() + ":1"


def res(tool, rule, path, line, fp):
    return {
        "ruleId": rule,
        "level": "warning",
        "message": {"text": f"{tool} finding {rule} at {path}:{line}"},
        "locations": [
            {
                "physicalLocation": {
                    "artifactLocation": {"uri": path, "uriBaseId": "%SRCROOT%"},
                    "region": {"startLine": line},
                }
            }
        ],
        "partialFingerprints": {"primaryLocationLineHash": fp},
    }


def run(tool, category, results):
    rules = sorted({r["ruleId"] for r in results})
    return {
        "tool": {
            "driver": {
                "name": tool,
                "version": "1.0.0",
                "rules": [{"id": r, "shortDescription": {"text": f"Rule {r}"}} for r in rules],
            }
        },
        "automationDetails": {"id": category},
        "results": results,
    }


# A1: same ruleId, same location, same fingerprint, different tools
A1 = {
    "toolx": [res("toolx", "M1", "src/a.ts", 3, h("M1|src/a.ts|3"))],
    "tooly": [res("tooly", "M1", "src/a.ts", 3, h("M1|src/a.ts|3"))],
}
# A2: different ruleId, same location, same fingerprint
A2 = {
    "toolx": [res("toolx", "toolx/M2", "src/a.ts", 4, h("M2|src/a.ts|4"))],
    "tooly": [res("tooly", "tooly/M2", "src/a.ts", 4, h("M2|src/a.ts|4"))],
}
# A3: same ruleId, same location, different fingerprints
A3 = {
    "toolx": [res("toolx", "M3", "src/a.ts", 5, h("toolx|M3|src/a.ts|5"))],
    "tooly": [res("tooly", "M3", "src/a.ts", 5, h("tooly|M3|src/a.ts|5"))],
}


def merged(*variants):
    return [run(t, "merge-test/", [r for v in variants for r in v[t]]) for t in ("toolx", "tooly")]


STEPS = {
    "A1": merged(A1),
    "A2": merged(A1, A2),
    "A3": merged(A1, A2, A3),
    "B1": [
        run(
            "toolz",
            "del-test/",
            [
                res("toolz", "Z1", "Dockerfile", 3, h("Z1|Dockerfile|3")),
                res("toolz", "Z2", "Dockerfile", 4, h("Z2|Dockerfile|4")),
            ],
        )
    ],
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for step in sys.argv[1:] or STEPS:
        with open(os.path.join(OUT, f"{step}.sarif.json"), "w") as f:
            json.dump(
                {
                    "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
                    "version": "2.1.0",
                    "runs": STEPS[step],
                },
                f,
                indent=2,
            )
            f.write("\n")
        print(step)
