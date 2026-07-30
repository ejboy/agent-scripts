# Scriptella ETL `mvn-lite` smoke test

Date: 2026-07-30

Status: Complete.

## Context

[Scriptella ETL](https://github.com/scriptella/scriptella-etl) is an open-source
Extract-Transform-Load and script-execution tool written in Java. During work to
modernize its multi-module Maven build, normal Maven output consumed substantial
agent context: the JDK 17 reactor test streamed compiler warnings, per-test output,
Javadocs, summaries, and plugin diagnostics across hundreds of lines.

The project workflow switched from invoking Maven directly to using
`agent-scripts/scripts/mvn-lite`. This was a practical compatibility and
agent-output smoke test, not a controlled performance benchmark.

## Smoke-test result

The equivalent JDK 17 reactor test completed successfully through `mvn-lite` in
11.137 seconds. Its complete agent-visible success output was one line:

```text
PASS · 11.137 s
```

The result establishes that `mvn-lite` can drive the tested Scriptella reactor
workflow while reducing successful output to a compact status. It does not show
that Maven executed faster: `mvn-lite` changes output policy, not Maven's build
performance.

## Practical before and after

| Property | Normal Maven | `mvn-lite` |
| --- | --- | --- |
| Successful run | Streams reactor setup, compiler warnings, every test class, Javadocs, summaries, and plugin output | Prints one line: `PASS · 11.137 s` |
| Failure | Produces a large Maven log that requires manual diagnosis | Prints a compact summary with recognized goals, causes, failed tests, and relevant errors |
| Maven flags | Uses only the flags explicitly provided | Adds `-B`, `-ntp`, and `-Dstyle.color=never` in compact mode when equivalent flags are absent |
| Diagnostics | Full output is immediately visible but noisy | Retains detailed output under `.agent-logs/maven/` on failure |
| Full output | Default behavior | Available with `mvn-lite --full ...` |
| JDK selection | Determined by the shell and environment | Unchanged; select the JDK with `JAVA_HOME` before invocation |

`mvn-lite` operates in the caller's current directory. It prefers an executable
`./mvnw` there and otherwise falls back to `mvn` from `PATH`, so it preserves the
project's Maven Wrapper choice when one is present.

## Interpretation

For this Scriptella workflow, the main benefit was context efficiency. Normal
Maven exposed useful information, but successful runs made the agent consume
hundreds of lines that did not affect the next action. `mvn-lite` privately
captured that output and surfaced only the successful result and Maven-reported
duration.

On failure, the policy changes: the complete Maven log is retained, while the
terminal receives a conservative summary for recognized compiler, test,
dependency, plugin-goal, and Maven-command failures. Unrecognized formats fall
back to a bounded log tail. The retained raw log remains authoritative.

## Limitations

- This was a single successful smoke-test observation, not a repeated benchmark.
- The experiment did not retain a byte or line count for the normal Maven output;
  “hundreds of lines” is the observed order of magnitude.
- No Scriptella-specific failure corpus was induced or measured.
- The 11.137-second duration is Maven's reported time for this run and is not
  evidence of a speed improvement.
- Build time and output vary with source state, dependency caches, machine load,
  Maven version, and JDK.

## Conclusion

The Scriptella ETL JDK 17 reactor smoke test passed through `mvn-lite` with the
one-line result `PASS · 11.137 s`. The wrapper did not make Maven faster; it made a
successful agent build dramatically less token-expensive while preserving
detailed failure logs and an explicit full-output mode for diagnosis.
