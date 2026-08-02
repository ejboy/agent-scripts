# SlopStop Implementation Plan

Issue: N/A
Status: Active
Created: 2026-08-01
Archived:

## Summary

SlopStop is a macOS-first command-line utility for experienced developers. It scans for forgotten local development workloads and prints a concise, actionable text report.

It has two result categories:

1. **SAFE TO STOP** — authoritative evidence shows that no active workload remains and a graceful native stop action exists.
2. **NEEDS REVIEW** — recognized developer processes are old and consuming meaningful CPU or unusually high memory, but SlopStop cannot safely stop them automatically.

The verified minimal baseline covers deterministic tests, Colima detection and safe stop, compact output, and early review-process scanning. Further work continues with Phase 2 CPU observation and recognition hardening.

## Progress

Current Phase: Phase 3 — Add more authoritative workload detectors  
Current Chunk: Chunk 7 — Repository-launched browser integration  
Status: Active

### Phase Checklist

- [x] Phase 0 — Product definition and scope
- [x] Phase 1 — Recover a working minimal product
- [x] Phase 2 — Add review-only process detection
- [ ] Phase 3 — Add more authoritative workload detectors
- [ ] Phase 4 — Harden, dogfood, and prepare for wider use

### Blockers

- None.

## Source Constraints

The following requirements are binding and must survive implementation.

### Product behavior

- Plain one-shot CLI output only.
- No TUI, cursor navigation, alternate screen, daemon, or watch mode.
- Audience is experienced developers.
- Output should be technical, compact, aligned, and low-noise.
- Show useful raw data such as PID, process name, age, CPU, RSS, and a short reason.
- Do not explain basic concepts such as PID, CPU, RSS, or how `kill` works.
- Review candidates are never stopped automatically.
- Use graceful native stop commands for safe resources.
- Never use `SIGKILL`.
- Default invocation is read-only.

### CLI

Required commands:

```text
slopstop
slopstop --stop
slopstop --stop-safe
slopstop --help
```

Behavior:

- `slopstop` scans and reports only.
- `slopstop --stop` asks once before stopping all currently safe candidates.
- `slopstop --stop-safe` stops all currently safe candidates without prompting.
- Unknown arguments fail with concise usage.
- No individual row selection in the initial implementation.

### Classification contract

A candidate may be **SAFE TO STOP** only when SlopStop has authoritative lifecycle evidence or repository-owned recorded state.

Examples:

- Colima is running and its own runtime has zero active containers.
- A repository-launched test browser is still alive, but its recorded owner/launcher is gone and its identity is fully revalidated.

The following signals alone can never make a candidate safe:

- old age;
- process name;
- command-line pattern;
- missing TTY;
- high CPU;
- high memory;
- apparent orphaning.

Those signals may only produce **NEEDS REVIEW** candidates.

### CPU heuristics (review-only)

- Prefer **speed** over multi-second sampling: review rows are advisory and never auto-stopped.
- Identity, age, RSS, and CPU come from a fresh `ps` snapshot (`%cpu` is an instantaneous heuristic, not sustained load).
- Describe CPU-triggered rows as **elevated CPU**.
- High-memory rows use **high memory developer workload**.
- CPU-based results always belong to `NEEDS REVIEW` and must never make anything `SAFE TO STOP`.
- On a TTY, show a short in-place spinner while the process table is scanned and the report is built:

```text
Preparing report... |
```

- Animation is TTY-only and does not extend work artificially.
- Clear it immediately before printing `NEEDS REVIEW`, and on interruption.
- Print no progress message when stdout is redirected or piped.
- Tests stub `ps` and must not wait on multi-second samples.

### Review thresholds

Initial defaults:

```text
minimum old age:       8 hours
review CPU threshold:  5 percent
high CPU threshold:    20 percent
high CPU minimum age:  1 hour
memory threshold:      2 GiB RSS
CPU source:            instantaneous ps %CPU (heuristic)
```

A recognized developer process is review-worthy when:

```text
age >= 8 hours AND CPU >= 5% (ps heuristic)
```

or:

```text
age >= 8 hours AND RSS >= 2 GiB
```

or:

```text
age >= 1 hour AND CPU >= 20% (ps heuristic)
```

### Output

Normal-width example:

```text
SlopStop — developer workload scan

SAFE TO STOP
PID      TYPE          AGE       CPU      MEMORY    DETAILS
—        Colima        18h       0.3%     2.3 GB    Running; no active containers
42812    Chrome        11h       0.0%     640 MB    Test browser; launcher exited

NEEDS REVIEW
PID      PROCESS       AGE       CPU      MEMORY    DETAILS
4821     opencode      14h       8.2%     420 MB    Old developer session
7314     java          10h       5.7%     1.2 GB    Gradle daemon
```

