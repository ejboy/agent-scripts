#!/usr/bin/env bash

set -uo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/agent-complaint-test.XXXXXX")"
report_file="$test_root/data/complaints.jsonl"

cleanup() { rm -rf "$test_root"; }
fail_test() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
trap cleanup EXIT

assert_jsonl() {
	python3 -c 'import json, sys
for line in open(sys.argv[1], encoding="utf-8"):
    json.loads(line)' "$1" || fail_test "invalid JSONL: $1"
}

run_complaint() {
	AGENT_COMPLAINT_FILE="$report_file" "$root/agent-complaint" "$@"
}

output="$(run_complaint 'printf "a $HOME"' 'The "useful" line was hard to parse; do not retain output')"
[[ "$output" == 'Complaint recorded.' ]] || fail_test "success message was unexpected"
[[ -f "$report_file" ]] || fail_test "report file was not created"
assert_jsonl "$report_file"

run_complaint --command 'npm run verify' --issue noisy-success --details '250 tests passed' \
	--exit-code 0 --output-lines 1800 --output-bytes 42000 >/dev/null
run_complaint --command 'tool --flag=$HOME' --details 'A failure was misleading' >/dev/null
control_value=$'before\001\002\006\010\013\014\016\037after'
directory_name="${PWD##*/}"
[[ -n "$directory_name" ]] || directory_name="/"
run_complaint "$control_value" "$control_value" >/dev/null
[[ "$(wc -l < "$report_file" | tr -d ' ')" == 4 ]] || fail_test "invocations did not append separately"

python3 - "$report_file" "$control_value" "$directory_name" <<'PY' || fail_test "record fields were not preserved"
import json
import sys

records = [json.loads(line) for line in open(sys.argv[1], encoding="utf-8")]
assert records[0]["command"] == 'printf "a $HOME"'
assert records[0]["details"] == 'The "useful" line was hard to parse; do not retain output'
assert records[0]["issue"] == "other"
assert records[0]["timestamp"].startswith("20")
assert records[1]["exit_code"] == 0
assert records[1]["output_lines"] == 1800
assert records[1]["output_bytes"] == 42000
assert records[3]["command"] == sys.argv[2]
assert records[3]["details"] == sys.argv[2]
assert all(record["directory"] == sys.argv[3] for record in records)
assert all("cwd" not in record and "environment" not in record and "stdout" not in record and "stderr" not in record for record in records)
PY

set +e
run_complaint 'only-command' >/dev/null 2>&1
status=$?
set -e
[[ "$status" != 0 ]] || fail_test "missing details did not fail"

mkdir "$test_root/unwritable"
set +e
AGENT_COMPLAINT_FILE="$test_root/unwritable" "$root/agent-complaint" cmd details >/dev/null 2>&1
status=$?
set -e
[[ "$status" != 0 ]] || fail_test "unwritable destination did not fail"

help="$("$root/agent-complaint" --help)"
[[ "$help" == *"coding agents"* && "$help" == *"do not"* && "$help" == *"noisy-success"* ]] || fail_test "help does not explain agent usage"
[[ "$help" == *"npm test"* && "$help" == *"javadoc"* ]] || fail_test "help examples are missing"

printf 'agent-complaint tests passed\n'
