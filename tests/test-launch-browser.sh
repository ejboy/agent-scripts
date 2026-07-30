#!/usr/bin/env bash
set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/launch-browser-test.XXXXXX")"
integration_pid_file=""
cleanup_test() {
	if [[ -n "$integration_pid_file" && -f "$integration_pid_file" ]]; then
		kill -TERM "$(<"$integration_pid_file")" 2>/dev/null || true
	fi
	rm -rf "$test_root"
}
trap cleanup_test EXIT

test_home="$test_root/home"
bin_dir="$test_root/bin"
state_dir="$test_home/.browser-testing-profile"
state_file="$state_dir/launch-state"
launchctl_args="$test_root/launchctl-args"
mkdir -p "$state_dir" "$bin_dir"

cat >"$bin_dir/uname" <<'EOF'
#!/usr/bin/env bash
echo Darwin
EOF
cat >"$bin_dir/launchctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$FAKE_LAUNCHCTL_ARGS"
[[ "${FAKE_LAUNCHCTL_FAIL:-false}" != true ]]
EOF
chmod +x "$bin_dir/uname" "$bin_dir/launchctl"

fail_test() {
	echo "FAIL: $1" >&2
	exit 1
}

run_launcher() {
	HOME="$test_home" \
	PATH="$bin_dir:$PATH" \
	FAKE_LAUNCHCTL_ARGS="$launchctl_args" \
	"$root/scripts/launch-browser" "$@"
}

expected_version="$(<"$root/VERSION")"
output="$(run_launcher --help)"
[[ "$output" == "launch-browser $expected_version"$'\n\nUsage:'* ]] ||
	fail_test "help version heading missing"

cat >"$state_file" <<'EOF'
service=xyz.pvrlabs.browser.123.456
pid=9876
EOF
set +e
output="$(FAKE_LAUNCHCTL_FAIL=true run_launcher --stop 2>&1)"
status=$?
set -e
[[ "$status" -eq 1 ]] || fail_test "failed launchctl status was $status"
[[ -f "$state_file" ]] || fail_test "state was removed after launchctl failure"

output="$(run_launcher --stop)"
[[ "$output" == *'Browser stopped'* ]] || fail_test "stop confirmation missing"
[[ "$output" == *'PID: 9876'* ]] || fail_test "stopped PID missing"
[[ "$output" == *'Service: xyz.pvrlabs.browser.123.456'* ]] || fail_test "stopped service missing"
[[ ! -f "$state_file" ]] || fail_test "state was not removed after stop"
printf '%s\n' remove xyz.pvrlabs.browser.123.456 >"$test_root/expected-args"
diff -u "$test_root/expected-args" "$launchctl_args" ||
	fail_test "launchctl received unexpected arguments"

cat >"$state_file" <<'EOF'
service=com.example.browser.123
pid=9876
EOF
rm -f "$launchctl_args"
set +e
output="$(run_launcher --stop 2>&1)"
status=$?
set -e
[[ "$status" -eq 1 ]] || fail_test "invalid state status was $status"
[[ "$output" == *'invalid browser service'* ]] || fail_test "invalid service error missing"
[[ -f "$state_file" ]] || fail_test "invalid state was unexpectedly removed"
[[ ! -e "$launchctl_args" ]] || fail_test "launchctl was called for invalid state"

set +e
output="$(run_launcher --stop --visible 2>&1)"
status=$?
set -e
[[ "$status" -eq 1 ]] || fail_test "combined stop status was $status"
[[ "$output" == *'--stop cannot be combined'* ]] || fail_test "combined stop error missing"

integration_home="$test_root/integration-home"
integration_bin="$test_root/integration-bin"
integration_state_dir="$integration_home/.browser-testing-profile"
integration_state_file="$integration_state_dir/launch-state"
integration_pid_file="$test_root/integration-chrome-pid"
integration_ready_file="$test_root/integration-ready"
integration_wrapper_pid_file="$test_root/integration-wrapper-pid"
integration_calls="$test_root/integration-launchctl-calls"
fake_chrome_app="$test_root/Google Chrome.app"
fake_chrome_bin="$fake_chrome_app/Contents/MacOS/Google Chrome"
mkdir -p "$integration_state_dir" "$integration_bin" "$(dirname "$fake_chrome_bin")"

cat >"$integration_bin/uname" <<'EOF'
#!/usr/bin/env bash
echo Darwin
EOF
cat >"$integration_bin/curl" <<'EOF'
#!/usr/bin/env bash
if [[ -f "$FAKE_READY_FILE" && -f "$FAKE_CHROME_PID_FILE" ]] &&
	kill -0 "$(<"$FAKE_CHROME_PID_FILE")" 2>/dev/null; then
	printf '%s\n' '{"Browser":"Fake Chrome"}'
	exit 0
