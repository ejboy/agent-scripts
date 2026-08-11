# Apache Commons CLI `mvn-lite` smoke test

Date: 2026-08-10

Status: Complete.

## Project selection

[Apache Commons CLI](https://github.com/apache/commons-cli) is a small,
Apache-licensed Java library for parsing command-line options. It complements the
larger, multi-module Scriptella experiment with a conventional single-module
library build:

- 143 files and 1.6 MB of extracted source at the tested revision
- one `pom.xml`
- 46 `*Test.java` source files
- 985 tests executed by Maven
- no Maven Wrapper, which exercises `mvn-lite`'s fallback to `mvn` on `PATH`

The experiment pinned commit
[`a98d307261347ee11d2f9c4f43693db31fc0a392`](https://github.com/apache/commons-cli/commit/a98d307261347ee11d2f9c4f43693db31fc0a392)
rather than testing a moving branch.

## Environment and command

- macOS 15.6.1, x86-64
- Eclipse Temurin OpenJDK 24.0.1
- Apache Maven 3.9.9
- `mvn-lite` 0.2.0

From the extracted project root, the successful test was:

```sh
/path/to/agent-scripts/scripts/mvn-lite --keep-log test
```

`--keep-log` retained the successful Maven log for measurement. It does not
change Maven's goals or the terminal summary.

## Results

The Maven test lifecycle completed successfully in a fresh source checkout. The
complete normal terminal result from `mvn-lite` was:

```text
PASS · 26.995 s
```

Maven reported 985 tests, 0 failures, 0 errors, and 61 skipped. The retained
underlying Maven log contained 203 lines and 15,079 bytes. These counts are a
description of this run, not a general performance benchmark.

A controlled failure used a nonexistent Surefire test selector:

```sh
/path/to/agent-scripts/scripts/mvn-lite -Dtest=DefinitelyMissingTest test
```

`mvn-lite` preserved Maven's nonzero exit status and produced a concise,
actionable diagnostic:

```text
FAIL

Failure summary:
  Goal: org.apache.maven.plugins:maven-surefire-plugin:3.5.6:test (default-test)
  Cause: No tests matching pattern "DefinitelyMissingTest" were executed! (Set -Dsurefire.failIfNoSpecifiedTests=false to ignore this error.)
```

It also printed the retained full-log path and the `--full` rerun hint.

## Interpretation

The experiment confirms both primary wrapper paths on a compact, representative
OSS Maven library:

- a real compile-and-test lifecycle succeeds while 203 lines of Maven output are
  reduced to one agent-visible status line;
- a Surefire goal failure remains nonzero and surfaces the failed goal and direct
  cause without requiring the full log for initial triage.

The project does not include `mvnw`, so this result specifically covers the
system-Maven fallback. Scriptella remains the complementary evidence for a
multi-module reactor.

## Limitations

- This was one success run and one controlled failure, not a repeated benchmark.
- The local Maven dependency cache was not controlled; elapsed time will vary
  with cache state, network, machine load, Maven, and JDK.
- `test` does not exercise later lifecycle phases such as packaging, signing, or
  deployment.
- The failure case tests Surefire goal summarization, not compiler or dependency
  failure parsing.
- The retained log includes the quieting flags that `mvn-lite` adds (`-B`,
  `-ntp`, and `-Dstyle.color=never`), so its line count is not a byte-for-byte
  measurement of an unwrapped interactive Maven invocation.

## Conclusion

Apache Commons CLI is a useful small companion fixture for `mvn-lite`: its pinned
single-module build ran 985 tests successfully, compacted a 203-line Maven log to
one line, and produced a focused diagnostic for an induced Surefire failure.
