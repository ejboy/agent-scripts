#!/usr/bin/env bash
set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/mvn-lite-test.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

runner="$root/scripts/mvn-lite"
project="$test_root/project with spaces"
bin_dir="$test_root/bin"
no_mvn_bin="$test_root/no-mvn-bin"
override_log_dir="$test_root/override logs"
mkdir -p "$project" "$bin_dir" "$no_mvn_bin"
project="$(cd -- "$project" && pwd)"
cp "$root/tests/fixtures/fake-mvn" "$bin_dir/mvn"
chmod +x "$bin_dir/mvn"

export FAKE_MVN="$bin_dir/mvn"
export FAKE_ARGS_FILE="$test_root/args"
export FAKE_INVOKED_FILE="$test_root/invoked"
export FAKE_PROJECT_DIR="$project"

fail_test() {
	echo "FAIL: $1" >&2
	exit 1
}

assert_file_contains() {
	grep -Fq -- "$2" "$1" || fail_test "expected $1 to contain: $2"
}

assert_args() {
	local expected_file="$test_root/expected-args"
	printf '%s\n' "$@" >"$expected_file"
	diff -u "$expected_file" "$FAKE_ARGS_FILE" || fail_test "Maven arguments differed"
}

run_from_project() {
	(
		cd "$project"
		PATH="$bin_dir:$PATH" "$runner" "$@"
	)
}

failure_log_from_output() {
	sed -n 's/^  //p' <<<"$1" | grep '/maven-.*\.log$' | tail -n 1
}

export FAKE_MODE=success
export FAKE_NAME=mvn
cat >"$project/mvnw" <<'EOF'
#!/usr/bin/env bash
FAKE_NAME=wrapper exec "$FAKE_MVN" "$@"
EOF
chmod +x "$project/mvnw"

output="$(run_from_project test)"
assert_file_contains "$FAKE_INVOKED_FILE" "wrapper"
assert_args -B -ntp -Dstyle.color=never test
[[ "$output" == "PASS · 1.234 s" ]] || fail_test "unexpected compact success output: $output"
if find "$project/.agent-logs" -type f -name '*.log' -print -quit | grep -q .; then
	fail_test "successful compact log was not removed"
fi

rm -f "$project/mvnw"
output="$(run_from_project)"
[[ "$output" == "PASS · 1.234 s" ]] || fail_test "no-argument invocation failed: $output"
assert_args -B -ntp -Dstyle.color=never

output="$(run_from_project '-Dname=value with spaces' clean verify)"
assert_file_contains "$FAKE_INVOKED_FILE" "mvn"
assert_args -B -ntp -Dstyle.color=never '-Dname=value with spaces' clean verify

output="$(run_from_project --keep-log test)"
log_file="$(sed -n 's/^Full Maven log: //p' <<<"$output")"
[[ -f "$log_file" ]] || fail_test "kept log does not exist"
[[ "$log_file" == "$project/.agent-logs/maven/"* ]] || fail_test "default log is not under caller directory"
rm -f "$log_file"

output="$(MVN_LITE_LOG_DIR="$override_log_dir" run_from_project --keep-log test)"
log_file="$(sed -n 's/^Full Maven log: //p' <<<"$output")"
[[ -f "$log_file" && "$log_file" == "$override_log_dir/"* ]] || fail_test "log override was not used"
rm -f "$log_file"

output="$(run_from_project -B --batch-mode -ntp --no-transfer-progress -Dstyle.color=auto test)"
assert_args -B --batch-mode -ntp --no-transfer-progress -Dstyle.color=auto test

output="$(run_from_project test --full)"
[[ "$output" == PASS* ]] || fail_test "wrapper option after Maven argument was intercepted"
assert_args -B -ntp -Dstyle.color=never test --full

output="$(run_from_project --full '-Dname=value with spaces' verify)"
[[ "$output" == *'[INFO] BUILD SUCCESS'* && "$output" != PASS* ]] || fail_test "--full did not stream Maven output"
assert_args '-Dname=value with spaces' verify

