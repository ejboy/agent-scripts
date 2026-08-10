#!/usr/bin/env bash

set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/npm-lite-test.XXXXXX")"
fake_bin="$test_root/bin"
project_dir="$test_root/project"
calls_file="$test_root/npm-calls.txt"

cleanup() {
	rm -rf -- "$test_root"
}

fail_test() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

trap cleanup EXIT
mkdir -p "$fake_bin" "$project_dir"
project_dir="$(cd -- "$project_dir" && pwd)"
ln -s "$root/tests/fixtures/fake-npm" "$fake_bin/npm"
: >"$calls_file"

run_lite() {
	(
		cd "$project_dir" || exit 1
		PATH="$fake_bin:$PATH" \
		FAKE_NPM_CALLS="$calls_file" \
		"$root/scripts/npm-lite" "$@"
	)
}

output="$(FAKE_NPM_MODE=success run_lite run verify)"
[[ "$output" == "PASS · 267 tests · "*" s" ]] || fail_test "verify success was not compact"
[[ ! -d "$project_dir/.agent-logs" ]] || fail_test "successful log directory was retained"

output="$(FAKE_NPM_MODE=no-count run_lite run test:unit)"
[[ "$output" == "PASS · "*" s" ]] || fail_test "count-free success summary missing"

output="$(FAKE_NPM_MODE=success run_lite install left-pad)"
[[ "$output" == $'setup output\n267 passing (4s)' ]] || fail_test "unsupported command did not pass through"

output="$(FAKE_NPM_MODE=success run_lite run verify -- --watch)"
[[ "$output" == $'setup output\n267 passing (4s)' ]] || fail_test "verify with extra arguments did not pass through"

control_value=$'argument\001\002\006\010\013\014\016\037value'
output="$(FAKE_NPM_MODE=success run_lite --loglevel "$control_value")"
[[ "$output" == $'setup output\n267 passing (4s)' ]] || fail_test "control-character argument did not pass through"

stderr_file="$test_root/passthrough-stderr"
set +e
output="$(FAKE_NPM_MODE=failure run_lite install left-pad 2>"$stderr_file")"
status=$?
set -e
[[ "$status" -eq 7 ]] || fail_test "pass-through failure exit status was not preserved"
[[ "$output" == "setup output" ]] || fail_test "pass-through stdout changed"
[[ "$(<"$stderr_file")" == "AssertionError: expected true but got false" ]] || fail_test "pass-through stderr changed"

set +e
output="$(FAKE_NPM_MODE=failure run_lite run verify 2>&1)"
status=$?
set -e
[[ "$status" -eq 7 ]] || fail_test "compact failure exit status was not preserved"
[[ "$output" == *"FAIL · exit 7"* ]] || fail_test "failure summary missing"
[[ "$output" == *"AssertionError: expected true but got false"* ]] || fail_test "failure detail missing"
log_file="$(sed -n 's/^Log: //p' <<<"$output")"
[[ -f "$log_file" ]] || fail_test "failure log was not retained"

old_log="$project_dir/.agent-logs/npm/npm-lite.old"
recent_log="$project_dir/.agent-logs/npm/npm-lite.recent"
unrelated_log="$project_dir/.agent-logs/npm/notes.old"
printf 'old\n' >"$old_log"
printf 'recent\n' >"$recent_log"
printf 'unrelated\n' >"$unrelated_log"
touch -t 200001010000 "$old_log" "$unrelated_log"

set +e
output="$(FAKE_NPM_MODE=long-failure run_lite run verify 2>&1)"
status=$?
set -e
[[ "$status" -eq 8 ]] || fail_test "bounded failure exit status was not preserved"
[[ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -le 85 ]] || fail_test "failure diagnostics were not bounded by lines"
[[ "$(printf '%s' "$output" | wc -c | tr -d ' ')" -le 8192 ]] || fail_test "failure diagnostics were not bounded by bytes"
[[ "$output" == *"failure diagnostics limited"* ]] || fail_test "failure truncation was not identified"
if grep -Fxq 'diagnostic line 1' <<<"$output"; then
	fail_test "failure diagnostics were not tailed"
fi
[[ ! -e "$old_log" ]] || fail_test "old npm-lite failure log was not pruned"
[[ -f "$recent_log" ]] || fail_test "recent npm-lite failure log was pruned"
[[ -f "$unrelated_log" ]] || fail_test "unrelated log was pruned"

rm -rf -- "$project_dir/.agent-logs"
: >"$project_dir/.agent-logs"
calls_size="$(wc -c <"$calls_file" | tr -d ' ')"
set +e
output="$(FAKE_NPM_MODE=success run_lite run verify 2>&1)"
status=$?
set -e
[[ "$status" -eq 2 ]] || fail_test "log-directory failure status was not 2"
[[ "$output" == *"Error: could not create npm log directory:"* ]] || fail_test "log-directory failure was unclear"
[[ "$(wc -c <"$calls_file" | tr -d ' ')" == "$calls_size" ]] || fail_test "npm ran after log-directory creation failed"
rm -f -- "$project_dir/.agent-logs"

