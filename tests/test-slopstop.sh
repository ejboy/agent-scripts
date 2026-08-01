#!/usr/bin/env bash
set -uo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/slopstop-test.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
bin="$test_root/bin"; mkdir -p "$bin"
runner="$root/experiments/slopstop/slopstop"
fail_test() { echo "FAIL: $1" >&2; exit 1; }
run_scan() { (PATH="$bin:$PATH" HOME="$test_root/home" SLOPSTOP_SAMPLE_INTERVAL=0 SLOPSTOP_WIDTH="${SLOPSTOP_WIDTH:-100}" "$runner" "$@"); }
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
[[ "$output" == *'SAFE TO STOP'* && "$output" == *'Colima'* ]] || fail_test 'empty Colima was not safe'
[[ "$output" != *'vite'* ]] || fail_test 'young process was reviewed'
[[ "$output" != *'Potential reclaim: unknown'* ]] || fail_test 'fake reclaim value was printed'

narrow_output="$(SLOPSTOP_WIDTH=60 run_scan)"
[[ "$narrow_output" == *$'SAFE TO STOP\n- Colima'* ]] || fail_test 'narrow safe layout was not used'
[[ "$narrow_output" == *$'PID: —  AGE: —  CPU: —  MEMORY: —'* ]] || fail_test 'narrow safe fields were missing'
if awk 'length($0) > 60 { exit 1 }' <<<"$narrow_output"; then :; else fail_test 'narrow output overflowed'; fi

for width in 79 80 89 90; do
	boundary_output="$(SLOPSTOP_WIDTH="$width" run_scan)"
	[[ "$boundary_output" == *$'SAFE TO STOP\n- Colima'* ]] || fail_test "width $width did not use compact layout"
	[[ "$boundary_output" == *'Running; no active containers'* ]] || fail_test "width $width truncated the safety reason"
done
for width in 120; do
	boundary_output="$(SLOPSTOP_WIDTH="$width" run_scan)"
	[[ "$boundary_output" == *'PID     TYPE'* ]] || fail_test "width $width did not use the normal table"
	[[ "$boundary_output" == *'Running; no active containers'* ]] || fail_test "width $width truncated the safety reason"
done

# The globally selected Docker daemon must not affect Colima classification.

# A stopped Colima instance is omitted.
printf '%s\n' '{"status":"Stopped","runtime":"docker"}' >"$FAKE_COLIMA_STATUS"
output="$(run_scan)"
[[ "$output" == *$'SAFE TO STOP\nNone.'* ]] || fail_test 'stopped Colima was reported safe'
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
[[ "$output" == *$'SAFE TO STOP\nNone.'* ]] || fail_test 'runtime query failure was reported safe'
unset FAKE_DOCKER_FAILURE

printf '%s\n' '{"status":"Running","runtime":"containerd","profile":"default"}' >"$FAKE_COLIMA_STATUS"
output="$(run_scan)"
[[ "$output" == *'Colima'* && "$output" == *'Running; no active containers'* ]] || fail_test 'containerd Colima was not queried'
printf '%s\n' '{"status":"Running","runtime":"unknown"}' >"$FAKE_COLIMA_STATUS"
output="$(run_scan)"
[[ "$output" == *$'SAFE TO STOP\nNone.'* ]] || fail_test 'unknown Colima runtime was reported safe'
printf '%s\n' '{"status":"Running","runtime":"docker"}' >"$FAKE_COLIMA_STATUS"
rm -f "$bin/colima"
output="$(run_scan)"
[[ "$output" == *$'SAFE TO STOP\nNone.'* ]] || fail_test 'unavailable Colima was not skipped'

# With every detector unavailable and no process rows, the scan is read-only
# and produces both empty sections without touching the host.
: >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" == *$'SAFE TO STOP\nNone.'* && "$output" == *$'NEEDS REVIEW\nNone.'* ]] || fail_test 'empty scan was not reported cleanly'
[[ ! -s "$FAKE_COLIMA_CALLS" && ! -s "$FAKE_BROWSER_CALLS" ]] || fail_test 'read-only scan changed fixture state'

printf '%s\n' \
  "developer  200  1  10:00:00  8.2  420000 /opt/opencode opencode --serve --workspace '/project with spaces'" \
  'developer  201  1  30:00 25.0  100000 /opt/opencode opencode --serve' \
  'developer  202  1  2-00:00:00 1.0 3000000 /usr/bin/java org.gradle.launcher.daemon.bootstrap.GradleDaemon' \
  'developer  203  1  10-00:00:00 90.0 100000 /usr/bin/node mystery' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" == *'200     opencode'* ]] || fail_test 'old OpenCode was not reviewed'
[[ "$output" != *'201     opencode'* ]] || fail_test 'young high CPU OpenCode was reviewed'
[[ "$output" == *'202     java'* ]] || fail_test 'high-memory Gradle was not reviewed'
[[ "$output" != *'203     node'* && "$output" != *'kernel_task'* ]] || fail_test 'unrecognized/system process was reviewed'

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
# After the initial snapshot(s), revalidation sees no matching process.
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
[[ "$(run_scan --help)" == *'Usage: slopstop'* ]] || fail_test 'help failed'

# Progress lifecycle: classification work must finish before the progress line is
# cleared. After clear, no expensive external commands (ps/id/sort/awk) run.
progress_shown="$test_root/progress-shown"
progress_cleared="$test_root/progress-cleared"
post_clear_log="$test_root/post-clear-commands"
: >"$post_clear_log"
rm -f "$progress_shown" "$progress_cleared"
make_stub id 'if [[ -f "'"$progress_cleared"'" ]]; then echo id >>"'"$post_clear_log"'"; fi; echo developer'
make_stub ps 'if [[ -f "'"$progress_cleared"'" ]]; then echo ps >>"'"$post_clear_log"'"; fi; cat "$FAKE_PS_OUTPUT"'
make_stub sort 'if [[ -f "'"$progress_cleared"'" ]]; then echo sort >>"'"$post_clear_log"'"; fi; /usr/bin/sort "$@"'
make_stub awk 'if [[ -f "'"$progress_cleared"'" ]]; then echo awk >>"'"$post_clear_log"'"; fi; /usr/bin/awk "$@"'
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
[[ "$output" != *'Scanning developer workloads'* ]] || fail_test 'progress text leaked into non-TTY output'
[[ "$output" == *'NEEDS REVIEW'* && "$output" == *'200     opencode'* ]] || fail_test 'review report missing after progress lifecycle'

bash -n "$runner" || fail_test 'syntax check failed'
echo 'slopstop tests passed'