output="$(run_from_project --raw verify)"
[[ "$output" == *'[INFO] BUILD SUCCESS'* && "$output" != PASS* ]] || fail_test "--raw did not stream Maven output"
assert_args verify

for informational_flag in -h --help -v --version -V --show-version; do
	case "$informational_flag" in
		-h|--help)
			export FAKE_MODE=help
			expected_text='usage: mvn'
			;;
		*)
			export FAKE_MODE=version
			expected_text='Apache Maven 3.9.9'
			;;
	esac
	set +e
	output="$(run_from_project "$informational_flag")"
	status=$?
	set -e
	[[ "$status" -eq 0 ]] || fail_test "$informational_flag status was $status"
	[[ "$output" == *"$expected_text"* && "$output" != PASS* ]] || fail_test "$informational_flag was not passed through"
	assert_args "$informational_flag"
done

export FAKE_MODE=help
output="$(run_from_project -- --help)"
[[ "$output" == *'usage: mvn'* && "$output" != PASS* ]] || fail_test "-- --help was not passed through"
assert_args --help

export FAKE_MODE=compiler
set +e
output="$(run_from_project test 2>&1)"
status=$?
set -e
[[ "$status" -eq 17 ]] || fail_test "compiler status was $status"
[[ "$output" == *'Compiler: src/main/java/App.java:4:9 — cannot find symbol'* ]] || fail_test "compiler summary missing"
[[ "$output" == *'Compiler detail: symbol:   variable missing'* ]] || fail_test "compiler detail missing"
[[ "$output" == *'Goal: org.apache.maven.plugins:maven-compiler-plugin:compile'* ]] || fail_test "compiler goal missing"
log_file="$(failure_log_from_output "$output")"
[[ -f "$log_file" ]] || fail_test "failed compiler log missing"

export FAKE_MODE=surefire-failure
set +e
output="$(run_from_project -Dpassword=secret test 2>&1)"
status=$?
set -e
[[ "$status" -eq 1 ]] || fail_test "Surefire status was $status"
[[ "$output" == *'Test: com.example.AppTest.shouldRejectInvalidInput'* ]] || fail_test "Surefire test summary missing"
[[ "$output" == *'Exception: java.lang.AssertionError: expected 400'* ]] || fail_test "Surefire exception missing"
[[ "$output" == *'surefire-reports'* ]] || fail_test "Surefire report hint missing"
[[ "$output" != *secret* ]] || fail_test "compact failure output exposed command secret"
[[ "$output" != *'Maven command:'* ]] || fail_test "compact failure output printed Maven command"
[[ "$output" == *'Full Maven log:'* ]] || fail_test "failure log path missing"
[[ "$output" == *'Re-run with --full for complete live output.'* ]] || fail_test "full-output guidance missing"
log_file="$(failure_log_from_output "$output")"
[[ -f "$log_file" ]] || fail_test "Surefire failure log missing"

export FAKE_MODE=failsafe-failure
set +e
output="$(run_from_project verify 2>&1)"
status=$?
set -e
[[ "$status" -eq 1 ]] || fail_test "Failsafe status was $status"
[[ "$output" == *'Test: com.example.AppIT.shouldStartService'* ]] || fail_test "Failsafe test summary missing"
[[ "$output" == *'Exception: java.lang.IllegalStateException: service unavailable'* ]] || fail_test "Failsafe exception missing"
[[ "$output" == *'failsafe-reports'* ]] || fail_test "Failsafe report hint missing"

export FAKE_MODE=dependency-resolution
set +e
output="$(run_from_project package 2>&1)"
status=$?
set -e
[[ "$status" -eq 1 ]] || fail_test "dependency status was $status"
[[ "$output" == *'Dependency: Failed to execute goal on project app: Could not resolve dependencies for project'* ]] || fail_test "dependency resolution summary missing"
[[ "$output" == *'Dependency: Could not find artifact com.example:missing-lib'* ]] || fail_test "missing artifact summary missing"
[[ "$output" != *'Goal: on project app: Could not resolve dependencies'* ]] ||
	fail_test "dependency failure was duplicated as a plugin goal"

