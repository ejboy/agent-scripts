# `repo-map` experiment run history

This file is an append-only index for comparing experiment evolution. Detailed
methods and evidence remain in the neighboring supplemental reports. Do not
rewrite an earlier run when behavior changes; add a new dated run and explain
any method or environment difference.

## Run 1: baseline

Date: 2026-08-10

Tested `agent-scripts` revision: `763fbac` (`Improve repo-map command discovery`)

`repo-map` script SHA-256:
`24fe9ffbe514b78d3e67b7a6ece3830d9e40544afe1a31c6fde48093cf1a76da`

Relevant environment:

- Codex CLI 0.147.0
- Google Chrome 151.0.7922.76
- Apache Maven 3.9.9
- Eclipse Temurin Java 24.0.1
- Node.js 25.9.0
- npm 11.12.1

### Discovery results

| Measure | Static guidance | `repo-map` guidance |
| --- | ---: | ---: |
| Correct repository | Yes | Yes |
| Correct module and entrypoint | Yes | Yes |
| Shell command executions | 2 | 5 |
| Unrelated repository contents read | 0 | 0 |
| Repository metadata exposed | One target | Full registry listing |
| Clarification or correction | None | None |

The `repo-map` session inspected help, ran `list`, then redundantly used both
`show aibadger` and `get aibadger`. An earlier discarded strict-read-only trial
did not produce a valid paired comparison and is documented in the discovery
supplement.

### Other baseline results

| Area | Baseline observation |
| --- | --- |
| `npm-lite` success | 18,854 bytes and 375 lines direct; 26 bytes and 1 line wrapped |
| `npm-lite` failure | 19,208 bytes and 389 lines direct; 3,663 bytes and 85 lines wrapped |
| Spring Maven success | 5,564 bytes and 70 lines direct; 16 bytes and 1 line wrapped |
| Scriptella Maven success | 66,812 bytes and 928 lines direct; 17 bytes and 1 line wrapped |
| Browser screenshots | Two helper renders and direct Chrome were byte-identical at 414 by 736 |
| Managed browser | Existing DevTools session was not reused as guidance expected |
| Registry failures | Missing, unknown, malformed, stale, alias, and unavailable-command cases were actionable |

## Future run template

### Run N: short description

Date:

Tested revision and script SHA-256:

Relevant environment changes:

Changed behavior under test:

| Measure | Baseline | Run N | Change |
| --- | ---: | ---: | ---: |
| Static-guidance command count | 2 | | |
| `repo-map`-guidance command count | 5 | | |
| Unrelated repository contents read | 0 | | |
| Unrelated registry entries exposed | Full listing | | |
| Clarifications or corrections | 0 | | |

Record targeted repository and command exit status and output size, strict
read-only sandbox behavior, repositories inspected, and any deviation from the
baseline method. Link to dated details appended to the affected supplemental
report.

