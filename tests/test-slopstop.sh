#!/usr/bin/env bash
set -uo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/slopstop-test.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
bin="$test_root/bin"; mkdir -p "$bin"
runner="$root/experiments/slopstop/slopstop"
fail_test() { echo "FAIL: $1" >&2; exit 1; }
run_scan() { (PATH="$bin:$PATH" HOME="$test_root/home" SLOPSTOP_WIDTH="${SLOPSTOP_WIDTH:-100}" "$runner" "$@"); }
make_stub() { local name="$1" body="$2"; printf '%s\n' '#!/usr/bin/env bash' "$body" >"$bin/$name"; chmod +x "$bin/$name"; }
make_stub uname 'echo Darwin'
make_stub id 'echo developer'
make_stub sleep 'exit 0'
make_stub ps 'cat "$FAKE_PS_OUTPUT"'
make_stub kill 'exit 0'
make_stub colima 'case "$1 $2" in "status --json") cat "$FAKE_COLIMA_STATUS" ;; esac; case "$1" in stop) echo stopped >>"$FAKE_COLIMA_CALLS" ;; esac'
make_stub docker 'if [[ "$1" == --context ]]; then [[ -n "${FAKE_DOCKER_FAILURE:-}" ]] && exit 1; cat "$FAKE_CONTAINERS"; else cat "$FAKE_GLOBAL_CONTAINERS"; fi'
make_stub nerdctl '[[ "$1" == --address && "$2" == unix://* ]] || exit 2; cat "$FAKE_CONTAINERS"'
make_stub launchctl 'case "$1" in print) exit 1;; esac'
make_stub launch-browser 'echo "$*" >>"$FAKE_BROWSER_CALLS"'

export FAKE_PS_OUTPUT="$test_root/ps"
export FAKE_COLIMA_STATUS="$test_root/colima-status"
export FAKE_COLIMA_CALLS="$test_root/colima-calls"
export FAKE_CONTAINERS="$test_root/containers"
export FAKE_GLOBAL_CONTAINERS="$test_root/global-containers"
export FAKE_BROWSER_CALLS="$test_root/browser-calls"
# Some Colima versions omit the status field on successful running output.
printf '%s\n' '{"runtime":"docker","docker_socket":"unix:///Users/test/.colima/default/docker.sock"}' >"$FAKE_COLIMA_STATUS"
: >"$FAKE_CONTAINERS"; : >"$FAKE_COLIMA_CALLS"; : >"$FAKE_BROWSER_CALLS"
printf '%s\n' global-container >"$FAKE_GLOBAL_CONTAINERS"

printf '%s\n' \
  'developer  101  1  1-00:00:00  1.0  200000 /usr/local/bin/node /project with spaces/vite --host' \
  'other      102  1  2-00:00:00 50.0 400000 /usr/bin/kernel_task' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" == *'Safe to stop'* && "$output" == *'Colima'* ]] || fail_test 'empty Colima was not safe'
[[ "$output" == *'Running; no active containers'* ]] || fail_test 'Colima reason missing'
[[ "$output" != *'vite'* ]] || fail_test 'young process was reviewed'
[[ "$output" != *'Potential reclaim: unknown'* ]] || fail_test 'fake reclaim value was printed'
[[ "$output" != *'SAFE TO STOP'* && "$output" != *'NEEDS REVIEW'* ]] || fail_test 'ALL CAPS section headers still present'
[[ "$output" != *'None.'* ]] || fail_test 'old None. empty marker still present'

# Stacked layout when detail room is tight (width < 12+2+20 = 34).
narrow_output="$(SLOPSTOP_WIDTH=33 run_scan)"
[[ "$narrow_output" == *$'\nColima\n'* ]] || fail_test 'narrow layout did not stack Colima'
[[ "$narrow_output" == *'Running; no active containers'* ]] || fail_test 'narrow layout truncated the safety reason'
if awk 'length($0) > 33 { exit 1 }' <<<"$narrow_output"; then :; else fail_test 'narrow output overflowed'; fi