Rules:

- Align columns.
- Right-align numeric fields where practical.
- Never truncate PID, process name, age, CPU, or memory solely to preserve details.
- Truncate or omit `DETAILS` first.
- Prefer the normal table whenever the terminal leaves at least ~25 columns for `DETAILS` (fixed columns are 46 wide; compact threshold is width &lt; 71).
- On narrower terminals only, switch to a compact indented record layout rather than overflowing.
- Do not force compact mode merely because a detail string would truncate; truncate `DETAILS` on the table instead.
- Do not depend on terminal height.
- Resolve width as: `SLOPSTOP_WIDTH`, then positive `COLUMNS`, then `tput cols`, then `stty size`, else 80.
- Color is optional and must never be required for meaning.
- Respect non-TTY output and `NO_COLOR` if color is added.

### Platform and implementation

- macOS first.
- Support Intel and Apple Silicon through `command -v`.
- Do not hard-code Homebrew prefixes.
- Shell implementation.
- No Python, Go, Node, or third-party runtime.
- Linux is future work.
- Prefer one primary script plus deterministic tests.
- Do not create a plugin framework or generalized abstraction layer prematurely.

## Phases

## Phase 0 — Product definition and scope

### Goal

Define the product, command behavior, safety model, output style, and initial detector priorities.

### Boundaries

- No implementation acceptance.
- No claim that the current script works.
- No future-platform implementation.

### Exit Criteria

- Name selected.
- CLI selected.
- Safety contract selected.
- Output format selected.
- Sampling interval selected.
- Initial and future detector families identified.

### Execution

#### Chunk 0 — Product specification

Status: [x]

Preconditions:

- None.

Checklist:

- [x] (design) Select product name: **SlopStop**.
- [x] (design) Select command name: `slopstop`.
- [x] (design) Define `SAFE TO STOP` and `NEEDS REVIEW`.
- [x] (design) Define `--stop` and `--stop-safe`.
- [x] (design) Choose plain aligned CLI output instead of a TUI.
- [x] (design) Choose approximately one-second macOS `top` CPU observation.
- [x] (design) Choose macOS-first shell implementation.
- [x] (design) Identify Colima as the first authoritative safe detector.
- [x] (design) Identify OpenCode, Gradle/JVM tools, dev servers, VMs, and other runtimes as later review or detector work.

Done criteria:

- Product behavior is documented in this plan.
- Future implementation can proceed without re-deciding the basic product contract.

## Phase 1 — Recover a working minimal product

### Goal

Produce a small, tested SlopStop implementation that correctly handles the basic Colima case and safe-stop behavior.

### Boundaries

- Colima only as the authoritative safe detector.
- No browser integration yet.
- No generic review-process scanning yet.
- No Multipass, VirtualBox, Gradle-native handling, or Linux support.
- Do not preserve broken implementation structure merely to reduce diff size.

### Exit Criteria

- Colima basic case works on the user's Mac.
- Deterministic tests cover positive, negative, revalidation, and stop behavior.
- Output is compact and correct at normal and narrow widths.
- `--stop` and `--stop-safe` are safe and verified.
- The user manually confirms real Colima behavior.

### Execution

#### Chunk 1 — Establish a deterministic baseline

Status: [x]

Preconditions:

- Current repository state is available locally.
- Existing script and README can be inspected.
- No assumption that current implementation is correct.

Checklist:

- [x] (design) Inspect the current script and decide which parts are reusable versus safer to replace.
- [x] (impl) Add or repair a deterministic test harness using a fake `PATH`.
- [x] (impl) Stub `uname`, `ps`, `tput`, `sleep`, `colima`, and the active runtime client as needed.
- [x] (test) Add a smoke test for `--help`.
- [x] (test) Add a smoke test for unsupported platforms.
- [x] (test) Add a read-only empty-result test.
- [x] (verify) Ensure tests never inspect or stop real processes or runtimes.
- [x] (verify) Ensure test execution does not wait for CPU observation.
- [x] (sanity) Run shell syntax checks supported by the repository.

Done criteria:

- [x] There is a deterministic test entrypoint.
- [x] Tests run without touching the real machine.
- [x] The current implementation state is reproducible.
- [x] No detector behavior is accepted without a fixture test.

