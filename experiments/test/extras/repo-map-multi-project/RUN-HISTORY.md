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

## Run 2: targeted discovery and strict read-only rerun

Date: 2026-08-10

Tested `agent-scripts` revision: `4d7f92c` plus the documented uncommitted
read-only parser correction.

`repo-map` script SHA-256:
`f8337ef472900b958e910d8913cdd3fff00aacac7affe62625cf31b468a0db3a`

Relevant environment changes: none; Codex CLI remained 0.147.0. npm, Maven, and
Java measurements were not repeated because their scripts and guidance did not
change. `html-screenshot` received a focused real-Chrome rerun after its output
filtering changed; `launch-browser` did not change.

Changed behavior under test: known repository and optional-command targets now
use `get NAME` and `command NAME`; read-only registry parsing no longer uses a
Bash here-string. `repo-map` now participates in shared version maintenance,
and successful non-verbose `html-screenshot` runs suppress Chrome diagnostics.

| Measure | Baseline | Run 2 | Change |
| --- | ---: | ---: | ---: |
| Static-guidance command count | 2 | 2 | 0 |
| `repo-map`-guidance command count | 5 | 2 | -3 |
| Repositories inspected | 1 | 1 | 0 |
| Unrelated repository contents read | 0 | 0 | 0 |
| Unrelated registry entries exposed | Full listing | 0 | Eliminated |
| Clarifications or corrections in final paired run | 0 | 0 | 0 |
| Successful `html-screenshot` output | Up to 4 lines per run | 1 line | Noise eliminated |

Targeted repository resolution exited 0 with one output line (45 bytes), and
targeted command resolution exited 0 with five output lines (178 bytes). Both
passed an OS sandbox profile denying filesystem writes except `/dev/null`.

The first strict rerun revealed that a Bash here-string still attempted a
temporary-file write. The parser was corrected and the final fresh-session run
completed in two commands without listing unrelated entries. Detailed evidence
was appended to the discovery and failure/portability reports.

The focused real-Chrome screenshot rerun exited 0 with one output line. Its PNG
was 6,158 bytes. Automated cases retained diagnostics for verbose and failure
paths. The browser-helper report contains the dated details.