export FAKE_MODE=goal
set +e
output="$(run_from_project test 2>&1)"
status=$?
set -e
[[ "$status" -eq 9 ]] || fail_test "goal status was $status"
[[ "$output" == *'Goal: org.apache.maven.plugins:maven-enforcer-plugin:enforce'* ]] || fail_test "plugin goal missing"
[[ "$output" != *'surefire-reports'* ]] || fail_test "non-test failure showed test hints"

export FAKE_MODE=maven-command-error
set +e
output="$(run_from_project teest 2>&1)"
status=$?
set -e
[[ "$status" -eq 2 ]] || fail_test "Maven command error status was $status"
[[ "$output" == *'Maven: Unknown lifecycle phase'* ]] || fail_test "Maven command error summary missing"

export FAKE_MODE=unknown
set +e
output="$(run_from_project test 2>&1)"
status=$?
set -e
[[ "$status" -eq 7 ]] || fail_test "unknown status was $status"
[[ "$output" == *'Maven log tail:'* ]] || fail_test "unknown failure did not use log tail"
tail_lines="$(awk '
	/^Maven log tail:$/ { capture = 1; next }
	capture && /^$/ { exit }
	capture { count++ }
	END { print count + 0 }
' <<<"$output")"
((tail_lines <= 80)) || fail_test "unknown fallback printed $tail_lines log lines"
[[ "$tail_lines" -eq 80 ]] || fail_test "unknown fallback expected 80 lines, got $tail_lines"

cat >"$project/mvnw" <<'EOF'
#!/usr/bin/env bash
exec "$FAKE_MVN" "$@"
EOF
chmod +x "$project/mvnw"
signal_pid_file="$test_root/signal-pid"
signal_exit_file="$test_root/signal-exit"
signal_launcher="$test_root/signal-launcher"
rm -f "$signal_pid_file" "$signal_exit_file"
cat >"$signal_launcher" <<'EOF'
#!/usr/bin/env bash
set -u
runner="$1"
pid_file="$2"
(
	for _ in {1..50}; do
		[[ -f "$pid_file" ]] && break
		sleep 0.05
	done
	kill -TERM "$$"
) &
exec "$runner" test
EOF
chmod +x "$signal_launcher"
set +e
output="$(
	cd "$project" &&
	FAKE_MODE=wait-for-signal \
	FAKE_SIGNAL_PID_FILE="$signal_pid_file" \
	FAKE_SIGNAL_EXIT_FILE="$signal_exit_file" \
	PATH="$bin_dir:$PATH" \
	"$(command -v bash)" "$signal_launcher" "$runner" "$signal_pid_file" 2>&1
)"
status=$?
set -e
[[ "$status" -eq 143 ]] || fail_test "SIGTERM status was $status"
[[ -f "$signal_pid_file" ]] || fail_test "signal fixture did not start"
[[ -f "$signal_exit_file" ]] || fail_test "Maven child did not complete signal cleanup"
rm -f "$project/mvnw"

mv "$bin_dir/mvn" "$bin_dir/mvn.saved"
ln -s "$(command -v dirname)" "$no_mvn_bin/dirname"
ln -s "$(command -v date)" "$no_mvn_bin/date"
bash_bin="$(command -v bash)"
set +e
output="$(cd "$project" && PATH="$no_mvn_bin" "$bash_bin" "$runner" test 2>&1)"
status=$?
set -e
[[ "$status" -eq 2 ]] || fail_test "missing Maven status was $status"
[[ "$output" == *'neither an executable ./mvnw nor mvn on PATH was found'* ]] || fail_test "missing Maven error unclear"

echo "mvn-lite tests passed"