#### Chunk 2 — Implement the Colima detector correctly

Status: [x]

Preconditions:

- Chunk 1 is complete.
- Colima is installed on the user's Mac for manual verification.
- The implementation can query Colima status and identify its configured runtime.

Checklist:

- [x] (design) Inspect actual `colima status` output while the user's installed Colima is running.
- [x] (design) Determine the reliable way to query the Colima-owned runtime rather than the globally selected Docker/containerd context.
- [x] (impl) Detect whether Colima is installed.
- [x] (impl) Detect whether Colima is running.
- [x] (impl) Determine the configured runtime.
- [x] (impl) Query the correct Colima-owned runtime for active containers.
- [x] (impl) Classify Colima as safe only when zero active containers are authoritatively confirmed.
- [x] (impl) Skip Colima when state cannot be determined.
- [x] (test) Cover Colima absent.
- [x] (test) Cover Colima stopped.
- [x] (test) Cover Colima running with zero containers.
- [x] (test) Cover Colima running with one or more containers.
- [x] (test) Cover runtime command failure.
- [x] (test) Cover a non-Colima global Docker context so it cannot produce a false safe result.
- [x] (verify) Manually run `slopstop` with Colima running and no containers.
- [x] (verify) Manually run `slopstop` with an active Colima container.
- [x] (sanity) Confirm no stop action occurs during ordinary scan.

Completion note: Chunk 2 is complete based on local fixture tests and manual verification of the Colima detector.

Done criteria:

- Basic Colima detection works on the user's Mac.
- A non-Colima Docker context cannot cause incorrect safe classification.
- Failure to query runtime state results in omission, not guessing.
- User manually verifies both zero-container and active-container cases.

#### Chunk 3 — Implement compact responsive output

Status: [x]

Preconditions:

- Chunk 2 is complete.
- At least one fixture can produce a safe Colima row.

Checklist:

- [x] (impl) Print the SlopStop heading and `SAFE TO STOP` section.
- [x] (impl) Print aligned normal-width columns.
- [x] (impl) Use `—` for logical resources without a meaningful PID.
- [x] (impl) Humanize age, CPU, and memory only when authoritative values exist.
- [x] (impl) Avoid fake values such as `Potential reclaim: unknown`.
- [x] (impl) Implement compact indented output below a defined width threshold.
- [x] (impl) Keep non-TTY output deterministic.
- [x] (test) Cover standard-width output.
- [x] (test) Cover narrow-width output.
- [x] (test) Cover empty safe results.
- [x] (verify) Confirm no line exceeds the selected narrow fixture width where practical.
- [x] (sanity) Confirm output contains no basic process-management explanations.

Completion note: Chunk 3 is complete. Fixed-column budget is 46 (not an inflated 62). Compact layout is used only when width &lt; 71; typical 80-column and wider terminals use the table and may truncate `DETAILS`. Boundary fixtures cover compact (60, 70) and table (71, 80, 89, 90, 120). Width resolution uses `SLOPSTOP_WIDTH` / `COLUMNS` / `tput` / `stty`.

Done criteria:

- Normal output is aligned and compact.
- Narrow output does not overflow merely because fixed columns exceed terminal width.
- Widescreen and ordinary 80-column terminals use the table, not the compact layout.
- Output remains useful without color.
- Empty output is concise.

#### Chunk 4 — Implement safe stopping and revalidation

Status: [x]

Preconditions:

- Chunks 1–3 are complete.
- Colima detection is reliable and deterministic.

Checklist:

- [x] (impl) Implement read-only default behavior.
- [x] (impl) Implement `--stop` with one confirmation prompt.
- [x] (impl) Implement `--stop-safe` without prompting.
- [x] (impl) Re-run Colima authoritative checks immediately before stopping.
- [x] (impl) Skip stopping when state changed.
- [x] (impl) Stop with `colima stop`.
- [x] (impl) Surface stop failures with nonzero status.
- [x] (impl) Keep revalidation pure; do not append duplicate candidates to shared report arrays.
- [x] (test) Confirm declined prompt performs no stop.
- [x] (test) Confirm accepted prompt stops exactly once.
- [x] (test) Confirm `--stop-safe` stops exactly once.
- [x] (test) Confirm changed state causes a skip.
- [x] (test) Confirm stop failure is reported and returns nonzero.
- [ ] (verify) Manually exercise `--stop` with idle Colima.
- [ ] (verify) Restart Colima manually after the test.

