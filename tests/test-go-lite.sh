#!/usr/bin/env bash

set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/go-lite-test.XXXXXX")"
fake_bin="$test_root/bin"
project="$test_root/project with spaces"
args_file="$test_root/go-args"
env_file="$test_root/go-env"
mkdir -p "$fake_bin" "$project"
cp "$root/tests/fixtures/fake-go" "$fake_bin/go"
chmod +x "$fake_bin/go"
trap 'rm -rf -- "$test_root"' EXIT

fail_test() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

run_lite() {
	(
		cd "$project" || exit 1
		PATH="$fake_bin:$PATH" \
		FAKE_GO_ARGS_FILE="$args_file" \
		FAKE_GO_ENV_FILE="$env_file" \
		FAKE_GO_MODE="${FAKE_GO_MODE:-success}" \
		"$root/scripts/go-lite" "$@"
	)
}

args_as_lines() {
	python3 - "$args_file" <<'PY'
import sys

fields = open(sys.argv[1], "rb").read().split(b"\0")
count = int(fields.pop(0))
assert fields.pop() == b""
assert len(fields) == count
for field in fields:
    print(field.decode())
PY
}

env_value() {
	sed -n "s/^$1=//p" "$env_file"
}

: >"$args_file"
output="$(run_lite test ./internal/storage)"
[[ "$output" == PASS\ \·\ *\ s ]] || fail_test "success was not compact: $output"
[[ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -eq 1 ]] || fail_test "success output was not one line"
[[ "$(args_as_lines)" == $'test\n./internal/storage' ]] || fail_test "test arguments changed"
[[ "$(env_value GOCACHE)" == /tmp/go-lite-cache ]] || fail_test "default cache was not selected"
[[ -d /tmp/go-lite-cache ]] || fail_test "default cache directory was not created"
[[ ! -d "$project/.agent-logs" ]] || fail_test "successful log was retained"

output="$(printf '%s\n' 'stdin input' | FAKE_GO_MODE=read-stdin run_lite test ./... 2>&1)"
[[ "$output" == PASS\ \·\ *\ s ]] || fail_test "compact mode did not preserve stdin"

cache_dir="$test_root/cache with spaces"
output="$(GO_LITE_CACHE_DIR="$cache_dir" FAKE_UNRELATED=unchanged run_lite test -count=1 ./... 2>/dev/null)"
[[ "$output" == PASS\ \·\ *\ s ]] || fail_test "count-first test invocation was not compact"
[[ "$(env_value GOCACHE)" == "$cache_dir" ]] || fail_test "GO_LITE_CACHE_DIR was not used"
[[ -d "$cache_dir" ]] || fail_test "selected cache directory was not created"
[[ "$(env_value GO_LITE_CACHE_DIR)" == "$cache_dir" ]] || fail_test "wrapper cache variable changed"
[[ "$(env_value FAKE_UNRELATED)" == unchanged ]] || fail_test "unrelated environment changed"

existing_cache="$test_root/existing-cache"
mkdir -p "$existing_cache"
output="$(GOCACHE="$existing_cache" GO_LITE_CACHE_DIR="$test_root/ignored-cache" run_lite test ./... 2>/dev/null)"
[[ "$output" == PASS\ \·\ *\ s ]] || fail_test "existing-cache run was not compact"
[[ "$(env_value GOCACHE)" == "$existing_cache" ]] || fail_test "existing GOCACHE was not preserved"
[[ ! -d "$test_root/ignored-cache" ]] || fail_test "GO_LITE_CACHE_DIR overrode GOCACHE"

set +e
output="$(FAKE_GO_MODE=small-failure run_lite test ./internal/storage 2>&1)"
status=$?
set -e
[[ "$status" -eq 23 ]] || fail_test "small failure status was $status"
[[ "$output" == *'--- FAIL: TestFoo'* && "$output" == *'fake_test.go:12:'* ]] || fail_test "small failure output was not surfaced"
[[ "$output" == *'Full Go log:'* && "$output" == *'Re-run with --full for complete live output.'* ]] ||
	fail_test "small failure guidance was missing"
log_file="$(sed -n 's/^  //p' <<<"$output" | grep '/go-.*\.log\.' | tail -n 1)"
[[ -f "$log_file" ]] || fail_test "small failure log was not retained"
[[ "$(<"$log_file")" == *'--- FAIL: TestFoo'* ]] || fail_test "raw failure log was incomplete"