# Wide enough for single-line name + detail rows.
for width in 80 100 120; do
	boundary_output="$(SLOPSTOP_WIDTH="$width" run_scan)"
	[[ "$boundary_output" == *'Colima'* && "$boundary_output" == *'Running; no active containers'* ]] || fail_test "width $width missing Colima row"
	[[ "$boundary_output" != *$'\nColima\n  '* ]] || fail_test "width $width used stacked layout unexpectedly"
done

# A stopped Colima instance is omitted.
printf '%s\n' '{"status":"Stopped","runtime":"docker"}' >"$FAKE_COLIMA_STATUS"
output="$(run_scan)"
[[ "$output" == *$'Safe to stop\n(none)'* ]] || fail_test 'stopped Colima was reported safe'
printf '%s\n' '{"status":"Running","runtime":"docker"}' >"$FAKE_COLIMA_STATUS"

# Platform rejection must happen before any detector can run.
make_stub uname 'echo Linux'
set +e
output="$(run_scan 2>&1)"; exit_status=$?
set -e
[[ "$exit_status" -ne 0 && "$output" == *'supports macOS only'* ]] || fail_test 'unsupported platform was accepted'
make_stub uname 'echo Darwin'

printf '%s\n' container-1 >"$FAKE_CONTAINERS"
output="$(run_scan)"
[[ "$output" != *'Running; no active containers'* ]] || fail_test 'active Colima container was safe'
: >"$FAKE_CONTAINERS"
output="$(FAKE_DOCKER_FAILURE=1 run_scan)"
[[ "$output" == *$'Safe to stop\n(none)'* ]] || fail_test 'runtime query failure was reported safe'
unset FAKE_DOCKER_FAILURE

printf '%s\n' '{"status":"Running","runtime":"containerd","profile":"default"}' >"$FAKE_COLIMA_STATUS"
output="$(run_scan)"
[[ "$output" == *'Colima'* && "$output" == *'Running; no active containers'* ]] || fail_test 'containerd Colima was not queried'
printf '%s\n' '{"status":"Running","runtime":"unknown"}' >"$FAKE_COLIMA_STATUS"
output="$(run_scan)"
[[ "$output" == *$'Safe to stop\n(none)'* ]] || fail_test 'unknown Colima runtime was reported safe'
printf '%s\n' '{"status":"Running","runtime":"docker"}' >"$FAKE_COLIMA_STATUS"
rm -f "$bin/colima"
output="$(run_scan)"
[[ "$output" == *$'Safe to stop\n(none)'* ]] || fail_test 'unavailable Colima was not skipped'

# With every detector unavailable and no process rows, the scan is read-only
# and produces both empty sections without touching the host.
: >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" == *$'Safe to stop\n(none)'* && "$output" == *$'Needs review\n(none)'* ]] || fail_test 'empty scan was not reported cleanly'
[[ ! -s "$FAKE_COLIMA_CALLS" && ! -s "$FAKE_BROWSER_CALLS" ]] || fail_test 'read-only scan changed fixture state'

# Review heuristics use instantaneous ps %CPU (not top).
printf '%s\n' \
  "developer  200  1  10:00:00  8.2  420000 /opt/opencode opencode --serve --workspace '/project with spaces'" \
  'developer  201  1  30:00 25.0  100000 /opt/opencode opencode --serve' \
  'developer  202  1  2-00:00:00 1.0 3000000 /usr/bin/java org.gradle.launcher.daemon.bootstrap.GradleDaemon' \
  'developer  203  1  10-00:00:00 90.0 100000 /usr/bin/node mystery' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" == *'opencode'* && "$output" == *'pid 200'* ]] || fail_test 'old OpenCode was not reviewed with pid in details'
[[ "$output" == *'elevated CPU'* ]] || fail_test 'CPU review missing elevated-CPU detail'
[[ "$output" != *'pid 201'* ]] || fail_test 'young high CPU OpenCode was reviewed'
[[ "$output" == *'java'* && "$output" == *'pid 202'* ]] || fail_test 'high-memory Gradle was not reviewed'
[[ "$output" == *'high memory developer workload'* ]] || fail_test 'high-memory review missing detail'
[[ "$output" != *'pid 203'* && "$output" != *'kernel_task'* ]] || fail_test 'unrecognized/system process was reviewed'