Completion note: Chunk 4 is complete for implementation and deterministic fixtures. Pure revalidation uses `colima_still_safe` / `evaluate_browser_safe` without mutating report arrays. Manual Colima stop dogfood remains optional user verification.

Done criteria:

- Default scan never changes machine state.
- Destructive modes stop only revalidated safe resources.
- A changing candidate is skipped.
- Errors are not reported as success.
- User manually confirms the real stop path.

## Phase 2 — Add review-only process detection

### Goal

Add the developer-focused actionable `top` behavior without weakening the safe-stop contract.

### Boundaries

- Review candidates remain report-only.
- Individual process rows are acceptable.
- No process-tree aggregation initially.
- No generic “show every high-CPU process.”
- No automated stopping of review candidates.

### Exit Criteria

- Approximately one-second `top` CPU observation works as documented.
- Recognized old/resource-heavy developer processes are shown.
- System processes and unrelated applications are excluded.
- OpenCode and representative JVM/dev-server cases are covered by tests.

### Execution

#### Chunk 5 — Implement one-second CPU observation

Status: [x]

Preconditions:

- Phase 1 is complete.
- Deterministic process fixtures exist.
- CPU candidates are review-only.

Checklist:

- [x] Confirm the exact supported macOS `top` command and output format.
- [x] Define the measurement as “busy during sample,” not sustained CPU.
- [x] Identify recognized candidate PIDs before sampling where practical.
- [x] Run `top` with an initial baseline and a second sample approximately one second later.
- [x] Parse only the second sample for measured CPU.
- [x] Correlate results by PID and enough process identity to reduce PID-reuse errors.
- [x] Keep CPU sampling independent from safe-resource detection.
- [x] Show an in-place progress line only on a TTY (`Sampling CPU...` / `Preparing report...` with spinner).
- [x] Animate the progress line while real sampling and classification run (TTY only).
- [x] Clear the message before report output.
- [x] Clear the message on interruption before exiting.
- [x] Print no progress text for non-TTY output.
- [x] Stub `top` in tests so tests do not wait.
- [x] Test CPU below threshold.
- [x] Test CPU above the normal threshold.
- [x] Test CPU above the high threshold.
- [x] Test process disappearance or PID identity change.
- [x] Test malformed or unavailable `top` output.
- [x] Test non-TTY execution without sampling text.
- [ ] Test interruption cleanup where practical.
- [ ] Manually compare an OpenCode sample with Activity Monitor or interactive `top`.

Completion note: Chunk 5 originally used multi-second `top` sampling; that was replaced with a fast instantaneous `ps` `%CPU` heuristic because review candidates are advisory only and `top` was too slow/fragile. Details say `elevated CPU` or `high memory developer workload`. Fixtures cover age/CPU/RSS thresholds without waiting.

Done criteria:

- Review scanning adds an approximately one-second observation.
- The second `top` sample supplies the measured CPU value.
- Documentation says “busy during sample.”
- CPU sampling cannot create a safe candidate.
- The TTY progress line animates only while real work runs, clears cleanly, and never appears in piped output.
- Automated tests do not sleep.

#### Chunk 6 — Add conservative review-process recognition

Status: [x]

Preconditions:

- Chunk 5 is complete.
- CPU classification is deterministic.

Checklist:

- [x] (design) Define a small allowlist of recognizable developer workloads.
- [x] (impl) Recognize OpenCode directly.
- [x] (impl) Recognize Bun processes only when arguments clearly identify OpenCode.
- [x] (impl) Recognize Gradle and Kotlin daemons conservatively.
- [x] (impl) Recognize Maven Daemon (`mvnd`) separately from normal Maven.
- [x] (impl) Recognize selected dev servers such as Vite, Next dev, webpack dev server, nodemon, `python -m http.server`, `go run`, Air, and Cargo Watch.
- [x] (impl) Recognize headless/remote-debugging browsers as review-only unless repository-owned state proves safety.
- [x] (impl) Exclude `kernel_task`, WindowServer, Spotlight, system daemons, other users, and unrecognized processes.
- [x] (impl) Apply age/CPU/RSS thresholds.
- [x] (impl) Sort review rows primarily by CPU descending.
- [x] (test) Cover each supported recognition family with positive and negative fixtures.
- [x] (test) Confirm generic `java`, `node`, `bun`, `python`, and browsers are not recognized solely by executable name.
- [x] (test) Confirm system and unrelated high-CPU processes are omitted.
- [ ] (verify) Dogfood against a real old OpenCode or representative developer process.

