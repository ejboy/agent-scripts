# mvn-lite

*Introverted Maven for coding agents.*

`mvn-lite` provides compact Maven output while preserving normal Maven command
behavior. It is optimized for build, test, package, install, and verification
commands. Use `--full` for reporting goals or whenever ordinary Maven output is
needed.

For the motivation behind the tool, read
[Introverted Maven](https://pvrlabs.xyz/articles/introverted-maven.html).

It stays close to Maven:

- It operates in the caller's current working directory.
- It prefers that directory's executable `./mvnw`, then falls back to `mvn`
  from `PATH`.
- It accepts ordinary Maven arguments and preserves their order and boundaries.
- Compact mode adds `-B`, `-ntp`, and `-Dstyle.color=never` when an equivalent
  option was not supplied.
- It extracts common compiler, test, dependency, plugin-goal, and Maven command
  failures conservatively.
- It retains complete failure logs and returns Maven's exit status unchanged.

## Usage

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

Wrapper options must appear before Maven arguments. Use `--` to end
wrapper-option parsing explicitly. Maven's `-h`, `--help`, `-v`, `--version`,
`-V`, and `--show-version` informational flags pass through with ordinary
output and unchanged arguments.

## Output

A successful compact run looks like:

```text
PASS · 4.2 s
```

A representative failure looks like this; actual extraction depends on Maven
and plugin output:

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

## Scope and failure logs

Compact mode is designed primarily for builds and tests. Reporting and
inspection goals such as `dependency:tree`, `help:effective-pom`, and
`help:active-profiles` may need `--full`.

Summaries are deterministic and conservative. Unsupported formats fall back to
at most 80 lines from the Maven log. The wrapper does not inspect the POM,
classify every Maven plugin, reconstruct test counts, or call an AI service.

Compact-mode failure logs remain under `.agent-logs/maven/` in the current
project. Successful logs are deleted unless `--keep-log` is supplied. After a
failed run, `mvn-lite` removes its logs older than seven days, including logs
retained by `--keep-log`. Move any log that must be kept longer. Set
`MVN_LITE_LOG_DIR` to use another destination. Retained raw logs are
authoritative, and projects adopting `mvn-lite` should ignore `.agent-logs/`.

A project may optionally define its own `./scripts/build` wrapper for
project-specific verification policy, but that vocabulary belongs in the
application repository rather than here.

## Evidence

- [Financial engine app compatibility experiment](../experiments/test/PVR-LABS-FINANCIAL-ENGINE-APP.md)
- [Scriptella ETL smoke test](../experiments/test/SCRIPTELLA-MVN-LITE-SMOKE-TEST.md)
- [Apache Commons CLI smoke test](../experiments/test/APACHE-COMMONS-CLI-MVN-LITE-SMOKE-TEST.md)
