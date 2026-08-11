# Browser helpers and direct Chrome comparison evidence

Date: 2026-08-10

Status: Complete with a managed-browser reuse issue.

## Method

The website's local `index.html` was rendered at a 414 by 736 viewport with a
500 ms virtual-time budget. `html-screenshot` rendered it twice to separate
files and once while replacing an existing output. A direct headless Chrome
command used the equivalent rendering flags. Standard output and error were
captured separately.

The test also exercised missing-browser and missing-input failures. A managed
Chrome session was already active before this experiment, so it was preserved
and not stopped.

## Results

| Check | Result |
| --- | --- |
| Helper render exit status | 0 on both runs |
| Direct Chrome exit status | 0 |
| Dimensions | All images were 414 by 736 pixels |
| Determinism | Both helper images and direct image had the same SHA-256 digest |
| Output replacement | Passed; existing output was replaced on success |
| Failed replacement recovery | Passed; pre-existing sentinel content survived |
| Missing Chrome executable | Exit 1 with a concise named error |
| Missing HTML input | Exit 1 with a concise named error |
| Managed startup/reuse | Failed; existing DevTools session caused exit 1 |

The three successful screenshots were byte-identical and 154,454 bytes each.
Across two helper renders, visible output was 705 bytes and eight lines. One
direct Chrome render emitted 1,402 bytes and 11 lines. The helper filtered
repeated display-link diagnostics but still exposed other Chrome process and
allocator warnings.

## Issues and inefficiencies

- `launch-browser` reported `Chrome DevTools is already running` instead of
  reusing the existing managed session. This conflicts with the website guidance
  to “start or reuse” the managed browser.
- The experiment could not safely test managed-session cleanup because the
  session predated the experiment. Stopping it would have changed external state
  not created by this run.
- `html-screenshot` still printed non-actionable macOS process-policy and
  allocator diagnostics in normal mode. Its filtering reduced noise but did not
  make successful output consistently one line.
- Direct and helper rendering are functionally equivalent for the tested local
  page because the helper is a policy wrapper around the same browser flags.
  The observed value is argument consistency, output protection, validation,
  and diagnostic filtering rather than different rendering.

## Conclusion

`html-screenshot` produced deterministic, byte-identical output relative to the
equivalent direct Chrome command and handled replacement failures safely. Its
input validation was more actionable and its successful terminal output was
smaller, though still noisy. Managed-browser reuse did not work as documented
when DevTools was already active and needs separate correction or documentation.

## Quiet-output rerun: 2026-08-10

`html-screenshot` was updated to suppress Chrome stderr after a successful
non-verbose render while continuing to retain it for `--verbose` and failed
renders. A real Chrome smoke test rendered a local HTML fixture successfully and
printed exactly one line naming the screenshot path. The resulting PNG was
6,158 bytes. Focused automated tests also confirmed that successful default
output excludes a simulated non-actionable diagnostic, verbose output includes
it, and failure output retains Chrome's error evidence.

This closes the successful-output noise issue. The separate managed-session
reuse issue belongs to `launch-browser`, which did not change in this rerun.