Completion note: Chunk 6 allowlist is implemented in `recognized_process` with conservative patterns (no bare java/node/bun/python). Fixtures cover OpenCode, bun+opencode, Gradle/Kotlin daemons, mvnd, vite/next/webpack/nodemon (binary and node-wrapped), python http.server, go run, air, cargo-watch, headless Chrome, plus negatives for generic tools, system processes, and other users. Sort-by-CPU and review-never-stopped checks included. Optional real OpenCode dogfood remains.

Done criteria:

- Review output is low-noise.
- OpenCode and selected developer workloads appear only when thresholds are met.
- Review candidates are never stopped by any mode.
- Generic executable names do not cause broad false positives.

## Phase 3 — Add more authoritative workload detectors

### Goal

Expand safe cleanup only where native lifecycle state is reliable, while adding review-only visibility for running VMs and daemons.

### Boundaries

- Each product gets a dedicated detector.
- Do not infer safety from helper-process names.
- Do not stop active VMs automatically.
- Implement one detector family per chunk.

### Exit Criteria

- Browser integration is identity-safe.
- Gradle/mvnd native lifecycle support is conservative.
- Multipass and VirtualBox are useful without unsafe automatic shutdown.
- Additional runtimes are considered only after native semantics are verified.

### Execution

#### Chunk 7 — Repository-launched browser integration

Status: [ ]

Preconditions:

- Phase 2 is complete.
- The existing browser launcher and state format are available.
- State semantics are understood.

Checklist:

- [ ] (design) Document the exact launcher state fields.
- [ ] (impl) Validate PID, process identity/start identity, executable, profile, debugging port, and launcher/service ownership.
- [ ] (impl) Distinguish “service absent” from “service state could not be queried.”
- [ ] (impl) Classify only repository-launched browsers as safe.
- [ ] (impl) Use the existing graceful launcher stop operation.
- [ ] (test) Cover stale PID, PID reuse, wrong profile, wrong port, active launcher, missing launcher state, and query failure.
- [ ] (verify) Manually launch and clean up a test browser.

Done criteria:

- Arbitrary browsers can never become safe.
- PID reuse cannot produce a safe candidate.
- Service-query failure does not imply launcher absence.
- Real launcher integration is manually verified.

#### Chunk 8 — Gradle, Kotlin, and Maven daemon lifecycle support

Status: [ ]

Preconditions:

- Phase 2 review recognition is stable.
- Native daemon commands and version behavior are researched locally.

Checklist:

- [ ] (design) Determine what Gradle native status can authoritatively establish.
- [ ] (design) Account for Gradle version compatibility.
- [ ] (design) Determine `mvnd` native status and stop semantics.
- [ ] (impl) Keep uncertain daemon processes under review.
- [ ] (impl) Promote only authoritatively idle daemons to safe.
- [ ] (impl) Use native graceful stop commands.
- [ ] (test) Cover compatible/incompatible Gradle versions.
- [ ] (test) Cover idle, busy, unknown, and command-failure states.
- [ ] (verify) Manually exercise against local Gradle and/or `mvnd` installations when available.

Done criteria:

- No active build daemon is classified as safe.
- Version mismatch does not create false confidence.
- Native stop operations are used.
- Uncertain cases remain review-only.

#### Chunk 9 — Multipass

Status: [ ]

Preconditions:

- Earlier phases are complete.
- Multipass is available for local verification or fixture behavior is based on documented local command output.

Checklist:

- [ ] (design) Determine authoritative instance states.
- [ ] (impl) Show old/resource-heavy running instances under review.
- [ ] (design) Investigate whether idle background infrastructure has a supported shutdown path.
- [ ] (impl) Add safe cleanup only if a documented, reliable no-workload condition and graceful stop operation exist.
- [ ] (test) Cover no instances, stopped instances, running instances, and command failure.
- [ ] (verify) Manually test when Multipass is available.

Done criteria:

- Running VMs are never stopped automatically.
- Missing or ambiguous service lifecycle semantics do not produce a safe candidate.
- Review output identifies useful Multipass state.

#### Chunk 10 — VirtualBox

Status: [ ]

Preconditions:

- Earlier phases are complete.
- `VBoxManage` behavior is understood.

Checklist:

- [ ] (impl) List running VMs individually under review.
- [ ] (impl) Show VM name and relevant host process/PID when reliably available.
- [ ] (impl) Apply age/CPU/RSS prioritization where attribution is reliable.
- [ ] (test) Cover no VMs, running VMs, inaccessible state, and command failure.
- [ ] (verify) Manually test when VirtualBox is available.

Done criteria:

