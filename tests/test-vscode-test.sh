#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/vscode-test-test.XXXXXX")"
cleanup() { rm -rf -- "$test_root"; }
trap cleanup EXIT

bin_dir="$test_root/bin"
home_dir="$test_root/home"
workspace="$test_root/workspace"
workspace_file="$test_root/review.code-workspace"
code_args="$test_root/code-args"
fake_app="$test_root/Visual Studio Code Test.app"
fake_code="$fake_app/Contents/MacOS/Code"
mkdir -p "$bin_dir" "$home_dir" "$workspace" "$(dirname -- "$fake_code")"
printf '{"folders":[{"path":"workspace"}]}\n' >"$workspace_file"

fail_test() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

cat >"$bin_dir/curl" <<'EOF'
#!/usr/bin/env bash
[[ -f "$FAKE_CDP_READY" ]]
EOF
cat >"$bin_dir/lsof" <<'EOF'
#!/usr/bin/env bash
if [[ ! -e "$FAKE_LSOF_ATTEMPTED" ]]; then
	printf attempted >"$FAKE_LSOF_ATTEMPTED"
	exit 1
fi
[[ -f "$FAKE_CODE_PID" ]] && cat "$FAKE_CODE_PID"
EOF
cat >"$bin_dir/launchctl" <<'EOF'
#!/usr/bin/env bash
case "$1" in
	submit)
		shift
		while [[ "$1" != -- ]]; do shift; done
		shift
		nohup "$@" >/dev/null 2>&1 &
		;;
	remove) exit 0 ;;
esac
EOF
cat >"$bin_dir/node" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == -p ]]; then
	printf '%s\n' "${FAKE_NODE_VERSION:-22.0.0}"
	exit 0
fi
printf '{"mode":"%s","target":"%s","limit":%s}\n' "$VSCODE_TEST_MODE" "$VSCODE_TEST_TARGET" "$VSCODE_TEST_LIMIT"
EOF
cat >"$bin_dir/osascript" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$FAKE_OSASCRIPT_ARGS"
cat >/dev/null
EOF
cat >"$bin_dir/ps" <<'EOF'
#!/usr/bin/env bash
recorded_pid="$(cat "$FAKE_CODE_PID" 2>/dev/null || true)"
if [[ -n "$recorded_pid" && "$*" == *"$recorded_pid"* ]] && kill -0 "$recorded_pid" 2>/dev/null; then
	if [[ "$*" == *'command='* ]]; then printf 'Code --remote-debugging-port=9333\n'; else printf '%s\n' "$recorded_pid"; fi