# CPU below the normal threshold is omitted even when old.
printf '%s\n' \
  'developer  210  1  10:00:00  4.9  100000 /opt/opencode opencode --serve' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" != *'pid 210'* ]] || fail_test 'below-threshold CPU was reviewed'

# High CPU threshold: age >= 1h and CPU >= 20%.
printf '%s\n' \
  'developer  211  1  01:30:00  20.0  100000 /opt/opencode opencode --serve' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" == *'pid 211'* ]] || fail_test 'high-CPU threshold case was not reviewed'
printf '%s\n' \
  'developer  211  1  01:30:00  19.9  100000 /opt/opencode opencode --serve' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" != *'pid 211'* ]] || fail_test 'just-below high-CPU threshold was reviewed'

# --- Chunk 6: recognition families (all rows are old + above CPU threshold) ---
# Positive: each supported family must appear with its pid in details.
printf '%s\n' \
  'developer  301  1  10:00:00  8.0  100000 /opt/opencode opencode --serve' \
  'developer  302  1  10:00:00  8.0  100000 /usr/local/bin/bun run opencode --serve' \
  'developer  303  1  10:00:00  8.0  100000 /usr/bin/java org.gradle.launcher.daemon.bootstrap.GradleDaemon' \
  'developer  304  1  10:00:00  8.0  100000 /usr/bin/java org.jetbrains.kotlin.daemon.KotlinCompileDaemon' \
  'developer  305  1  10:00:00  8.0  100000 /opt/homebrew/bin/mvnd --status' \
  'developer  306  1  10:00:00  8.0  100000 /usr/local/bin/vite --host' \
  'developer  307  1  10:00:00  8.0  100000 /usr/local/bin/node /proj/node_modules/vite/bin/vite.js --host' \
  'developer  308  1  10:00:00  8.0  100000 /usr/local/bin/next dev' \
  'developer  309  1  10:00:00  8.0  100000 /usr/local/bin/node /proj/node_modules/next/dist/bin/next dev' \
  'developer  310  1  10:00:00  8.0  100000 /usr/local/bin/webpack serve' \
  'developer  311  1  10:00:00  8.0  100000 /usr/local/bin/nodemon server.js' \
  'developer  312  1  10:00:00  8.0  100000 /usr/bin/python3 -m http.server 8000' \
  'developer  313  1  10:00:00  8.0  100000 /usr/local/go/bin/go run ./cmd/api' \
  'developer  314  1  10:00:00  8.0  100000 /usr/local/bin/air' \
  'developer  315  1  10:00:00  8.0  100000 /Users/dev/.cargo/bin/cargo-watch -x run' \
  'developer  316  1  10:00:00  8.0  100000 /usr/local/bin/cargo watch -x test' \
  'developer  317  1  10:00:00  8.0  100000 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless --remote-debugging-port=9222' >"$FAKE_PS_OUTPUT"
rm -f "$bin/colima"
output="$(run_scan)"
for pid in 301 302 303 304 305 306 307 308 309 310 311 312 313 314 315 316 317; do
	[[ "$output" == *"pid $pid"* ]] || fail_test "recognition family pid $pid was not reviewed"
done
# Sort is primarily by CPU descending; equal CPUs keep a stable listing presence.
[[ "$output" == *'Needs review'* ]] || fail_test 'review section missing for recognition families'

# Negative: generic executables and system processes must not match by name alone.
printf '%s\n' \
  'developer  401  1  10:00:00 90.0 100000 /usr/bin/java -jar app.jar' \
  'developer  402  1  10:00:00 90.0 100000 /usr/local/bin/node server.js' \
  'developer  403  1  10:00:00 90.0 100000 /usr/local/bin/bun run index.ts' \
  'developer  404  1  10:00:00 90.0 100000 /usr/bin/python3 app.py' \
  'developer  405  1  10:00:00 90.0 100000 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \
  'developer  406  1  10:00:00 90.0 100000 /usr/bin/kernel_task' \
  'developer  407  1  10:00:00 90.0 100000 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer' \
  'developer  408  1  10:00:00 90.0 100000 /System/Library/Frameworks/CoreServices.framework/Frameworks/Metadata.framework/Support/mds_stores' \
  'other      409  1  10:00:00 90.0 400000 /opt/opencode opencode --serve' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