set +e
output="$(FAKE_GO_MODE=large-failure run_lite test ./... 2>&1)"
status=$?
set -e
[[ "$status" -eq 29 ]] || fail_test "large failure status was $status"
[[ "$output" == *'failure diagnostics selected'* ]] || fail_test "large failure was not bounded"
[[ "$output" == *'fake.go:123:45: undefined: MissingThing'* ]] || fail_test "compiler context was omitted"
[[ "$output" == *'FAIL    example.test/internal/storage'* ]] || fail_test "final summary was omitted"
[[ "$(printf '%s' "$output" | wc -c | tr -d ' ')" -lt 8192 ]] || fail_test "large failure output was not bounded"
large_log="$(sed -n 's/^  //p' <<<"$output" | grep '/go-.*\.log\.' | tail -n 1)"
[[ "$(wc -l <"$large_log" | tr -d ' ')" -gt 120 ]] || fail_test "complete large log was not retained"

set +e
output="$(FAKE_GO_MODE=byte-failure run_lite test ./... 2>&1)"
status=$?
set -e
[[ "$status" -eq 37 ]] || fail_test "byte-bounded failure status was $status"
[[ "$output" == *'diagnostics omitted by byte limit'* ]] || fail_test "byte-bounded failure was not truncated"
[[ "$output" == *'Full Go log:'* && "$output" == *'Re-run with --full for complete live output.'* ]] ||
	fail_test "byte-bounded failure guidance was missing"
[[ "$(printf '%s' "$output" | wc -c | tr -d ' ')" -lt 8192 ]] || fail_test "byte-bounded failure output was not bounded"

kept_before="$(find "$project/.agent-logs/go" -type f -name 'go-*.log.*' | wc -l | tr -d ' ')"
output="$(FAKE_GO_MODE=success run_lite --keep-log test ./...)"
[[ "$output" == PASS\ \·\ *\ s ]] || fail_test "keep-log success was not compact"
kept_count="$(find "$project/.agent-logs/go" -type f -name 'go-*.log.*' | wc -l | tr -d ' ')"
[[ "$kept_count" -eq $((kept_before + 1)) ]] || fail_test "successful keep-log file was not retained"
rm -f -- "$project/.agent-logs/go"/go-*.log.*

output="$(FAKE_GO_MODE=full run_lite --full test ./internal/storage 2>&1)"
[[ "$output" == $'live go stdout\nlive go stderr' ]] || fail_test "--full did not stream ordinary output"
output="$(FAKE_GO_MODE=full run_lite --raw test ./internal/storage 2>&1)"
[[ "$output" == $'live go stdout\nlive go stderr' ]] || fail_test "--raw did not stream ordinary output"

non_test_log_count="$(find "$project/.agent-logs/go" -type f -name 'go-*.log.*' 2>/dev/null | wc -l | tr -d ' ')"
: >"$args_file"
output="$(FAKE_GO_MODE=passthrough run_lite mod tidy)"
[[ "$output" == 'go passthrough output' ]] || fail_test "non-test command did not pass through"
[[ "$(args_as_lines)" == $'mod\ntidy' ]] || fail_test "non-test arguments changed"
: >"$args_file"
output="$(FAKE_GO_MODE=passthrough run_lite env 'argument with spaces' --flag)"
[[ "$(args_as_lines)" == $'env\nargument with spaces\n--flag' ]] || fail_test "argument boundaries changed"
[[ "$(find "$project/.agent-logs/go" -type f -name 'go-*.log.*' 2>/dev/null | wc -l | tr -d ' ')" -eq "$non_test_log_count" ]] ||
	fail_test "non-test command created logs"

old_log="$project/.agent-logs/go/go-20000101-000000-1.log.old"
recent_log="$project/.agent-logs/go/go-recent.log.kept"
unrelated_log="$project/.agent-logs/go/notes.old"
mkdir -p "$project/.agent-logs/go"
printf 'old\n' >"$old_log"
printf 'recent\n' >"$recent_log"
printf 'unrelated\n' >"$unrelated_log"
touch -t 200001010000 "$old_log" "$unrelated_log"
output="$(run_lite test ./...)"
[[ ! -e "$old_log" ]] || fail_test "old Go log was not pruned"
[[ -f "$recent_log" ]] || fail_test "recent Go log was pruned"
[[ -f "$unrelated_log" ]] || fail_test "unrelated Go file was pruned"

: >"$args_file"
help_output="$(run_lite --help-go-lite)"
[[ "$help_output" == *'go-lite '* && "$help_output" == *'--full, --raw'* && "$help_output" == *'--help-go-lite'* ]] ||
	fail_test "Go wrapper help was incomplete"
[[ ! -s "$args_file" ]] || fail_test "wrapper help invoked Go"

printf '%s\n' 'go-lite tests passed'
