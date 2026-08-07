#!/usr/bin/env bash

set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/npm-lite-test.XXXXXX")"
fake_bin="$test_root/bin"
project_dir="$test_root/project"
stats_file="$test_root/npm-stats.jsonl"
calls_file="$test_root/npm-calls.txt"

cleanup() {
	rm -rf "$test_root"
}

fail_test() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

trap cleanup EXIT
mkdir -p "$fake_bin" "$project_dir"
project_dir="$(cd "$project_dir" && pwd)"
ln -s "$root/fixtures/fake-npm" "$fake_bin/npm"
: > "$calls_file"

run_lite() {
	(
		cd "$project_dir" || exit 1
		PATH="$fake_bin:$PATH" \
		FAKE_NPM_CALLS="$calls_file" \
		NPM_LITE_STATS_FILE="$stats_file" \
		"$root/npm-lite" "$@"
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

set +e
output="$(FAKE_NPM_MODE=failure run_lite run verify 2>&1)"
status=$?
set -e
[[ "$status" == 7 ]] || fail_test "failure exit status was not preserved"
[[ "$output" == *"FAIL · exit 7"* ]] || fail_test "failure summary missing"
[[ "$output" == *"AssertionError: expected true but got false"* ]] || fail_test "failure detail missing"
[[ "$output" == *"Log: $project_dir/.agent-logs/npm/"* ]] || fail_test "failure log path missing"
find "$project_dir/.agent-logs/npm" -type f -name 'npm-lite.*' | grep -q . || fail_test "failure log was not retained"

[[ "$(wc -l < "$stats_file" | tr -d ' ')" == 6 ]] || fail_test "unexpected stats entry count"
grep -Fq '"mode":"compact","workflow":"verify","exit":0' "$stats_file" || fail_test "verify stats missing"
grep -Fq '"mode":"compact","workflow":"test:unit","exit":0' "$stats_file" || fail_test "unit stats missing"
grep -Fq '"mode":"passthrough","workflow":"other","exit":0' "$stats_file" || fail_test "pass-through stats missing"
grep -Eq '"input_bytes":[0-9]+.*"output_bytes":[0-9]+' "$stats_file" || fail_test "compact measurements missing"
grep -Fq '"input_bytes":null,"input_lines":null,"output_bytes":null,"output_lines":null' "$stats_file" || fail_test "pass-through measurements should be null"
python3 - "$stats_file" "$control_value" <<'PY' || fail_test "stats JSONL was invalid or lost control characters"
import json
import sys

records = [json.loads(line) for line in open(sys.argv[1], encoding="utf-8")]
assert records[4]["argv"][-1] == sys.argv[2]
PY

NPM_LITE_STATS=0 FAKE_NPM_MODE=success run_lite run verify >/dev/null
[[ "$(wc -l < "$stats_file" | tr -d ' ')" == 6 ]] || fail_test "stats opt-out was ignored"

printf 'npm-lite experiment tests passed\n'