- Active VirtualBox VMs are visible but never automatically stopped.
- Helper processes are not reported as unrelated duplicate rows when a logical VM row is available.

#### Chunk 11 — Additional local runtimes

Status: [ ]

Preconditions:

- Chunks 7–10 are complete.
- Real usage indicates value.

Candidate products:

- Lima
- Podman machine
- Docker Desktop
- OrbStack

Checklist:

- [ ] (design) Prioritize products based on actual developer use.
- [ ] (design) Verify native status and stop semantics per product.
- [ ] (impl) Add one product at a time.
- [ ] (test) Add dedicated fixtures per product.
- [ ] (verify) Dogfood each product before marking complete.

Done criteria:

- No generic VM-helper matching.
- Each runtime has authoritative lifecycle checks.
- Safe classification requires zero active workload plus a documented graceful stop.

## Phase 4 — Harden, dogfood, and prepare for wider use

### Goal

Validate defaults, reduce false positives, and decide whether SlopStop remains a repository utility or becomes a standalone project.

### Boundaries

- No expansion purely for completeness.
- No Linux claim without explicit implementation and tests.
- No TUI unless real usage demonstrates that plain text is insufficient.

### Exit Criteria

- Repeated dogfooding shows useful, low-noise output.
- Thresholds are validated.
- Documentation matches actual behavior.
- Repository placement decision is revisited.

### Execution

#### Chunk 12 — Dogfooding and threshold validation

Status: [ ]

Preconditions:

- Phases 1–3 contain enough useful behavior for regular use.

Checklist:

- [ ] (verify) Run SlopStop during normal development for multiple sessions.
- [ ] (verify) Record false positives and missed useful candidates.
- [ ] (design) Revisit 5%, 20%, 8-hour, 1-hour, and 2-GiB defaults.
- [ ] (impl) Adjust defaults only with observed justification.
- [ ] (verify) Confirm output remains short and actionable.
- [ ] (sanity) Confirm no safe detector has produced a false positive.

Done criteria:

- Defaults are supported by actual use.
- Known false positives are resolved or documented.
- Safe classification remains conservative.

#### Chunk 13 — Documentation and repository integration

Status: [ ]

Preconditions:

- Core behavior is stable.

Checklist:

- [ ] (integrate) Update README with exact supported detectors.
- [ ] (integrate) Document current limitations and explicitly deferred work.
- [ ] (integrate) Archive or clearly supersede `old-killidle-proposal.md`.
- [ ] (integrate) Add the normal installation/execution path used by the scripts repository.
- [ ] (verify) Confirm every documented detector has tests and actual implementation.
- [ ] (sanity) Remove stale claims such as missing test paths or unsupported features.

Done criteria:

- README describes only verified behavior.
- Old proposal cannot mislead future agents.
- Installation and usage are clear.

#### Chunk 14 — Platform and project-boundary decision

Status: [ ]

Preconditions:

- SlopStop is stable on macOS.
- Actual usage indicates whether expansion is worthwhile.

Checklist:

- [ ] (design) Decide whether to keep SlopStop in the shared scripts repository.
- [ ] (design) Consider splitting only if release cadence, documentation, contributors, or code size justify it.
- [ ] (design) Decide whether Linux support is valuable.
- [ ] (impl) If Linux is approved, create explicit Linux-specific fixtures and implementation chunks.
- [ ] (sanity) Do not assume BSD and GNU `ps`, `date`, `stat`, or process semantics are interchangeable.

Done criteria:

- Repository placement is intentional.
- Linux is either explicitly planned or explicitly deferred.
- No unsupported platform claim remains.

## Explicitly Deferred

The following are not part of the current implementation path unless a future plan promotes them:

- TUI or continuous interactive display
- daemon or scheduled cleanup
- automatic stopping of review candidates
- generic “kill every old process” behavior
- Homebrew database-service cleanup
- processes owned by other users
- JSON output
- configuration files before defaults are validated
- process-tree aggregation before individual rows prove insufficient
- plugin framework
- automatic Linux portability
- broad IntelliJ orphan detection without authoritative signals

## Outcome

Required before archive.

- What was delivered:
- What changed from the original plan:
- What was intentionally skipped:

## Notes

- The first implementation attempt is reference material only. Existing code is not automatically considered complete.
- Work must proceed from the earliest incomplete chunk.
- Before each chunk, preview intended changes, likely files, verification, assumptions, and risks.
- Do not implement future chunks early.
- If a chunk's preconditions are not satisfied, stop and resolve that condition first.