for pid in 401 402 403 404 405 406 407 408 409; do
	[[ "$output" != *"pid $pid"* ]] || fail_test "generic/system/other-user pid $pid was incorrectly reviewed"
done
[[ "$output" == *$'Needs review\n(none)'* ]] || fail_test 'expected empty review for negative recognition fixtures'

# CPU sort: higher CPU appears before lower among review rows.
printf '%s\n' \
  'developer  501  1  10:00:00  6.0  100000 /opt/opencode opencode --a' \
  'developer  502  1  10:00:00 40.0  100000 /opt/opencode opencode --b' \
  'developer  503  1  10:00:00 12.0  100000 /opt/opencode opencode --c' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
pos_hi="${output%%pid 502*}"; pos_mid="${output%%pid 503*}"; pos_lo="${output%%pid 501*}"
((${#pos_hi} < ${#pos_mid} && ${#pos_mid} < ${#pos_lo})) || fail_test 'review rows were not sorted by CPU descending'

# Review candidates are never stopped automatically.
: >"$FAKE_BROWSER_CALLS"
printf '%s\n' 'developer  520  1  10:00:00  8.0  100000 /opt/opencode opencode --serve' >"$FAKE_PS_OUTPUT"
output="$(run_scan --stop-safe)"
[[ "$output" == *'pid 520'* ]] || fail_test 'review row missing in stop-safe scan'
[[ "$output" != *'Stopped'* ]] || fail_test 'review candidate was stopped'
[[ ! -s "$FAKE_BROWSER_CALLS" ]] || fail_test 'stop-safe touched browser launcher for review-only scan'
make_stub colima 'case "$1 $2" in "status --json") cat "$FAKE_COLIMA_STATUS" ;; esac; case "$1" in stop) echo stopped >>"$FAKE_COLIMA_CALLS" ;; esac'
printf '%s\n' '{"status":"Running","runtime":"docker"}' >"$FAKE_COLIMA_STATUS"
: >"$FAKE_CONTAINERS"

# The existing launch-browser state is safe only when its recorded identity
# matches a live Chrome row and launchctl no longer owns the recorded service.
mkdir -p "$test_root/home/.browser-testing-profile"
printf 'service=xyz.pvrlabs.browser.test\npid=%s\n' "$$" >"$test_root/home/.browser-testing-profile/launch-state"
printf '%s\n' "developer  $$  1  9-00:00:00  0.0  100000 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless --remote-debugging-port=9222" >"$FAKE_PS_OUTPUT"
rm -f "$bin/colima"; : >"$FAKE_BROWSER_CALLS"
output="$(run_scan)"
[[ "$output" == *'Chrome'* && "$output" == *'Test browser; launcher exited'* ]] || fail_test 'recorded test browser was not safe'
output="$(run_scan --stop-safe)"
[[ "$output" == *'Stopped Chrome'* && "$(<"$FAKE_BROWSER_CALLS")" == '--stop' ]] || fail_test 'recorded browser cleanup failed'
rm -f "$test_root/home/.browser-testing-profile/launch-state"

make_stub colima 'case "$1 $2" in "status --json") cat "$FAKE_COLIMA_STATUS" ;; esac; case "$1" in stop) echo stopped >>"$FAKE_COLIMA_CALLS" ;; esac'
printf '%s\n' 'developer  300  1  9-00:00:00  0.0  100000 /opt/opencode opencode --serve' >"$FAKE_PS_OUTPUT"
: >"$FAKE_CONTAINERS"; : >"$FAKE_COLIMA_CALLS"
printf '%s\n' '{"status":"Running","runtime":"docker"}' >"$FAKE_COLIMA_STATUS"
output="$(printf '\n' | run_scan --stop)"
[[ "$output" == *'Colima'* && ! -s "$FAKE_COLIMA_CALLS" ]] || fail_test 'declined stop changed state'
output="$(printf 'y\n' | run_scan --stop)"
[[ "$output" == *'Stopped Colima'* && -s "$FAKE_COLIMA_CALLS" ]] || fail_test 'confirmed stop failed'
# Confirmed stop must invoke colima stop exactly once.
[[ "$(wc -l <"$FAKE_COLIMA_CALLS" | tr -d ' ')" == 1 ]] || fail_test 'confirmed stop did not run exactly once'
: >"$FAKE_COLIMA_CALLS"
output="$(run_scan --stop-safe)"
[[ "$output" == *'Stopped Colima'* && -s "$FAKE_COLIMA_CALLS" ]] || fail_test 'unprompted stop failed'
[[ "$(wc -l <"$FAKE_COLIMA_CALLS" | tr -d ' ')" == 1 ]] || fail_test 'unprompted stop did not run exactly once'

# Revalidation must skip when Colima is no longer safe, and must not stop.
colima_seen="$test_root/colima-status-seen"
rm -f "$colima_seen"
: >"$FAKE_COLIMA_CALLS"
make_stub colima '
case "$1 $2" in
  "status --json")
    if [[ -f "'"$colima_seen"'" ]]; then
      printf "%s\n" "{\"status\":\"Stopped\",\"runtime\":\"docker\"}"
    else
      : >"'"$colima_seen"'"
      cat "$FAKE_COLIMA_STATUS"
    fi
    ;;
esac
case "$1" in stop) echo stopped >>"$FAKE_COLIMA_CALLS" ;; esac
'
output="$(run_scan --stop-safe)"
[[ "$output" == *'Skipped Colima: state changed'* ]] || fail_test 'changed Colima state was not skipped'
[[ ! -s "$FAKE_COLIMA_CALLS" ]] || fail_test 'changed Colima state still stopped'
# Restore a stable Colima stub for later cases.
make_stub colima 'case "$1 $2" in "status --json") cat "$FAKE_COLIMA_STATUS" ;; esac; case "$1" in stop) echo stopped >>"$FAKE_COLIMA_CALLS" ;; esac'
printf '%s\n' '{"status":"Running","runtime":"docker"}' >"$FAKE_COLIMA_STATUS"
: >"$FAKE_CONTAINERS"

# Stop failure must be reported and yield a nonzero exit status.
make_stub colima 'case "$1 $2" in "status --json") cat "$FAKE_COLIMA_STATUS" ;; esac; case "$1" in stop) exit 1 ;; esac'
set +e
output="$(run_scan --stop-safe 2>&1)"; exit_status=$?
set -e
[[ "$exit_status" -ne 0 && "$output" == *'Failed to stop Colima'* ]] || fail_test 'Colima stop failure was not reported'
make_stub colima 'case "$1 $2" in "status --json") cat "$FAKE_COLIMA_STATUS" ;; esac; case "$1" in stop) echo stopped >>"$FAKE_COLIMA_CALLS" ;; esac'

# Browser candidate whose state changes before stop is skipped.
mkdir -p "$test_root/home/.browser-testing-profile"
printf 'service=xyz.pvrlabs.browser.test\npid=%s\n' "$$" >"$test_root/home/.browser-testing-profile/launch-state"
printf '%s\n' "developer  $$  1  9-00:00:00  0.0  100000 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless --remote-debugging-port=9222" >"$FAKE_PS_OUTPUT"
rm -f "$bin/colima"
: >"$FAKE_BROWSER_CALLS"
ps_calls="$test_root/ps-calls"
: >"$ps_calls"
make_stub ps '
echo ps >>"'"$ps_calls"'"
# First call is the initial identity snapshot; later calls include review ps and revalidation.
if [[ "$(wc -l <"'"$ps_calls"'" | tr -d " ")" -gt 2 ]]; then
  : >"$FAKE_PS_OUTPUT"
fi
cat "$FAKE_PS_OUTPUT"
'
output="$(run_scan --stop-safe)"
[[ "$output" == *'Skipped Chrome'* && "$output" == *'state changed'* ]] || fail_test 'changed browser state was not skipped'
[[ ! -s "$FAKE_BROWSER_CALLS" ]] || fail_test 'changed browser state still stopped'
make_stub ps 'cat "$FAKE_PS_OUTPUT"'
rm -f "$test_root/home/.browser-testing-profile/launch-state"
make_stub colima 'case "$1 $2" in "status --json") cat "$FAKE_COLIMA_STATUS" ;; esac; case "$1" in stop) echo stopped >>"$FAKE_COLIMA_CALLS" ;; esac'

set +e
output="$(run_scan --bogus 2>&1)"; exit_status=$?
set -e
[[ "$exit_status" -ne 0 && "$output" == *'Usage:'* ]] || fail_test 'unknown argument accepted'
help_output="$(run_scan --help)"
[[ "$help_output" == *'Usage: slopstop'* ]] || fail_test 'help failed'
[[ "$help_output" == *'--stop'* && "$help_output" == *'--stop-safe'* ]] || fail_test 'help missing stop modes'
[[ "$help_output" == *'Review candidates are never stopped automatically.'* ]] || fail_test 'help missing review safety note'
# Scan output should not repeat the long stop how-to footer.
scan_with_safe="$(run_scan)"
[[ "$scan_with_safe" == *'Colima'* ]] || fail_test 'expected a safe Colima row for footer check'
[[ "$scan_with_safe" != *'Run `slopstop --stop`'* ]] || fail_test 'scan still prints stop how-to footer'

# Progress lifecycle: classification finishes before the progress line is cleared.
# After clear, no expensive external commands (ps/id/sort) run.
progress_shown="$test_root/progress-shown"
progress_cleared="$test_root/progress-cleared"
post_clear_log="$test_root/post-clear-commands"
: >"$post_clear_log"
rm -f "$progress_shown" "$progress_cleared"
make_stub id 'if [[ -f "'"$progress_cleared"'" ]]; then echo id >>"'"$post_clear_log"'"; fi; echo developer'
make_stub ps 'if [[ -f "'"$progress_cleared"'" ]]; then echo ps >>"'"$post_clear_log"'"; fi; cat "$FAKE_PS_OUTPUT"'
make_stub sort 'if [[ -f "'"$progress_cleared"'" ]]; then echo sort >>"'"$post_clear_log"'"; fi; /usr/bin/sort "$@"'
printf '%s\n' \
  "developer  200  1  10:00:00  8.2  420000 /opt/opencode opencode --serve" \
  'developer  202  1  2-00:00:00 1.0 3000000 /usr/bin/java org.gradle.launcher.daemon.bootstrap.GradleDaemon' >"$FAKE_PS_OUTPUT"
make_stub colima 'case "$1 $2" in "status --json") cat "$FAKE_COLIMA_STATUS" ;; esac'
: >"$FAKE_CONTAINERS"
output="$(
	SLOPSTOP_PROGRESS_SHOWN_FILE="$progress_shown" \
	SLOPSTOP_PROGRESS_CLEARED_FILE="$progress_cleared" \
	run_scan
)"
[[ -f "$progress_shown" ]] || fail_test 'progress shown marker was not written'
[[ -f "$progress_cleared" ]] || fail_test 'progress cleared marker was not written'
[[ ! -s "$post_clear_log" ]] || fail_test "expensive command ran after progress clear: $(tr '\n' ' ' <"$post_clear_log")"
[[ "$output" != *'Preparing report'* && "$output" != *'Sampling CPU'* ]] || fail_test 'progress text leaked into non-TTY output'
[[ "$output" == *'Needs review'* && "$output" == *'pid 200'* && "$output" == *'opencode'* ]] || fail_test 'review report missing after progress lifecycle'

bash -n "$runner" || fail_test 'syntax check failed'
echo 'slopstop tests passed'