fi
exit 22
EOF
cat >"$integration_bin/lsof" <<'EOF'
#!/usr/bin/env bash
if [[ -f "$FAKE_READY_FILE" && -f "$FAKE_CHROME_PID_FILE" ]] &&
	kill -0 "$(<"$FAKE_CHROME_PID_FILE")" 2>/dev/null; then
	for arg in "$@"; do
		[[ "$arg" == "-t" ]] && printf '%s\n' "$(<"$FAKE_CHROME_PID_FILE")"
	done
	exit 0
fi
exit 1
EOF
cat >"$integration_bin/launchctl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$FAKE_LAUNCHCTL_CALLS"
case "$1" in
	submit)
		[[ "${FAKE_SUBMIT_FAIL:-false}" != true ]] || exit 1
		shift
		while (($# > 0)); do
			if [[ "$1" == "--" ]]; then
				shift
				break
			fi
			shift
		done
		"$@" &
		printf '%s\n' "$!" >"$FAKE_WRAPPER_PID_FILE"
		;;
	remove)
		# Intentionally leave Chrome running. launch-browser --stop must
		# identify and terminate the recorded CDP listener itself.
		;;
esac
EOF
cat >"$fake_chrome_bin" <<'EOF'
#!/usr/bin/env bash
cleanup_fake_chrome() {
	rm -f "$FAKE_READY_FILE"
	exit 0
}
trap cleanup_fake_chrome INT TERM
printf '%s\n' "$$" >"$FAKE_CHROME_PID_FILE"
printf '%s\n' ready >"$FAKE_READY_FILE"
while :; do
	sleep 1
done
EOF
chmod +x "$integration_bin/uname" "$integration_bin/curl" \
	"$integration_bin/lsof" "$integration_bin/launchctl" "$fake_chrome_bin"

run_integration_launcher() {
	HOME="$integration_home" \
	PATH="$integration_bin:$PATH" \
	LAUNCH_BROWSER_CHROME_APP="$fake_chrome_app" \
	FAKE_READY_FILE="$integration_ready_file" \
	FAKE_CHROME_PID_FILE="$integration_pid_file" \
	FAKE_WRAPPER_PID_FILE="$integration_wrapper_pid_file" \
	FAKE_LAUNCHCTL_CALLS="$integration_calls" \
	"$root/scripts/launch-browser" "$@"
}

rm -f "$integration_calls" "$integration_pid_file" "$integration_ready_file"
output="$(run_integration_launcher)"
[[ "$output" == *'Browser ready'* ]] || fail_test "detached browser did not become ready"
[[ -f "$integration_state_file" ]] || fail_test "detached launch state was not created"
recorded_pid="$(sed -n 's/^pid=//p' "$integration_state_file")"
[[ "$recorded_pid" == "$(<"$integration_pid_file")" ]] ||
	fail_test "readiness did not rewrite the recorded Chrome PID"
grep -Fq 'submit ' "$integration_calls" || fail_test "launchctl submit was not called"
integration_log="$(sed -n 's/^Log: //p' <<<"$output")"
[[ -f "$integration_log" ]] || fail_test "detached launch log was not created"

output="$(run_integration_launcher --stop)"
[[ "$output" == *'Browser stopped'* ]] || fail_test "integrated stop did not confirm shutdown"
[[ ! -f "$integration_state_file" ]] || fail_test "integrated stop left state behind"
for _ in {1..50}; do
	[[ ! -f "$integration_log" ]] && break
	sleep 0.05
done
[[ ! -f "$integration_log" ]] || fail_test "normal stop left the detached Chrome log"

rm -f "$integration_calls" "$integration_pid_file" "$integration_ready_file"
set +e
output="$(FAKE_SUBMIT_FAIL=true run_integration_launcher 2>&1)"
status=$?
set -e
[[ "$status" -eq 1 ]] || fail_test "submit failure status was $status"
[[ "$output" == *'launchctl failed to start Google Chrome'* ]] ||
	fail_test "submit failure diagnostic missing"
[[ ! -f "$integration_state_file" ]] || fail_test "submit failure left launch state"
[[ ! -f "$integration_pid_file" ]] || fail_test "submit failure started Chrome"

rm -f "$integration_calls" "$integration_pid_file" "$integration_ready_file"
output="$(run_integration_launcher)"
integration_log="$(sed -n 's/^Log: //p' <<<"$output")"
chrome_pid="$(<"$integration_pid_file")"
kill -TERM "$chrome_pid"
for _ in {1..50}; do
	if [[ ! -f "$integration_state_file" && ! -f "$integration_log" ]]; then
		break
	fi
	sleep 0.05
done
[[ ! -f "$integration_state_file" ]] ||
	fail_test "detached runner did not remove state after Chrome exit"
[[ ! -f "$integration_log" ]] ||
	fail_test "detached runner did not remove a successful Chrome log"

echo "launch-browser tests passed"
