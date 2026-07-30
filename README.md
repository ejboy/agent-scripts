# agent-scripts

Maven build logs often consume far more coding-agent context than the actual failure. `mvn-lite` keeps normal Maven command syntax and exit behavior while providing compact output for common build and verification workflows.

## mvn-lite

`mvn-lite` is optimized for build, test, package, install, and verification commands. Use `--full` for reporting goals or whenever ordinary Maven output is needed.

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
  /project/.agent-logs/maven/maven-20260730-100000-12345.log

Re-run with --full for complete live output.
```

## Installation

Repository-local installation keeps the wrapper reviewed and versioned with the application:

```bash
mkdir -p scripts
cp /path/to/agent-scripts/scripts/mvn-lite ./scripts/mvn-lite
chmod +x ./scripts/mvn-lite
printf '\n.agent-logs/\n' >> .gitignore

./scripts/mvn-lite test
```

For optional global installation or symlinking:

```bash
mkdir -p ~/.local/bin
ln -s /path/to/agent-scripts/scripts/mvn-lite ~/.local/bin/mvn-lite

cd /path/to/project
mvn-lite test
```

The command always operates on the current working directory, not the script's installation directory.

## Usage

```bash
mvn-lite test
mvn-lite clean verify
mvn-lite -pl app -am test
mvn-lite -Dtest=SomeTest test
mvn-lite --version
mvn-lite --help
mvn-lite --full dependency:tree
mvn-lite --keep-log verify
```

The wrapper options are:

- `--full`: ordinary live Maven output.
- `--raw`: alias for `--full`.
- `--keep-log`: retain the log after a successful compact run.

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

Compact-mode failure logs remain under `.agent-logs/maven/` in the current project. Successful logs are deleted unless `--keep-log` is supplied. Set `MVN_LITE_LOG_DIR` to use another destination. Retained raw logs are authoritative, and projects adopting `mvn-lite` should ignore `.agent-logs/`.

A project may optionally define its own `./scripts/build` wrapper for project-specific verification policy, but that vocabulary belongs in the application repository rather than here.

## launch-browser

`scripts/launch-browser` is a separate macOS utility for starting Google Chrome with DevTools enabled at `http://127.0.0.1:9222`. It defaults to detached headless mode.

```bash
./scripts/launch-browser
./scripts/launch-browser --visible
./scripts/launch-browser --foreground --isolated
./scripts/launch-browser --stop
```

Successful detached launches record their service label and PID in `~/.browser-testing-profile/launch-state`, alongside the existing persistent browser profile. `--stop` validates that the recorded service uses the `xyz.pvrlabs.browser.*` prefix, asks `launchctl` to stop it, and verifies that both the recorded PID and DevTools endpoint have stopped before removing state. If the recorded PID still owns port `9222` after service removal, the script terminates that process directly. It never kills an arbitrary process merely because it uses port `9222`.

The temporary launch log is removed when Chrome exits normally; abnormal-exit logs remain available for diagnostics.

## Status

This is an experimental, small utility collection. `mvn-lite` is not a complete Maven replacement, and this repository is not a build system, browser automation framework, AI agent, or task runner.

MIT licensed; see [LICENSE](LICENSE).
