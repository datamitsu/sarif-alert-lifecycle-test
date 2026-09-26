# sarif-alert-lifecycle-test

Throwaway experiment repository. **It will be deleted** once the results are recorded.

It checks how GitHub code scanning manages the lifecycle of alerts when SARIF
files are uploaded through the REST API (`POST /repos/{owner}/{repo}/code-scanning/sarifs`)
and a later upload covers only part of what an earlier one did:

- Q1: one category, two tools (eslint + hadolint); the next upload in the same
  category contains only eslint. What happens to the hadolint alerts?
- Q2: one category, eslint; a result disappears from the next upload. Is it fixed?
- Q3: two categories (`cat-a`, `cat-b`); re-uploading only `cat-a` — does it touch `cat-b`?
  How are identical rule/location results in different categories deduplicated?
- Q4: one SARIF file with two runs sharing the same `tool.driver.name` in one category —
  accepted or rejected?
- Q5: what the analyses endpoint reports about an analysis that a later upload no longer covers.

All uploads target the same commit and `refs/heads/main`. The SARIF files uploaded are
archived under `sarif/`, and the raw API responses captured after each step under `results/`.
The source files (`src/a.ts`, `Dockerfile`) exist only so that alert locations point at real files.
