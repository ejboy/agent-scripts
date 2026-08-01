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
output="$(printf '\n' | run_scan --stop)"
[[ "$output" == *'Colima'* && ! -s "$FAKE_COLIMA_CALLS" ]] || fail_test 'declined stop changed state'
output="$(printf 'y\n' | run_scan --stop)"
[[ "$output" == *'Stopped Colima'* && -s "$FAKE_COLIMA_CALLS" ]] || fail_test 'confirmed stop failed'
: >"$FAKE_COLIMA_CALLS"
output="$(run_scan --stop-safe)"
[[ "$output" == *'Stopped Colima'* && -s "$FAKE_COLIMA_CALLS" ]] || fail_test 'unprompted stop failed'

set +e
output="$(run_scan --bogus 2>&1)"; exit_status=$?
set -e
[[ "$exit_status" -ne 0 && "$output" == *'Usage:'* ]] || fail_test 'unknown argument accepted'
[[ "$(run_scan --help)" == *'Usage: slopstop'* ]] || fail_test 'help failed'
bash -n "$runner" || fail_test 'syntax check failed'
echo 'slopstop tests passed'
