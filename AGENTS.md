# AGENTS.md

Guidance for coding agents working in this repository.

## Commits

- Do not commit, amend, or push without explicit user approval.

## Validation

- Static check: run `shellcheck --severity=warning` on `scripts/mvn-lite scripts/launch-browser tests/*.sh maintainers/*` before finishing changes to those paths. Do not fold experimental trees under `experiments/` into repo-wide validation.
- Tests: run `./tests/test-versions.sh` for version changes; run the full `./tests/test-*.sh` suite when a `scripts/` utility or the tests themselves change.
- Experiments under `experiments/` are self-contained: validate them with their local README/tests only.
- Follow existing script style: `set -euo pipefail` (or `set -uo pipefail` in tests), no comments unless requested, `printf` over `echo`.
