#!/usr/bin/env bash
set -uo pipefail
exp="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/slopstop-test.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT
bin="$test_root/bin"; mkdir -p "$bin"
runner="$exp/slopstop"
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
make_stub nerdctl '
addr=""; ns=""
while (($# > 0)); do
  case "$1" in
    --address) addr="$2"; shift 2 ;;
    --namespace) ns="$2"; shift 2 ;;
    ps) shift; break ;;
    *) shift ;;
  esac
done
[[ "$addr" == unix://* ]] || exit 2
if [[ "$ns" == k8s.io ]]; then
  [[ -n "${FAKE_NERDCTL_K8S_FAIL:-}" ]] && exit 1
  cat "$FAKE_K8S_CONTAINERS"
  exit 0
fi
cat "$FAKE_CONTAINERS"
'
make_stub gradle 'case "$1" in --status) cat "$FAKE_GRADLE_STATUS" ;; --stop) echo stopped >>"$FAKE_GRADLE_CALLS" ;; esac'
make_stub mvnd 'case "$1" in --status) cat "$FAKE_MVND_STATUS" ;; --stop) echo stopped >>"$FAKE_MVND_CALLS" ;; esac'
make_stub launchctl 'cat "$FAKE_LAUNCHCTL_LIST"'
export FAKE_PS_OUTPUT="$test_root/ps"
export FAKE_COLIMA_STATUS="$test_root/colima-status"
export FAKE_COLIMA_CALLS="$test_root/colima-calls"
export FAKE_CONTAINERS="$test_root/containers"
export FAKE_K8S_CONTAINERS="$test_root/k8s-containers"
export FAKE_GLOBAL_CONTAINERS="$test_root/global-containers"
export FAKE_GRADLE_STATUS="$test_root/gradle-status"
export FAKE_GRADLE_CALLS="$test_root/gradle-calls"
export FAKE_MVND_STATUS="$test_root/mvnd-status"
export FAKE_MVND_CALLS="$test_root/mvnd-calls"
export FAKE_LAUNCHCTL_LIST="$test_root/launchctl-list"
printf '%s\n' 'PID	Status	Label' >"$FAKE_LAUNCHCTL_LIST"
printf '%s\n' '{"status":"Running","runtime":"docker","docker_socket":"unix:///Users/test/.colima/default/docker.sock"}' >"$FAKE_COLIMA_STATUS"
: >"$FAKE_CONTAINERS"; : >"$FAKE_COLIMA_CALLS"; : >"$FAKE_K8S_CONTAINERS"
: >"$FAKE_GRADLE_CALLS"; : >"$FAKE_MVND_CALLS"
printf '%s\n' 'No Gradle daemons are running.' >"$FAKE_GRADLE_STATUS"
printf '%s\n' 'No daemons are running.' >"$FAKE_MVND_STATUS"
printf '%s\n' global-container >"$FAKE_GLOBAL_CONTAINERS"

printf '%s\n' \
  'developer  101  1  1-00:00:00  1.0  200000 /usr/local/bin/node /project with spaces/vite --host' \
  'other      102  1  2-00:00:00 50.0 400000 /usr/bin/kernel_task' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" == *'Safe to stop'* && "$output" == *'--stop-safe'* && "$output" == *'Colima'* ]] || fail_test 'empty Colima was not safe'
[[ "$output" == *'Running; no active containers'* ]] || fail_test 'Colima reason missing'
[[ "$output" != *'vite'* ]] || fail_test 'young process was reviewed'
[[ "$output" != *'SAFE TO STOP'* && "$output" != *'NEEDS REVIEW'* ]] || fail_test 'ALL CAPS section headers still present'
[[ "$output" != *'None.'* ]] || fail_test 'old None. empty marker still present'

narrow_output="$(SLOPSTOP_WIDTH=33 run_scan)"
[[ "$narrow_output" == *$'\nColima\n'* || "$narrow_output" == *'Colima'* ]] || fail_test 'narrow layout missing Colima'
# Must keep a recognizable prefix of the safety reason (not any unrelated "...").
[[ "$narrow_output" == *'Running; no active containers'* || "$narrow_output" == *'Running; no active cont...'* || "$narrow_output" == *'Running; no active'* ]] || fail_test 'narrow layout lost safety reason'
while IFS= read -r line; do
	((${#line} <= 33)) || fail_test "narrow output overflowed: ${#line} <$line>"
done <<<"$narrow_output"

for width in 80 100 120; do
	boundary_output="$(SLOPSTOP_WIDTH="$width" run_scan)"
	[[ "$boundary_output" == *'Colima'* && "$boundary_output" == *'Running; no active containers'* ]] || fail_test "width $width missing Colima row"
done

printf '%s\n' '{"status":"Stopped","runtime":"docker"}' >"$FAKE_COLIMA_STATUS"
output="$(run_scan)"
[[ "$output" == *$'Safe to stop\n(none)'* ]] || fail_test 'stopped Colima was reported safe'

printf '%s\n' '{"status":"Starting","runtime":"docker"}' >"$FAKE_COLIMA_STATUS"
: >"$FAKE_CONTAINERS"
output="$(run_scan)"
[[ "$output" == *$'Safe to stop\n(none)'* ]] || fail_test 'Starting Colima was reported safe'

# Some Colima versions omit the status field on successful running output.
# Missing status + empty containers must still be safe; only explicit non-Running fails.
printf '%s\n' '{"runtime":"docker","docker_socket":"unix:///Users/test/.colima/default/docker.sock"}' >"$FAKE_COLIMA_STATUS"
: >"$FAKE_CONTAINERS"
output="$(run_scan)"
[[ "$output" == *'Colima'* && "$output" == *'Running; no active containers'* ]] || fail_test 'Colima without status field was not safe'

printf '%s\n' '{"status":"Running","runtime":"docker","kubernetes":true}' >"$FAKE_COLIMA_STATUS"
: >"$FAKE_CONTAINERS"
output="$(run_scan)"
[[ "$output" == *$'Safe to stop\n(none)'* ]] || fail_test 'Kubernetes-enabled Colima was reported safe'

printf '%s\n' '{"status":"Running","runtime":"docker+k3s"}' >"$FAKE_COLIMA_STATUS"
: >"$FAKE_CONTAINERS"
output="$(run_scan)"
[[ "$output" == *$'Safe to stop\n(none)'* ]] || fail_test 'docker+k3s Colima was reported safe'

printf '%s\n' '{"status":"Running","runtime":"docker"}' >"$FAKE_COLIMA_STATUS"

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
: >"$FAKE_CONTAINERS"; : >"$FAKE_K8S_CONTAINERS"
output="$(run_scan)"
[[ "$output" == *'Colima'* && "$output" == *'Running; no active containers'* ]] || fail_test 'containerd Colima was not queried'

export FAKE_NERDCTL_K8S_FAIL=1
output="$(run_scan)"
[[ "$output" == *$'Safe to stop\n(none)'* ]] || fail_test 'k8s.io nerdctl failure still reported Colima safe'
unset FAKE_NERDCTL_K8S_FAIL

printf '%s\n' 'k8s-pod-container' >"$FAKE_K8S_CONTAINERS"
: >"$FAKE_CONTAINERS"
output="$(run_scan)"
[[ "$output" == *$'Safe to stop\n(none)'* ]] || fail_test 'k8s.io containers still reported Colima safe'
: >"$FAKE_K8S_CONTAINERS"

printf '%s\n' '{"status":"Running","runtime":"unknown"}' >"$FAKE_COLIMA_STATUS"
output="$(run_scan)"
[[ "$output" == *$'Safe to stop\n(none)'* ]] || fail_test 'unknown Colima runtime was reported safe'
printf '%s\n' '{"status":"Running","runtime":"docker"}' >"$FAKE_COLIMA_STATUS"
rm -f "$bin/colima"
output="$(run_scan)"
[[ "$output" == *$'Safe to stop\n(none)'* ]] || fail_test 'unavailable Colima was not skipped'

: >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" == *$'Safe to stop\n(none)'* && "$output" == *$'Needs review\n(none)'* ]] || fail_test 'empty scan was not reported cleanly'
[[ ! -s "$FAKE_COLIMA_CALLS" ]] || fail_test 'read-only scan changed fixture state'

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

printf '%s\n' 'developer  210  1  10:00:00  4.9  100000 /opt/opencode opencode --serve' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" != *'pid 210'* ]] || fail_test 'below-threshold CPU was reviewed'

printf '%s\n' 'developer  211  1  01:30:00  20.0  100000 /opt/opencode opencode --serve' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" == *'pid 211'* ]] || fail_test 'high-CPU threshold case was not reviewed'
printf '%s\n' 'developer  211  1  01:30:00  19.9  100000 /opt/opencode opencode --serve' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" != *'pid 211'* ]] || fail_test 'just-below high-CPU threshold was reviewed'

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
[[ "$output" == *'detached debug browser'* ]] || fail_test 'debug Chrome missing review reason'

printf '%s\n' \
  'developer  330  1  01:22  0.1  217244 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --remote-debugging-port=9222 --headless=new' \
  'developer  331  1  01:22  0.0  100000 /Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Versions/1/Helpers/Google Chrome Helper --type=renderer' \
  'developer  332  1  10:00:00 90.0 400000 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome' \
  'developer  333  1  01:22  0.0  1020 /bin/bash -c /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless --remote-debugging-port=9222' \
  'developer  335  1  10:00:00  0.1  100000 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --remote-debugging-port=9222' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" == *'pid 330'* && "$output" == *'detached debug browser'* ]] || fail_test 'young idle debug Chrome was not reviewed'
[[ "$output" == *'pid 335'* ]] || fail_test 'remote-debugging-only Chrome was not reviewed'
[[ "$output" != *'pid 332'* ]] || fail_test 'normal interactive Chrome was reviewed'
[[ "$output" != *'pid 331'* ]] || fail_test 'Chrome Helper was reviewed'
[[ "$output" != *'pid 333'* ]] || fail_test 'bash wrapper mentioning Chrome path was reviewed'

# launchctl kill-hint detection (PVR Labs launch-browser labels only).
printf '%s\n' \
  'PID	Status	Label' \
  '300	0	xyz.pvrlabs.browser.44498.10298' >"$FAKE_LAUNCHCTL_LIST"
printf '%s\n' \
  'developer  340  300  10:00:00  0.1  100000 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless --remote-debugging-port=9222' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" == *'pid 340'* && "$output" == *'kill: launchctl remove xyz.pvrlabs.browser.44498.10298'* ]] || fail_test 'wrapper-parent launch-browser Chrome missing kill hint'

printf '%s\n' \
  'PID	Status	Label' \
  '350	0	xyz.pvrlabs.browser.555.111' >"$FAKE_LAUNCHCTL_LIST"
printf '%s\n' \
  'developer  350  1  10:00:00  0.1  100000 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless --remote-debugging-port=9222' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" == *'pid 350'* && "$output" == *'kill: launchctl remove xyz.pvrlabs.browser.555.111'* ]] || fail_test 'direct-job launch-browser Chrome missing kill hint'

printf '%s\n' \
  'PID	Status	Label' \
  '360	0	com.example.browser' >"$FAKE_LAUNCHCTL_LIST"
printf '%s\n' \
  'developer  360  1  10:00:00  0.1  100000 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless --remote-debugging-port=9222' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" == *'pid 360'* && "$output" != *'launchctl remove'* ]] || fail_test 'unrelated launchd label produced kill hint'

printf '%s\n' \
  'PID	Status	Label' \
  '300	0	xyz.pvrlabs.browser.44498.10298; rm -rf /' >"$FAKE_LAUNCHCTL_LIST"
printf '%s\n' \
  'developer  370  300  10:00:00  0.1  100000 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless --remote-debugging-port=9222' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" == *'pid 370'* && "$output" != *'launchctl remove'* ]] || fail_test 'invalid launch-browser label produced kill hint'

printf '%s\n' 'PID	Status	Label' >"$FAKE_LAUNCHCTL_LIST"
printf '%s\n' \
  'developer  380  1  10:00:00  0.1  100000 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless --remote-debugging-port=9222' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" == *'pid 380'* && "$output" != *'launchctl remove'* ]] || fail_test 'no matching launchctl job produced kill hint'

# Narrow/normal widths render the kill hint without overflow.
printf '%s\n' \
  'PID	Status	Label' \
  '300	0	xyz.pvrlabs.browser.44498.10298' >"$FAKE_LAUNCHCTL_LIST"
printf '%s\n' \
  'developer  340  300  10:00:00  0.1  100000 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless --remote-debugging-port=9222' >"$FAKE_PS_OUTPUT"
for width in 20 33; do
	width_output="$(SLOPSTOP_WIDTH="$width" run_scan)"
	while IFS= read -r line; do
		((${#line} <= width)) || fail_test "narrow launchctl output overflowed at $width: ${#line} <$line>"
	done <<<"$width_output"
	[[ "$width_output" == *'kill: launchctl'* ]] || fail_test "narrow launchctl hint missing at width $width"
done
width_output="$(SLOPSTOP_WIDTH=100 run_scan)"
[[ "$width_output" == *'kill: launchctl remove xyz.pvrlabs.browser.44498.10298'* ]] || fail_test 'full launchctl label not shown at normal width'

printf '%s\n' \
  'developer  401  1  10:00:00 90.0 100000 /usr/bin/java -jar app.jar' \
  'developer  402  1  10:00:00 90.0 100000 /usr/local/bin/node server.js' \
  'developer  403  1  10:00:00 90.0 100000 /usr/local/bin/bun run index.ts' \
  'developer  404  1  10:00:00 90.0 100000 /usr/bin/python3 app.py' \
  'developer  406  1  10:00:00 90.0 100000 /usr/bin/kernel_task' \
  'developer  407  1  10:00:00 90.0 100000 /System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer' \
  'other      409  1  10:00:00 90.0 400000 /opt/opencode opencode --serve' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
for pid in 401 402 403 404 406 407 409; do
	[[ "$output" != *"pid $pid"* ]] || fail_test "generic/system/other-user pid $pid was incorrectly reviewed"
done
[[ "$output" == *$'Needs review\n(none)'* ]] || fail_test 'expected empty review for negative recognition fixtures'

printf '%s\n' \
  'developer  501  1  10:00:00  6.0  100000 /opt/opencode opencode --a' \
  'developer  502  1  10:00:00 40.0  100000 /opt/opencode opencode --b' \
  'developer  503  1  10:00:00 12.0  100000 /opt/opencode opencode --c' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
pos_hi="${output%%pid 502*}"; pos_mid="${output%%pid 503*}"; pos_lo="${output%%pid 501*}"
((${#pos_hi} < ${#pos_mid} && ${#pos_mid} < ${#pos_lo})) || fail_test 'review rows were not sorted by CPU descending'

printf '%s\n' \
  'developer  520  1  10:00:00  8.0  100000 /opt/opencode opencode --serve' \
  'developer  521  1  01:00  0.0  100000 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless --remote-debugging-port=9222' >"$FAKE_PS_OUTPUT"
output="$(run_scan --stop-safe)"
[[ "$output" == *'pid 520'* && "$output" == *'pid 521'* ]] || fail_test 'review rows missing in stop-safe scan'
[[ "$output" != *'Stopped'* ]] || fail_test 'review candidate was stopped'

printf '%s\n' \
  'PID STATUS   INFO' \
  '9001 IDLE     8.5' \
  '9002 IDLE     8.5' >"$FAKE_GRADLE_STATUS"
printf '%s\n' \
  'developer  9001  1  10:00:00  0.0  200000 /usr/bin/java org.gradle.launcher.daemon.bootstrap.GradleDaemon' \
  'developer  9002  1  10:00:00  0.0  200000 /usr/bin/java org.gradle.launcher.daemon.bootstrap.GradleDaemon' >"$FAKE_PS_OUTPUT"
: >"$FAKE_GRADLE_CALLS"; : >"$FAKE_CONTAINERS"
printf '%s\n' '{"status":"Stopped","runtime":"docker"}' >"$FAKE_COLIMA_STATUS"
output="$(run_scan)"
[[ "$output" == *'Gradle'* && "$output" == *'2 idle daemon'* ]] || fail_test 'idle Gradle was not safe'
[[ "$output" != *'pid 9001'* && "$output" != *'pid 9002'* ]] || fail_test 'idle Gradle PIDs still listed under review'
output="$(run_scan --stop-safe)"
[[ "$output" == *'Stopped Gradle daemons'* && -s "$FAKE_GRADLE_CALLS" ]] || fail_test 'gradle --stop was not used'
[[ "$(wc -l <"$FAKE_GRADLE_CALLS" | tr -d ' ')" == 1 ]] || fail_test 'gradle --stop did not run exactly once'

printf '%s\n' \
  'PID STATUS   INFO' \
  '9001 IDLE     8.5' \
  '9003 BUSY     8.5' >"$FAKE_GRADLE_STATUS"
printf '%s\n' \
  'developer  9001  1  10:00:00  0.0  200000 /usr/bin/java org.gradle.launcher.daemon.bootstrap.GradleDaemon' \
  'developer  9003  1  10:00:00  5.0  200000 /usr/bin/java org.gradle.launcher.daemon.bootstrap.GradleDaemon' >"$FAKE_PS_OUTPUT"
: >"$FAKE_GRADLE_CALLS"
output="$(run_scan)"
[[ "$output" != *'idle daemon'* ]] || fail_test 'busy Gradle was reported safe'
[[ "$output" == *'pid 9003'* ]] || fail_test 'busy Gradle daemon was not reviewed'

printf '%s\n' \
  'PID STATUS   INFO' \
  '9001 IDLE     8.5' \
  '9004 CANCELED 8.5' >"$FAKE_GRADLE_STATUS"
output="$(run_scan)"
[[ "$output" != *'idle daemon'* ]] || fail_test 'unknown Gradle status was reported safe'

printf '%s\n' \
  'WARNING: Deprecated Gradle features were used' \
  'PID STATUS   INFO' \
  '9001 IDLE     8.5' >"$FAKE_GRADLE_STATUS"
output="$(run_scan)"
[[ "$output" != *'idle daemon'* ]] || fail_test 'Gradle status with warning banner was reported safe'

printf '%s\n' 'No Gradle daemons are running.' >"$FAKE_GRADLE_STATUS"
printf '%s\n' \
  'PID Uptime Status' \
  '9100 00:10:00 Idle' \
  '9101 2h Idle' >"$FAKE_MVND_STATUS"
printf '%s\n' \
  'developer  9100  1  10:00:00  0.0  200000 /opt/homebrew/bin/mvnd' \
  'developer  9101  1  10:00:00  0.0  200000 /opt/homebrew/bin/mvnd' >"$FAKE_PS_OUTPUT"
: >"$FAKE_MVND_CALLS"
output="$(run_scan)"
[[ "$output" == *'mvnd'* && "$output" == *'2 idle daemon'* ]] || fail_test 'idle mvnd (Uptime Status format) was not safe'
[[ "$output" != *'pid 9100'* && "$output" != *'pid 9101'* ]] || fail_test 'idle mvnd PIDs still listed under review'
output="$(run_scan --stop-safe)"
[[ "$output" == *'Stopped mvnd daemons'* && -s "$FAKE_MVND_CALLS" ]] || fail_test 'mvnd --stop was not used'
[[ "$(wc -l <"$FAKE_MVND_CALLS" | tr -d ' ')" == 1 ]] || fail_test 'mvnd --stop did not run exactly once'

printf '%s\n' \
  'PID Uptime Status' \
  '9100 00:10:00 Idle' \
  '9102 00:01:00 Busy' >"$FAKE_MVND_STATUS"
printf '%s\n' \
  'developer  9100  1  10:00:00  0.0  200000 /opt/homebrew/bin/mvnd' \
  'developer  9102  1  10:00:00  5.0  200000 /opt/homebrew/bin/mvnd' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" != *'idle daemon'* ]] || fail_test 'busy mvnd (Uptime Status format) was reported safe'
printf '%s\n' 'No daemons are running.' >"$FAKE_MVND_STATUS"

printf '%s\n' \
  'developer  9200  1  10:00:00  8.0  100000 /Applications/Docker.app/Contents/MacOS/Docker Desktop' \
  'developer  9201  1  10:00:00  8.0  100000 /Applications/OrbStack.app/Contents/MacOS/OrbStack' \
  'developer  9204  1  10:00:00  8.0  100000 /Applications/Docker.app/Contents/MacOS/com.docker.backend' \
  'developer  9202  1  10:00:00 12.0  500000 qemu-system-x86_64 -machine q35' \
  'developer  9205  1  01:00  0.0  100000 /Applications/Docker.app/Contents/MacOS/Docker Desktop' >"$FAKE_PS_OUTPUT"
output="$(run_scan)"
[[ "$output" == *'Docker Desktop'* && "$output" == *'pid 9200'* ]] || fail_test 'old Docker Desktop was not reviewed'
[[ "$output" == *'OrbStack'* && "$output" == *'pid 9201'* ]] || fail_test 'old OrbStack was not reviewed'
[[ "$output" != *'pid 9204'* ]] || fail_test 'Docker backend was listed separately'
[[ "$output" != *'pid 9205'* ]] || fail_test 'young idle Docker Desktop was reviewed'
[[ "$output" != *'pid 9202'* && "$output" != *'qemu'* ]] || fail_test 'raw qemu was listed for review'

long_name_out="$(SLOPSTOP_WIDTH=40 run_scan)"
while IFS= read -r line; do
	((${#line} <= 40)) || fail_test "long name overflowed terminal width: ${#line} <$line>"
done <<<"$long_name_out"

printf '%s\n' \
  'developer  9301  1  10:00:00  8.0  100000 /opt/opencode-is-a-really-long-path-component-name-for-terminal-width-testing opencode --serve' >"$FAKE_PS_OUTPUT"
narrow_long="$(SLOPSTOP_WIDTH=20 run_scan)"
while IFS= read -r line; do
	((${#line} <= 20)) || fail_test "stacked long name overflowed width 20: ${#line} <$line>"
done <<<"$narrow_long"
[[ "$narrow_long" == *'...'* || "$narrow_long" == *'opencode-is-a-rea'* ]] || fail_test 'expected truncated long process name in narrow output'

make_stub colima 'case "$1 $2" in "status --json") cat "$FAKE_COLIMA_STATUS" ;; esac; case "$1" in stop) echo stopped >>"$FAKE_COLIMA_CALLS" ;; esac'
printf '%s\n' '{"status":"Running","runtime":"docker"}' >"$FAKE_COLIMA_STATUS"
printf '%s\n' 'developer  300  1  9-00:00:00  0.0  100000 /opt/opencode opencode --serve' >"$FAKE_PS_OUTPUT"
: >"$FAKE_CONTAINERS"; : >"$FAKE_COLIMA_CALLS"
output="$(printf '\n' | run_scan --stop)"
[[ "$output" == *'Colima'* && ! -s "$FAKE_COLIMA_CALLS" ]] || fail_test 'declined stop changed state'
output="$(printf 'y\n' | run_scan --stop)"
[[ "$output" == *'Stopped Colima'* && -s "$FAKE_COLIMA_CALLS" ]] || fail_test 'confirmed stop failed'
[[ "$(wc -l <"$FAKE_COLIMA_CALLS" | tr -d ' ')" == 1 ]] || fail_test 'confirmed stop did not run exactly once'
: >"$FAKE_COLIMA_CALLS"
output="$(run_scan --stop-safe)"
[[ "$output" == *'Stopped Colima'* && -s "$FAKE_COLIMA_CALLS" ]] || fail_test 'unprompted stop failed'
[[ "$(wc -l <"$FAKE_COLIMA_CALLS" | tr -d ' ')" == 1 ]] || fail_test 'unprompted stop did not run exactly once'

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
make_stub colima 'case "$1 $2" in "status --json") cat "$FAKE_COLIMA_STATUS" ;; esac; case "$1" in stop) echo stopped >>"$FAKE_COLIMA_CALLS" ;; esac'
printf '%s\n' '{"status":"Running","runtime":"docker"}' >"$FAKE_COLIMA_STATUS"
: >"$FAKE_CONTAINERS"

make_stub colima 'case "$1 $2" in "status --json") cat "$FAKE_COLIMA_STATUS" ;; esac; case "$1" in stop) exit 1 ;; esac'
set +e
output="$(run_scan --stop-safe 2>&1)"; exit_status=$?
set -e
[[ "$exit_status" -ne 0 && "$output" == *'Failed to stop Colima'* ]] || fail_test 'Colima stop failure was not reported'
make_stub colima 'case "$1 $2" in "status --json") cat "$FAKE_COLIMA_STATUS" ;; esac; case "$1" in stop) echo stopped >>"$FAKE_COLIMA_CALLS" ;; esac'

set +e
output="$(run_scan --bogus 2>&1)"; exit_status=$?
set -e
[[ "$exit_status" -ne 0 && "$output" == *'Usage:'* ]] || fail_test 'unknown argument accepted'
help_output="$(run_scan --help)"
[[ "$help_output" == *'Usage: slopstop'* ]] || fail_test 'help failed'
[[ "$help_output" == *'--stop'* && "$help_output" == *'--stop-safe'* ]] || fail_test 'help missing stop modes'
[[ "$help_output" == *'Review candidates are never stopped automatically.'* ]] || fail_test 'help missing review safety note'
scan_with_safe="$(run_scan)"
[[ "$scan_with_safe" == *'Colima'* ]] || fail_test 'expected a safe Colima row for footer check'
[[ "$scan_with_safe" != *'Run `slopstop --stop`'* ]] || fail_test 'scan still prints long stop how-to footer'

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