printf '#!/usr/bin/env bash\nexit 1\n' >"$fake_bin/mktemp"
chmod +x "$fake_bin/mktemp"
set +e
output="$(FAKE_NPM_MODE=success run_lite run verify 2>&1)"
status=$?
set -e
rm -f -- "$fake_bin/mktemp"
[[ "$status" -eq 2 ]] || fail_test "log-creation failure status was not 2"
[[ "$output" == *"Error: could not create npm log in:"* ]] || fail_test "log-creation failure was unclear"
[[ "$(wc -c <"$calls_file" | tr -d ' ')" == "$calls_size" ]] || fail_test "npm ran after log creation failed"
real_mktemp="$(command -v mktemp)"
marker="$test_root/mktemp-marker"
cat >"$fake_bin/mktemp" <<'EOF'
#!/usr/bin/env bash
if [[ ! -e "${FAKE_MKTEMP_MARKER:?}" ]]; then
	: >"${FAKE_MKTEMP_MARKER}"
	exec "${REAL_MKTEMP:?}" "$@"
fi
exit 1
EOF
chmod +x "$fake_bin/mktemp"
export FAKE_MKTEMP_MARKER="$marker" REAL_MKTEMP="$real_mktemp"
set +e
output="$(FAKE_NPM_MODE=success run_lite run verify 2>&1)"
status=$?
set -e
rm -f -- "$fake_bin/mktemp"
unset FAKE_MKTEMP_MARKER REAL_MKTEMP
[[ "$status" -eq 2 ]] || fail_test "summary-creation failure status was not 2"
[[ "$output" == *"Error: could not create npm summary file in:"* ]] || fail_test "summary-creation failure was unclear"
[[ "$(wc -c <"$calls_file" | tr -d ' ')" == "$calls_size" ]] || fail_test "npm ran after summary creation failed"

signal_output="$test_root/signal-output"
signal_pid_file="$test_root/signal-pid"
signal_child_pid_file="$test_root/signal-child-pid"
(
	cd "$project_dir" || exit 1
	PATH="$fake_bin:$PATH" \
	FAKE_NPM_MODE=signal-wait \
	FAKE_NPM_CALLS="$calls_file" \
	FAKE_NPM_PID_FILE="$signal_pid_file" \
	FAKE_NPM_CHILD_PID_FILE="$signal_child_pid_file" \
	exec "$root/scripts/npm-lite" run verify
) >"$signal_output" 2>&1 &
wrapper_pid=$!
for _ in {1..40}; do
	if [[ -f "$signal_pid_file" && -f "$signal_child_pid_file" ]]; then
		break
	fi
	sleep 0.05
done
[[ -f "$signal_pid_file" && -f "$signal_child_pid_file" ]] || fail_test "signal test npm did not start"
signal_npm_pid="$(<"$signal_pid_file")"
signal_child_pid="$(<"$signal_child_pid_file")"
check_descendants=false
if pgrep -P "$signal_npm_pid" >/dev/null 2>&1; then
	check_descendants=true
fi
kill -TERM "$wrapper_pid"
set +e
wait "$wrapper_pid"
status=$?
set -e
[[ "$status" -eq 143 ]] || fail_test "TERM status was $status"
[[ "$(<"$signal_output")" != *"PASS"* ]] || fail_test "interrupted run reported success"
if [[ "$check_descendants" == true ]]; then
	for _ in {1..40}; do
		if ! kill -0 "$signal_npm_pid" 2>/dev/null && ! kill -0 "$signal_child_pid" 2>/dev/null; then
			break
		fi
		sleep 0.05
	done
	if kill -0 "$signal_npm_pid" 2>/dev/null || kill -0 "$signal_child_pid" 2>/dev/null; then
		kill -KILL "$signal_npm_pid" "$signal_child_pid" 2>/dev/null || true
		fail_test "TERM did not stop npm and its descendant"
	fi
else
	kill -KILL "$signal_child_pid" 2>/dev/null || true
fi
find "$project_dir/.agent-logs/npm" -type f -name 'npm-lite.*' -print -quit | grep -q . ||
	fail_test "interrupted run did not retain its raw log"

python3 - "$calls_file" "$control_value" <<'PY' || fail_test "npm argument boundaries were not preserved"
import sys

fields = open(sys.argv[1], "rb").read().split(b"\0")
assert fields.pop() == b""
calls = []
while fields:
	count = int(fields.pop(0))
	calls.append([fields.pop(0).decode() for _ in range(count)])
assert calls == [
	["run", "verify"],
	["run", "test:unit"],
	["install", "left-pad"],
	["run", "verify", "--", "--watch"],
	["--loglevel", sys.argv[2]],
	["install", "left-pad"],
	["run", "verify"],
	["run", "verify"],
	["run", "verify"],
]
PY

printf '%s\n' 'npm-lite tests passed'
