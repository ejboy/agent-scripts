# agent-scripts

[![Version](https://img.shields.io/badge/version-0.2.0-blue)](https://github.com/ejboy/agent-scripts/tree/v0.2.0)

agent-scripts is a collection of small, local-first command-line utilities for AI-assisted development. Some reduce noisy tool output and save agent context; others make common development tasks easier to automate. Scripts use predictable command names, work well from PATH, and are designed to be easy for both developers and coding agents to discover and invoke.

## Tools

- `mvn-lite` — compact Maven output for builds and tests
- `npm-lite` — compact output for selected npm test and verification workflows
- `html-screenshot` — render local HTML or URLs to PNG
- `launch-browser` — launch Chrome with DevTools enabled
- `repo-map` — local repository and agent-capability discovery

Public, standalone utilities live under `scripts/`. Repository release tooling lives
separately under `maintainers/` and is not part of the public utility interface.

## Installation

Clone the repository and add its `scripts/` directory to `PATH`:

```bash
git clone https://github.com/ejboy/agent-scripts.git ~/.local/share/agent-scripts
export PATH="$HOME/.local/share/agent-scripts/scripts:$PATH"
```

Add the `export` line to your shell startup file to make the tools available in future sessions. You can then invoke `mvn-lite`, `npm-lite`, `html-screenshot`, `launch-browser`, and `repo-map` by name from any project.

See the [installation guide](docs/installation.md) for shell setup, updates, and optional project-local pinning.

## repo-map

`repo-map` is a machine-local registry for discovering related repositories and useful commands across projects. Projects should document their required commands directly; coding agents can use `repo-map` to discover additional machine-local capabilities and related repositories.

```bash
repo-map
repo-map command html-screenshot
repo-map commands
repo-map commands --check
repo-map add ~/src/aibadger
repo-map show aibadger
repo-map get aibadger
```

Required project commands should be documented directly in each project's `AGENTS.md`. Use `repo-map get NAME` to resolve a known related repository without relying on a machine-specific path, and use `repo-map list` only when the required repository is unknown.

The command catalog is for optional, machine-local helpers. Use `repo-map command NAME` to check a known capability without listing the entire catalog. Use `repo-map commands` only when the needed optional capability is unknown. Registration does not guarantee availability; `repo-map command NAME` checks the named command, while `repo-map commands --check` checks every registration and exits nonzero if any command is unavailable.

`repo-map` exposes a curated set of `agent-scripts` commands as built-in capabilities. These commands are intended to be invoked by name and assume the `agent-scripts` `scripts/` directory is on `PATH`. They are not written to the user registry. The intentionally user-editable registry at `~/.agent-scripts/repo-map` stores additional local repositories, descriptions, notes, and command metadata. `repo-map` does not scan repositories, infer a repository's build system, manage dependencies, or run project tasks. Its simple records use `repo|name|path|description|notes` and `command|name|command|description` lines.

See the [multi-project smoke test and controlled follow-ups](experiments/test/REPO-MAP-MULTI-PROJECT-SMOKE-TEST.md) for real-project discovery, failure, wrapper-output, and browser-helper evidence, including observed limitations and inefficiencies.

## mvn-lite

*Introverted Maven for coding agents.*

`mvn-lite` provides compact Maven output while preserving normal Maven command behavior.

`mvn-lite` is optimized for build, test, package, install, and verification commands. Use `--full` for reporting goals or whenever ordinary Maven output is needed.

Real-project results:

- [Financial engine app Maven compatibility experiment](experiments/test/PVR-LABS-FINANCIAL-ENGINE-APP.md): successful output fell from 6,753 to 16 bytes—more than 99.7%.
- [Scriptella ETL smoke test](experiments/test/SCRIPTELLA-MVN-LITE-SMOKE-TEST.md): a successful JDK 17 reactor test fell from hundreds of lines to one.

It stays close to Maven:

- It operates in the caller's current working directory, regardless of where the script is installed.
- It prefers that directory's executable `./mvnw`, then falls back to `mvn` from `PATH`.
- It accepts ordinary Maven arguments and preserves their order and boundaries.
- Compact mode adds `-B`, `-ntp`, and `-Dstyle.color=never` when an equivalent option was not supplied.
- It prints a small success result and conservatively extracts common compiler, test, dependency, plugin-goal, and Maven command failures.
- It retains complete failure logs and returns Maven's exit status unchanged.

A successful compact run looks like:

```text
PASS · 4.2 s
```

A representative failure looks like this; actual extraction depends on Maven and plugin output:

```text
FAIL

Failure summary:
  Test: com.example.AppTest.shouldRejectInvalidInput
  Exception: java.lang.AssertionError: expected 400

Full Maven log:
  /project/.agent-logs/maven/maven-20260730-100000-12345.log.a1B2c3

Re-run with --full for complete live output.
```

A standard plugin failure with a clear same-line cause can include:

```text
  Goal: org.example:example-plugin:1.0:run (default)
  Cause: Generated output directory is not writable
```

### Usage

```bash
mvn-lite clean verify
mvn-lite -pl app -am test
mvn-lite --full dependency:tree
mvn-lite --keep-log verify
mvn-lite --help-mvn-lite
```

The wrapper options are:

- `--full`: ordinary live Maven output.
- `--raw`: alias for `--full`.
- `--keep-log`: retain a successful compact-run log temporarily.
- `--help-mvn-lite`: show the wrapper version, usage, and wrapper options.

Maven informational options such as `--help` and `--version` continue to pass
through to Maven.

Wrapper options must appear before Maven arguments. Use `--` to end wrapper-option parsing explicitly.

Maven's informational flags always pass through with ordinary output and unchanged arguments:

```text
-h
--help
-v
--version
-V
--show-version
```

### Scope and failure logs

Compact mode is designed primarily for builds and tests. Reporting and inspection goals such as `dependency:tree`, `help:effective-pom`, and `help:active-profiles` may need `--full`.

Summaries are deterministic and conservative. Unsupported formats fall back to at most 80 lines from the Maven log. The wrapper does not inspect the POM, classify every Maven plugin, reconstruct test counts, or call an AI service.

Compact-mode failure logs remain under `.agent-logs/maven/` in the current project. Successful logs are deleted unless `--keep-log` is supplied. After a failed run, `mvn-lite` removes its logs older than seven days, including logs retained by `--keep-log`. Move any log that must be kept longer. Set `MVN_LITE_LOG_DIR` to use another destination. Retained raw logs are authoritative, and projects adopting `mvn-lite` should ignore `.agent-logs/`.

A project may optionally define its own `./scripts/build` wrapper for project-specific verification policy, but that vocabulary belongs in the application repository rather than here.

## npm-lite

`npm-lite` reduces successful output for the two supported npm workflows while
keeping npm's behavior for every other invocation. Only these exact commands
use compact mode:

```bash
npm-lite run verify
npm-lite run test:unit
```

Successful compact runs print a short status and optional test count. Failures
retain the complete npm output under `.agent-logs/npm/`, print bounded
diagnostics, and preserve npm's exit status. Failed npm logs older than seven
days are pruned on later compact runs; move any log that must be retained
longer. Other commands pass through to npm unchanged, including:

```bash
npm-lite install
npm-lite run build
```

The latter examples behave like ordinary npm because they do not exactly match
one of the compact workflows.

## launch-browser

`scripts/launch-browser` is a separate macOS utility for starting Google Chrome with DevTools enabled at `http://127.0.0.1:9222`. It defaults to detached headless mode.

```bash
launch-browser
launch-browser --visible
launch-browser --foreground --isolated
launch-browser --stop
launch-browser --help
```

Successful detached launches record their service label and PID in `~/.browser-testing-profile/launch-state`, alongside the existing persistent browser profile. `--stop` validates that the recorded service uses the `xyz.pvrlabs.browser.*` prefix, asks `launchctl` to stop it, and verifies that both the recorded PID and DevTools endpoint have stopped before removing state. If the recorded PID still owns port `9222` after service removal, the script terminates that process directly. It never kills an arbitrary process merely because it uses port `9222`.

The temporary launch log is removed when Chrome exits normally; abnormal-exit logs remain available for diagnostics.

## html-screenshot

`scripts/html-screenshot` is a one-shot headless Chrome renderer for local HTML files, `file://` URLs, and HTTP(S) URLs. It does not start or manage a reusable browser instance.

```bash
html-screenshot examples/page.html
html-screenshot --width 1440 --height 900 --wait 1000 -o /tmp/page.png examples/page.html
html-screenshot --scale 2 https://example.com
```

It discovers standard macOS Chrome and Chromium application locations before checking `PATH`. Use `--chrome /path/to/chrome` or `CHROME_BIN=/path/to/chrome` to select an executable explicitly. The default viewport is 1280×720 with a 500 ms virtual-time wait. Successful default output is one line; use `--verbose` to retain Chrome diagnostics. Failed renders always include Chrome diagnostics.

Release maintenance is documented in [maintainers/README.md](maintainers/README.md).

## Status

This is an experimental, small utility collection. `mvn-lite` is not a complete Maven replacement, and this repository is not a build system, browser automation framework, AI agent, or task runner.

MIT licensed; see [LICENSE](LICENSE).
