# killidle — dev-machine cleanup tool proposal

Status: Proposal
Created: 2026-08-01

## Summary

`killidle` is a macOS CLI that finds idle, forgotten, or duplicate processes on a
developer machine and offers to stop them. It reports candidates in a categorized
table with age and memory usage, and stops nothing unless asked.

The target audience is a single developer on a single Mac: leftovers from browser
automation, stale dev servers, running-but-unused container runtimes, started
Homebrew services, duplicate tool instances, and abandoned JVM daemons.

## Problem

Developers leave a predictable set of things running and forget them:

- a headless Chrome started for a test run, still listening on port 9222
- `python -m http.server` serving a local site that is no longer needed
- Colima / Docker Desktop / Lima / OrbStack VMs that were stopped in spirit but not in fact
- Homebrew services (`postgres`, `mysql`, `redis`, ...) started once and never touched again
- multiple long-lived copies of the same tool, one per idle shell
- Gradle and Kotlin JVM daemons that linger after the build finished

None of these are visible enough to clean up by hand, and together they consume
several gigabytes and real CPU time.

## How the tool works

### Modes

`killidle` has two modes.

- **Scan (default).** Take one snapshot of the process table, classify candidates,
  and print a grouped report. Nothing is stopped.
- **Clean (`--stop`).** Same scan, then stop the candidates. It confirms each stop
  unless `--yes` is given.

### Scan

A single `ps` snapshot is taken and parsed once. For every process the tool reads:

- PID and parent PID
- elapsed time (to judge "idle long enough")
- resident memory
- command line

Each process is evaluated against detection rules. A candidate must be older than a
minimum idle threshold (`--min-age`, default 2 hours) to be reported. This keeps
freshly-started servers and active builds out of the results.

### Categories

1. **Container and VM runtimes** — Colima, Docker Desktop, Lima, OrbStack, Podman
   machine, VirtualBox, Multipass. These are stopped with their own commands
   (`colima stop`, `limactl stop <name>`, ...) rather than a raw kill, so state stays
   clean.
2. **Leftover dev servers** — `python -m http.server`, Vite/webpack/nodemon/next dev,
   `go run`/air/dlv, `cargo watch`, puma/rails on development ports. Matched by
   recognizable command-line patterns.
3. **Headless test browsers** — Chrome/Edge/Brave launched with remote debugging or
   a testing profile, cross-checked against the launcher's recorded state.
4. **Idle Homebrew services** — `brew services` entries marked as started.
5. **Duplicate tool instances** — more than one long-idle copy of the same command;
   all but the first are candidates.
6. **Abandoned JVM daemons** — Gradle and Kotlin daemons whose owning build is gone.
   IntelliJ's own build processes are never candidates.

### Clean

Each stop action is explicit and narrow:

- the process is re-checked for existence just before stopping
- container runtimes get their real stop command
- processes get a graceful `TERM`, never `KILL`
- what was stopped is reported, so a restart is easy

### Safety rules

- Never proposes the shell running the tool, the tool's own process, or PID 1.
- Dry-run is the default; no process is touched without `--stop`.
- Idle age must clear the threshold before anything is considered.
- Conservative matching: unknown or ambiguous processes are reported as "not
  classified" only when clearly safe, and skipped otherwise.

## CLI sketch

```
killidle               # scan and report
killidle --stop        # scan and stop, with confirmation
killidle --stop --yes  # scan and stop without prompts
killidle --min-age 4   # raise the idle threshold to 4 hours
killidle --help
```

## Recommendations: stack

### Recommendation: Bash

`killidle` should be a single Bash script, consistent with the existing
`launch-browser` and `mvn-lite` utilities in this repository. Reasons:

- The detection surface is process-table inspection plus a handful of command
  lookups (`ps`, `pgrep`, `brew services`, `colima status`, ...). Bash already
  has direct access to all of it with zero dependencies.
- The tool's real stop commands are other binaries; Bash's role is to find
  candidates and invoke them, which is what the repo already does well.
- It fits the repo's "deterministic processing" and "generic scripts" principles:
  standard OS tools, no LLM, no API, no telemetry.
- No interpreter or toolchain to install for a personal utility that should run on
  any Mac.

### Alternatives considered

- **Python (stdlib only).** Would give nicer time parsing and table formatting, and
  is preinstalled on macOS. But it splits the tool into "script plus tests plus a
  packaging story", and the logic is thin enough that Python's advantages do not yet
  pay for that overhead. It becomes the right choice if parsing of process output
  grows substantially (e.g. JSON fixture-driven detection).
- **Go.** Overkill for this. Compilation, distribution, and a build step for a tool
  that is mostly "match and invoke" is not worth it at this size.
- **Homebrew tap / installed binary.** Unnecessary. The tool is personal, per the
  `experiments/` placement.

### Testing recommendation

Tests follow the existing repo pattern: a fake `PATH` of stub binaries
(`ps`, `brew`, `colima`, ...) with fixture output, so the tool is testable without
touching a real machine. This works naturally in Bash and keeps the experiment
self-contained.

## Scope boundaries

In scope:

- macOS only (matches the existing utilities)
- the six categories above, detected conservatively

Out of scope:

- cross-platform process management
- an interactive TUI, daemon, or scheduled job
- stopping processes owned by other users
- "kill everything idle" heuristics or auto-cleanup policies
- anything touching the StatLite product
