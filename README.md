# agent-scripts

[![Version](https://img.shields.io/badge/version-0.1.0-blue)](https://github.com/ejboy/agent-scripts/tree/v0.1.0)

agent-scripts is a collection of small, local-first command-line utilities for AI-assisted development. Some reduce noisy tool output and save agent context; others make common development tasks easier to automate. Scripts use predictable command names, work well from PATH, and are designed to be easy for both developers and coding agents to discover and invoke.

## Tools

- `mvn-lite` — compact Maven output for builds and tests
- `html-screenshot` — render local HTML or URLs to PNG
- `launch-browser` — launch Chrome with DevTools enabled

Public, standalone utilities live under `scripts/`. Repository release tooling lives
separately under `maintainers/` and is not part of the public utility interface.

## mvn-lite

*Introverted Maven for coding agents.*

`mvn-lite` provides compact Maven output while preserving normal Maven command behavior.

`mvn-lite` is optimized for build, test, package, install, and verification commands. Use `--full` for reporting goals or whenever ordinary Maven output is needed.

Real-project results:

- [Finrecord compatibility experiment](experiments/test/PVR-LABS-FINANCIAL-ENGINE-APP.md): successful output fell from 6,753 to 16 bytes—more than 99.7%.
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

## Installation

For shared projects, install a pinned version at the project root:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/ejboy/agent-scripts/v0.1.0/scripts/mvn-lite \
  -o mvn-lite
chmod +x mvn-lite
./mvn-lite test
```

Commit `mvn-lite` and add `.agent-logs/` to `.gitignore`.

For personal use across projects, install it on `PATH` instead:

```bash
mkdir -p ~/.local/bin
curl -fsSL \
  https://raw.githubusercontent.com/ejboy/agent-scripts/v0.1.0/scripts/mvn-lite \
  -o ~/.local/bin/mvn-lite
chmod +x ~/.local/bin/mvn-lite
```

Repositories that group utilities under `scripts/` may use `./scripts/mvn-lite`.

## Usage

```bash
./mvn-lite clean verify
./mvn-lite -pl app -am test
./mvn-lite --full dependency:tree
./mvn-lite --keep-log verify
./mvn-lite --help-mvn-lite
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

## Scope and failure logs

Compact mode is designed primarily for builds and tests. Reporting and inspection goals such as `dependency:tree`, `help:effective-pom`, and `help:active-profiles` may need `--full`.

Summaries are deterministic and conservative. Unsupported formats fall back to at most 80 lines from the Maven log. The wrapper does not inspect the POM, classify every Maven plugin, reconstruct test counts, or call an AI service.

Compact-mode failure logs remain under `.agent-logs/maven/` in the current project. Successful logs are deleted unless `--keep-log` is supplied. After a failed run, `mvn-lite` removes its logs older than seven days, including logs retained by `--keep-log`. Move any log that must be kept longer. Set `MVN_LITE_LOG_DIR` to use another destination. Retained raw logs are authoritative, and projects adopting `mvn-lite` should ignore `.agent-logs/`.

A project may optionally define its own `./scripts/build` wrapper for project-specific verification policy, but that vocabulary belongs in the application repository rather than here.

## launch-browser

`scripts/launch-browser` is a separate macOS utility for starting Google Chrome with DevTools enabled at `http://127.0.0.1:9222`. It defaults to detached headless mode.

```bash
./scripts/launch-browser
./scripts/launch-browser --visible
./scripts/launch-browser --foreground --isolated
./scripts/launch-browser --stop
./scripts/launch-browser --help
```

Successful detached launches record their service label and PID in `~/.browser-testing-profile/launch-state`, alongside the existing persistent browser profile. `--stop` validates that the recorded service uses the `xyz.pvrlabs.browser.*` prefix, asks `launchctl` to stop it, and verifies that both the recorded PID and DevTools endpoint have stopped before removing state. If the recorded PID still owns port `9222` after service removal, the script terminates that process directly. It never kills an arbitrary process merely because it uses port `9222`.

The temporary launch log is removed when Chrome exits normally; abnormal-exit logs remain available for diagnostics.

## html-screenshot

`scripts/html-screenshot` is a one-shot headless Chrome renderer for local HTML files, `file://` URLs, and HTTP(S) URLs. It does not start or manage a reusable browser instance.

```bash
./scripts/html-screenshot examples/page.html
./scripts/html-screenshot --width 1440 --height 900 --wait 1000 -o /tmp/page.png examples/page.html
./scripts/html-screenshot --scale 2 https://example.com
```

It discovers standard macOS Chrome and Chromium application locations before checking `PATH`. Use `--chrome /path/to/chrome` or `CHROME_BIN=/path/to/chrome` to select an executable explicitly. The default viewport is 1280×720 with a 500 ms virtual-time wait; use `--verbose` to retain Chrome diagnostics.

## Maintaining releases

The root `VERSION` is the canonical release version. Public scripts embed that
version so copied files retain their identity and provenance. Maintainers can update
all registered scripts and run validation with:

```bash
./maintainers/bump-version 0.2.0
```

The maintainer command updates files and shows the resulting diff; it does not
commit or tag the release.

## Status

This is an experimental, small utility collection. `mvn-lite` is not a complete Maven replacement, and this repository is not a build system, browser automation framework, AI agent, or task runner.

MIT licensed; see [LICENSE](LICENSE).
