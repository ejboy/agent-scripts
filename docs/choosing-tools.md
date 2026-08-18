# Choosing the right tool

The primary tools in this repository, `mvn-lite` and `npm-lite`, target the largest source of context window bloat by stripping output noise from routine builds and tests. Secondary utilities assist with browser automation, VS Code extension testing, and local repository discovery without embedding machine-specific paths in project instructions.

## Quick guide

| Tier | Tool | Use it when | Use something else when |
| --- | --- | --- | --- |
| **Primary** | `mvn-lite` | Running routine Maven builds, tests, packaging, installation, or verification | Running reporting or inspection goals, or when ordinary live Maven output is required; use `mvn-lite --full` |
| **Primary** | `npm-lite` | Running exactly `npm run verify` or `npm run test:unit` | Running any other npm workflow; unsupported commands pass through unchanged |
| **Secondary** | `html-screenshot` | Rendering a local file or URL to a PNG in one command | A persistent interactive browser session is required |
| **Secondary** | `launch-browser` | Starting and managing a reusable Chrome DevTools session | Only a single screenshot is required |
| **Secondary** | `vscode-test` | Testing a VS Code extension through repeatable launch, inspection, activation, and screenshot operations | Arbitrary DevTools evaluation or cross-platform editor automation is required |
| **Secondary** | `repo-map` | Resolving a known machine-local repository or discovering an unknown local repository or helper | The project already provides a correct, stable path or command directly |

## Measured output savings

The experiments show that `mvn-lite` and `npm-lite` provide the largest measurable context savings. They reduce presentation volume rather than accelerating the underlying commands.

| Workflow | Baseline output | Wrapped output | Reduction |
| --- | ---: | ---: | ---: |
| Maven, Spring demo success | 5,564 bytes, 70 lines | 16 bytes, 1 line | 99.71% by bytes |
| Maven, Scriptella reactor success | 66,812 bytes, 928 lines | 17 bytes, 1 line | 99.97% by bytes |
| Maven, Apache Commons CLI success | 15,079 bytes, 203 lines | 17 bytes, 1 line | 99.89% by bytes |
| Maven, Spring demo unknown goal | 2,683 bytes, 28 lines | 272 bytes, 9 lines | 89.86% by bytes |
| npm, earlier verification success | 18,854 bytes, 375 lines | 26 bytes, 1 line | 99.86% by bytes |
| npm, Vitest success | 2,260 bytes, 43 lines | 25 bytes, 1 line | 98.89% by bytes |
| npm, Tape success | 136,262 bytes, 1,476 lines | 12 bytes, 1 line | 99.99% by bytes |
| npm, Jest success | 2,491 bytes, 68 lines | 24 bytes, 1 line | 99.04% by bytes |
| npm, earlier verification failure | 19,208 bytes, 389 lines | 3,663 bytes, 85 lines | 80.93% by bytes |
| npm, Tape failure | 136,829 bytes, 1,487 lines | 5,208 bytes, 85 lines | 96.19% by bytes |

`mvn-lite` was exercised across four Maven projects. These include a multi-module reactor, an application build, and Apache Commons CLI as a conventional single-module library using system Maven instead of a Maven Wrapper. The Commons CLI run also showed that an induced Surefire failure retained a focused goal and cause summary.

Most baselines in the table are matched direct-command output. The Commons CLI baseline is the retained Maven log produced with `mvn-lite`'s quieting flags, so it demonstrates agent-visible compaction but is not a byte-for-byte comparison with an unwrapped interactive Maven command.

`npm-lite` now has matched direct comparisons for an earlier verification workflow and three open-source `test:unit` projects using Vitest, Tape, and Jest. All four successful workflows became one line, with reductions from 98.89% to 99.99% by bytes. The large Tape failure fell by 96.19%, but direct Vitest and Jest failures were already short and the wrapper's headings and log path made the measured output slightly larger. Compact failure output is therefore bounded and diagnostic-oriented, not guaranteed to be smaller in every case.

The three-project npm table records the version originally measured. That experiment exposed missing ANSI-normalized TAP counts and weak context selection for long failures; both were addressed afterward. The current implementation prints short failures in full and selects marker-aware context for long failures, so its failure byte counts will differ from the historical measurements. It still trusts npm's exit status and discards successful logs, which can hide warnings or errors from a project command that exits successfully.

On failure, both wrappers preserve the underlying exit status and retain the complete raw log. Compact failure output is intentionally larger than successful output because it must identify the next action. When the summary is insufficient, inspect the retained log, use `mvn-lite --full` for Maven, or run the corresponding `npm` command directly for npm workflows.

The measurements do not demonstrate faster execution. Run order, caches, JVM startup, and machine activity make the small observed timing differences unsuitable as performance evidence.

## Browser workflows

Use `html-screenshot` for one-shot rendering. In the experiment it produced a PNG that was byte-identical to the equivalent direct Chrome command. Its value is consistent arguments, input validation, safe output replacement, and concise successful output. It does not use a different rendering engine or make Chrome faster.

Use `launch-browser` when several browser automation actions should share a persistent Chrome DevTools session. It manages the browser profile, launch state, and cleanup. It is not needed for a single screenshot. Reusing an already-active DevTools session that was not started through the expected managed state remains a known limitation.

Use `vscode-test` for macOS VS Code extension sessions. It exposes a stable command prefix for approvals and deliberately limits DevTools inspection to summaries and bounded visible text. Routine success output is one line; full VS Code diagnostics remain in the launch log named by an error.

## Targeted repository discovery

Required project commands belong directly in that project's `AGENTS.md`. When another local repository is required, prefer a stable alias and resolve it directly:

```bash
repo-map get aibadger
```

Use `repo-map list` only when the required repository is unknown. Likewise, check a known optional helper directly:

```bash
repo-map command html-screenshot
```

Use `repo-map commands` only when the needed capability is unknown. `repo-map command NAME` checks the named command, while `repo-map commands --check` checks every registered command and exits nonzero if any command is unavailable.

The experiments found that targeted `repo-map get NAME` guidance matched a supplied static path: both approaches used two shell commands, inspected one repository, and exposed no unrelated repository metadata. Generic discovery was less efficient because it required more commands and exposed the full registry. `repo-map` therefore provides portability and discovery rather than an inherent output reduction.

`repo-map` exposes a curated set of `agent-scripts` commands as built-in capabilities. The user-editable registry at `~/.agent-scripts/repo-map` stores additional repositories, descriptions, notes, and command metadata. Its records use `repo|name|path|description|notes` and `command|name|command|description` lines. It does not scan repositories, infer build systems, manage dependencies, or run project tasks.

## Evidence

The detailed methods, captured measurements, limitations, and rerun history remain under [`experiments/test/`](../experiments/test/). The primary build-wrapper reports are the [npm open-source project experiment](../experiments/test/NPM-LITE-OPEN-SOURCE-EXPERIMENT.md), [Apache Commons CLI Maven smoke test](../experiments/test/APACHE-COMMONS-CLI-MVN-LITE-SMOKE-TEST.md), [Financial Engine App Maven comparison](../experiments/test/PVR-LABS-FINANCIAL-ENGINE-APP.md), and [Scriptella Maven smoke test](../experiments/test/SCRIPTELLA-MVN-LITE-SMOKE-TEST.md). The [`repo-map` multi-project smoke test](../experiments/test/REPO-MAP-MULTI-PROJECT-SMOKE-TEST.md) covers discovery and browser helpers as well as the earlier wrapper comparisons.