fi
EOF
cat >"$bin_dir/screencapture" <<'EOF'
#!/usr/bin/env bash
printf png >"$2"
EOF
cat >"$fake_code" <<'EOF'
#!/usr/bin/env bash
cleanup_code() {
	if [[ "${FAKE_CODE_IGNORE_FIRST_TERM:-false}" == true && ! -f "$FAKE_CODE_TERM_SEEN" ]]; then
		printf seen >"$FAKE_CODE_TERM_SEEN"
		return
	fi
	rm -f -- "$FAKE_CDP_READY"
	exit 0
}
trap cleanup_code INT TERM
printf '%s\n' "$@" >"$FAKE_CODE_ARGS"
printf '%s\n' "$$" >"$FAKE_CODE_PID"
printf ready >"$FAKE_CDP_READY"
while :; do sleep 1; done
EOF
chmod +x "$bin_dir"/* "$fake_code"

run_tool() {
	HOME="$home_dir" PATH="$bin_dir:/usr/bin:/bin" FAKE_CDP_READY="$test_root/ready" \
		FAKE_CODE_ARGS="$code_args" FAKE_CODE_PID="$test_root/code-pid" \
		FAKE_LSOF_ATTEMPTED="$test_root/lsof-attempted" \
		FAKE_OSASCRIPT_ARGS="$test_root/osascript-args" \
		FAKE_CODE_IGNORE_FIRST_TERM="${FAKE_CODE_IGNORE_FIRST_TERM:-false}" \
		FAKE_CODE_TERM_SEEN="$test_root/code-term-seen" \
		VSCODE_TEST_CODE_BIN="$fake_code" "$root/scripts/vscode-test" "$@"
}

expected_version="$(<"$root/VERSION")"
output="$(run_tool --help)"
[[ "$output" == "vscode-test $expected_version"* ]] || fail_test 'help version heading missing'

output="$(run_tool launch --port 9333 --extension-development-path "$test_root/extension" "$workspace")"
[[ "$output" == 'VS Code ready: pid='*' cdp=http://127.0.0.1:9333' ]] || fail_test 'launch output was not compact'
grep -Fxq -- '--remote-debugging-port=9333' "$code_args" || fail_test 'DevTools port was not passed'
grep -Fxq -- "--extensionDevelopmentPath=$test_root/extension" "$code_args" || fail_test 'extension path was not passed'
grep -Fxq -- "$workspace" "$code_args" || fail_test 'workspace was not passed'
[[ "$(run_tool status --port 9333)" == 'VS Code ready: pid='*' cdp=http://127.0.0.1:9333' ]] || fail_test 'status output was unexpected'
rm -f -- "$test_root/ready"
set +e
output="$(run_tool status --port 9333 2>&1)"
status=$?
set -e
[[ "$status" -eq 1 && "$output" == *'sandbox restrictions may be blocking process or localhost probes'* && "$output" == *'approve this vscode-test invocation'* ]] || fail_test 'status did not explain a probable sandbox restriction'
set +e
output="$(run_tool inspect page --port 9333 2>&1)"
status=$?
set -e
[[ "$status" -eq 1 && "$output" == *'sandbox restrictions may be blocking process or localhost probes'* && "$output" == *'approve this vscode-test invocation'* ]] || fail_test 'inspect did not explain a probable sandbox restriction'
printf ready >"$test_root/ready"
set +e
output="$(run_tool launch --port 9333 "$workspace" 2>&1)"
status=$?
set -e
[[ "$status" -eq 1 && "$output" == *'managed launch state already exists'* ]] || fail_test 'launch overwrote live recovery state'
[[ "$(run_tool inspect panel --port 9333)" == '{"mode":"inspect","target":"panel","limit":4000}' ]] || fail_test 'panel inspection was not routed'
grep -Fq 'querySelector("#active-frame").contentDocument' "$root/scripts/vscode-test" || fail_test 'panel inspection did not enter the active frame'
grep -Fq 'panel target is ambiguous' "$root/scripts/vscode-test" || fail_test 'panel inspection did not reject ambiguous targets'
! grep -Fq 'contentDocument || document' "$root/scripts/vscode-test" || fail_test 'panel inspection retained the outer-document fallback'
set +e
output="$(FAKE_NODE_VERSION=20.19.0 run_tool inspect panel --port 9333 2>&1)"
status=$?
set -e
[[ "$status" -eq 1 && "$output" == *'requires Node.js 22+'* && "$output" == *'found 20.19.0'* ]] || fail_test 'unsupported Node.js version did not fail clearly'
[[ "$(run_tool text page --limit 250 --port 9333)" == '{"mode":"text","target":"page","limit":250}' ]] || fail_test 'text options were not routed'
[[ "$(run_tool controls page --filter 'AI Badger' --port 9333)" == '{"mode":"controls","target":"page","limit":4000}' ]] || fail_test 'controls options were not routed'
[[ "$(run_tool click --aria-label 'Source Control' --port 9333)" == '{"mode":"click","target":"page","limit":4000}' ]] || fail_test 'click options were not routed'
[[ "$(run_tool palette 'AI Badger: Copy Workspace Changes for Review' --port 9333)" == '{"mode":"palette","target":"page","limit":4000}' ]] || fail_test 'palette options were not routed'
[[ "$(run_tool wait-control --aria-label 'AI Badger: Copy Changes for Review' --count 1 --timeout 5 --port 9333)" == '{"mode":"wait-control","target":"page","limit":4000}' ]] || fail_test 'wait-control options were not routed'
grep -Fq 'pane-header,.view-pane,.scm-view,.monaco-list-row' "$root/scripts/vscode-test" || fail_test 'control inspection omitted placement context'
grep -Fq 'dataset.commandId||e.dataset.actionId' "$root/scripts/vscode-test" || fail_test 'control inspection omitted command identity'
set +e
output="$(run_tool wait-control --aria-label test --port 9333 2>&1)"
status=$?
set -e
[[ "$status" -eq 1 && "$output" == *'--count must be a non-negative integer'* ]] || fail_test 'wait-control accepted a missing count'
managed_pid="$(<"$test_root/code-pid")"
[[ "$(run_tool activate --port 9333)" == "VS Code activated: pid=$managed_pid" ]] || fail_test 'activation output was unexpected'
grep -Fxq -- "$managed_pid" "$test_root/osascript-args" || fail_test 'activation did not target the managed PID'
[[ "$(run_tool screenshot "$test_root/screen.png")" == "Screenshot: $test_root/screen.png" ]] || fail_test 'screenshot output was unexpected'
[[ -s "$test_root/screen.png" ]] || fail_test 'screenshot was not created'
[[ "$(run_tool stop --port 9333)" == 'VS Code stopped: pid='* ]] || fail_test 'stop output was unexpected'
[[ ! -f "$home_dir/.agent-scripts/vscode-test/launch-9333.state" ]] || fail_test 'stop retained launch state'

rm -f -- "$test_root/lsof-attempted"
output="$(FAKE_CODE_IGNORE_FIRST_TERM=true run_tool launch --port 9333 "$workspace")"
[[ "$output" == 'VS Code ready: pid='* ]] || fail_test 'second launch output was unexpected'
[[ "$(run_tool stop --port 9333)" == 'VS Code stopped: pid='* ]] || fail_test 'stop did not retry termination'
[[ -f "$test_root/code-term-seen" ]] || fail_test 'first termination was not ignored by the fixture'
[[ ! -f "$home_dir/.agent-scripts/vscode-test/launch-9333.state" ]] || fail_test 'retried stop retained launch state'

rm -f -- "$test_root/lsof-attempted"
output="$(run_tool launch --port 9333 "$workspace_file")"
[[ "$output" == 'VS Code ready: pid='* ]] || fail_test '.code-workspace launch output was unexpected'
grep -Fxq -- "$workspace_file" "$code_args" || fail_test '.code-workspace file was not passed'
[[ "$(run_tool stop --port 9333)" == 'VS Code stopped: pid='* ]] || fail_test '.code-workspace session did not stop'

printf 'service=test.dead\npid=999999\nlog=%s\n' "$test_root/dead.log" >"$home_dir/.agent-scripts/vscode-test/launch-9333.state"
printf '999999\n' >"$test_root/code-pid"
printf ready >"$test_root/ready"
[[ "$(run_tool status --port 9333)" == 'VS Code ready: pid=999999 cdp=http://127.0.0.1:9333' ]] || fail_test 'status ignored the matching listener PID'
rm -f -- "$test_root/ready" "$test_root/code-pid"
[[ "$(run_tool stop --port 9333)" == 'VS Code already stopped: pid=999999; stale state removed' ]] || fail_test 'stop did not report an already-dead process'
printf 'service=test.dead\npid=999999\nlog=%s\n' "$test_root/dead.log" >"$home_dir/.agent-scripts/vscode-test/launch-9333.state"
set +e
output="$(run_tool status --port 9333 2>&1)"
status=$?
set -e
[[ "$status" -eq 1 && "$output" == *'stale launch state removed'* ]] || fail_test 'status did not remove stale state'
[[ ! -f "$home_dir/.agent-scripts/vscode-test/launch-9333.state" ]] || fail_test 'status retained stale state'

set +e
output="$(run_tool inspect --port 70000 2>&1)"
status=$?
set -e
[[ "$status" -eq 1 && "$output" == *'invalid port'* ]] || fail_test 'invalid port was accepted'

printf 'vscode-test tests passed\n'
