# Extended real-project build-wrapper evidence

Date: 2026-08-10

Status: Complete for available Maven and npm workflows.

## Scope

Matched direct and wrapped runs were collected from:

- AIBadger VS Code: npm success and representative assertion failure
- StatLite's Spring Actuator demo: Maven success and unknown-goal failure
- Scriptella ETL: multi-module Maven success

The npm measurements are detailed in the dedicated comparison report. No second
local repository used `npm-lite`'s compact `verify` or `test:unit` interface, so
the experiment did not manufacture an additional “real-project” npm claim from
an unsupported script. Other npm scripts pass through by design.

## Maven results

| Project and case | Direct exit | Wrapped exit | Direct output | Wrapped output |
| --- | ---: | ---: | ---: | ---: |
| Spring demo success | 0 | 0 | 5,564 bytes, 70 lines | 16 bytes, 1 line |
| Spring demo unknown goal | 1 | 1 | 2,683 bytes, 28 lines | 272 bytes, 9 lines |
| Scriptella reactor success | 0 | 0 | 66,812 bytes, 928 lines | 17 bytes, 1 line |

The Spring demo direct and wrapped success wall times were 7.431 and 5.983
seconds. Direct and wrapped failure times were 1.699 and 1.739 seconds. The
Scriptella direct and wrapped times were 13.622 and 13.397 seconds. Run order,
JVM startup, caches, and machine activity prevent treating these small
differences as performance evidence.

The Spring failure summary identified Maven's unknown lifecycle phase and
retained a 2,683-byte raw log, equal to the combined size of direct Maven's
stdout and stderr. Both wrapped success results were one line:

```text
PASS · 4.332 s
PASS · 11.792 s
```

## Issues and inefficiencies

- The Spring demo's direct Maven output included 997 bytes of JVM diagnostics on
  stderr even on success. Compact mode hid them on success and retained them in
  the failure log, which is useful but means the raw log remains necessary when
  environment warnings matter.
- Warm caches and sequential execution favor later runs unpredictably. These
  observations compare output and correctness, not build speed.
- Only one locally available repository exercised `npm-lite` compact mode. The
  npm conclusion is therefore strong for that workflow but not broad ecosystem
  compatibility evidence.
- The induced Maven failure was an unknown goal, not a compiler, dependency, or
  test failure. Existing wrapper tests cover those parsers, but more real-project
  failure evidence would still be valuable.

## Conclusion

Across two Maven projects and the available npm project, the wrappers preserved
exit status and underlying results while greatly reducing successful output.
Recognized failures retained authoritative logs and exposed enough information
for the next action. The evidence supports context-efficiency claims, not speed
claims or universal compatibility.
