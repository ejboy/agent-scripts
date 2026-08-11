#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/repo-map-test.XXXXXX")"
cleanup() {
	rm -rf -- "$test_root"
}
trap cleanup EXIT

fail_test() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

run_map() {
	HOME="$test_root/home" "$root/scripts/repo-map" "$@"
}

repo_one="$test_root/first repository"
repo_two="$test_root/second-repository"
mkdir -p "$repo_one" "$repo_two" "$test_root/home"
git -C "$repo_one" init -q
git -C "$repo_two" init -q
git -C "$repo_one" remote add origin 'git@example.test:team/first-repository.git'
git -C "$repo_two" remote add origin 'https://example.test/team/second-repository.git'
printf '%s\n' initial >"$repo_one/file"
git -C "$repo_one" add file
git -C "$repo_one" -c user.name=test -c user.email=test@example.test commit -q -m initial
before_status="$(git -C "$repo_one" status --porcelain)"

output="$(run_map --help)"
[[ "$output" == *'repo-map [list]'* ]] || fail_test '--help did not show usage'
for subcommand in list add show get remove command commands; do
	output="$(run_map "$subcommand" --help)"
	[[ "$output" == *"Usage: repo-map $subcommand"* ]] || fail_test "$subcommand --help did not show subcommand usage"
done
mkdir -p "$test_root/home/.agent-scripts"
printf '%s\n' 'not-a-record' >"$test_root/home/.agent-scripts/repo-map"
for subcommand in list add show get remove command commands; do
	output="$(run_map "$subcommand" --help)"
	[[ "$output" == *"Usage: repo-map $subcommand"* ]] || fail_test "$subcommand --help depended on a valid registry"
done
rm -- "$test_root/home/.agent-scripts/repo-map"
output="$(run_map)"
[[ "$output" == *'agent-scripts'* && "$output" == *'[built-in]'* ]] || fail_test 'fresh HOME omitted built-in repository'
[[ ! -e "$test_root/home/.agent-scripts/repo-map" ]] || fail_test 'built-in discovery created a user registry'
expected_root="$(cd -- "$root" && pwd -P)"
[[ "$(run_map get agent-scripts)" == "$expected_root" ]] || fail_test 'built-in get returned the wrong path'
symlink_path="$test_root/repo-map"
ln -s "$root/scripts/repo-map" "$symlink_path"
[[ "$(HOME="$test_root/home" "$symlink_path" get agent-scripts)" == "$expected_root" ]] || fail_test 'symlinked repo-map resolved the wrong built-in path'
output="$(run_map show agent-scripts)"
[[ "$output" == *'Description: Local utilities for AI-assisted development'* ]] || fail_test 'built-in description was missing'
for builtin_command in mvn-lite html-screenshot launch-browser repo-map npm-lite; do
	[[ "$output" == *"$builtin_command"* ]] || fail_test "built-in command was missing: $builtin_command"
done
output="$(run_map commands)"
[[ "$output" == *'Registered commands:'* && "$output" == *'mvn-lite'* && "$output" == *'agent-scripts'* ]] || fail_test 'fresh commands omitted built-in capabilities'
output="$(PATH="$root/scripts:$PATH" run_map command html-screenshot)"
[[ "$output" == *'Command: html-screenshot'* && "$output" == *'Repository: agent-scripts'* && "$output" == *'Status: available'* && "$output" == *"Path: $root/scripts/html-screenshot"* && "$output" == *'Description: Render local HTML or URLs to PNG'* ]] || fail_test 'targeted command lookup did not show the available built-in command'
output="$(PATH="$root/scripts:$PATH" run_map commands --check)"
[[ "$output" == *'COMMAND'* && "$output" == *'available'* && "$output" == *"$root/scripts/mvn-lite"* ]] || fail_test 'commands --check did not resolve built-in commands'

fake_bin="$test_root/fake-bin"
mkdir -p "$fake_bin"
printf '#!/usr/bin/env bash\nexit 99\n' >"$fake_bin/mktemp"
chmod +x "$fake_bin/mktemp"
for action in 'list' 'show agent-scripts' 'get agent-scripts' 'command html-screenshot' 'commands' 'commands --check'; do
	PATH="$fake_bin:$root/scripts:$PATH" run_map $action >/dev/null || fail_test "read-only operation required mktemp: $action"
done

(cd "$repo_one" && HOME="$test_root/home" "$root/scripts/repo-map" add)
registry="$test_root/home/.agent-scripts/repo-map"
[[ -f "$registry" ]] || fail_test 'registry was not created under HOME'
[[ "$(git -C "$repo_one" status --porcelain)" == "$before_status" ]] || fail_test 'add modified the Git repository'
grep -Fxq "repo|first-repository|$(cd -- "$repo_one" && pwd -P)||" "$registry" || fail_test 'current repository was not added'

run_map add "$repo_two" >/dev/null
expected_two="$(cd -- "$repo_two" && pwd -P)"
[[ "$(run_map get second-repository)" == "$expected_two" ]] || fail_test 'get did not print only the canonical path'
[[ "$(run_map get first-repository)" == "$(cd -- "$repo_one" && pwd -P)" ]] || fail_test 'get failed for first repository'
output="$(run_map list)"
[[ "$output" == *'agent-scripts'* && "$output" == *'first-repository'* && "$output" == *'second-repository'* ]] || fail_test 'list omitted a repository'
output="$(run_map show second-repository)"
[[ "$output" == *'Commands:'* ]] || fail_test 'repository without commands was not valid'

awk -F '|' -v OFS='|' 'NR == 1 && $1 == "repo" { $4 = "User description"; $5 = "User notes" } { print }' "$registry" >"$test_root/registry.tmp"
mv -- "$test_root/registry.tmp" "$registry"
printf '%s\n' 'command|first-repository|mvn-lite|Compact Maven output' 'command|first-repository|html-screenshot|Render HTML to PNG' >>"$registry"
output="$(run_map show first-repository)"
[[ "$output" == *'Description: User description'* ]] || fail_test 'user description was not shown'
[[ "$output" == *'mvn-lite'* && "$output" == *'Compact Maven output'* ]] || fail_test 'user command metadata was not shown'
[[ "$output" == *'Notes: User notes'* ]] || fail_test 'user notes were not preserved'
[[ "$output" == *'first-repository'* ]] || fail_test 'show output was malformed'

output="$(run_map commands)"
[[ "$output" == *'mvn-lite'* && "$output" == *'first-repository'* && "$output" == *'html-screenshot'* ]] || fail_test 'commands did not aggregate metadata'
output="$(PATH="$root/scripts:$PATH" run_map command mvn-lite)"
[[ "$output" == *'Repository: agent-scripts'* && "$output" == *'Repository: first-repository'* ]] || fail_test 'targeted command lookup did not distinguish duplicate registrations'

printf '%s\n' 'command|first-repository|definitely-unavailable-command|Unavailable test command' >>"$registry"
set +e
targeted_unavailable_output="$(PATH="$root/scripts:$PATH" run_map command definitely-unavailable-command 2>&1)"
targeted_unavailable_status=$?
set -e
[[ "$targeted_unavailable_status" -ne 0 && "$targeted_unavailable_output" == *'Status: missing'* && "$targeted_unavailable_output" == *'Path: -'* ]] || fail_test 'targeted command lookup did not fail for an unavailable command'

set +e
unavailable_output="$(PATH="$root/scripts:$PATH" run_map commands --check 2>&1)"
unavailable_status=$?
set -e
[[ "$unavailable_status" -ne 0 && "$unavailable_output" == *'definitely-unavailable-command'* && "$unavailable_output" == *'missing'* ]] || fail_test 'commands --check did not fail for an unavailable command'

set +e
unknown_command_output="$(run_map command unknown-command 2>&1)"
unknown_command_status=$?
set -e
[[ "$unknown_command_status" -ne 0 && "$unknown_command_output" == *'unknown command'* ]] || fail_test 'targeted command lookup accepted an unknown command'

set +e
duplicate_output="$(run_map add "$repo_two" 2>&1)"
duplicate_status=$?
set -e
[[ "$duplicate_status" -ne 0 && "$duplicate_output" == *'already registered'* ]] || fail_test 'duplicate add did not fail clearly'

reserved_repo="$test_root/reserved-repository"
mkdir -p "$reserved_repo"
git -C "$reserved_repo" init -q
git -C "$reserved_repo" remote add origin 'git@example.test:team/agent-scripts.git'
set +e
reserved_output="$(run_map add "$reserved_repo" 2>&1)"
reserved_status=$?
set -e
[[ "$reserved_status" -ne 0 && "$reserved_output" == *'reserved'* ]] || fail_test 'add did not reject reserved repository name'

for action in 'get absent' 'show absent' 'remove absent'; do
	set +e
	unknown_output="$(run_map $action 2>&1)"
	unknown_status=$?
	set -e
	[[ "$unknown_status" -ne 0 && "$unknown_output" == *'unknown repository'* ]] || fail_test "unknown repository did not fail: $action"
done

registry_before_remove="$(<"$registry")"
run_map remove first-repository >/dev/null
[[ "$(git -C "$repo_one" status --porcelain)" == "$before_status" ]] || fail_test 'remove modified the Git repository'
[[ "$registry_before_remove" != "$(<"$registry")" ]] || fail_test 'remove did not change the registry'
! grep -Fq 'first-repository' "$registry" || fail_test 'remove left repository records behind'

printf '%s\n' 'repo|agent-scripts|/shadow||' >"$registry"
set +e
reserved_record_output="$(run_map list 2>&1)"
reserved_record_status=$?
set -e
[[ "$reserved_record_status" -ne 0 && "$reserved_record_output" == *'reserved repository name'* ]] || fail_test 'reserved registry record was accepted'

printf '%s\n' 'command|ghost|unavailable|No such command' >"$registry"
set +e
orphan_output="$(run_map list 2>&1)"
orphan_status=$?
set -e
[[ "$orphan_status" -ne 0 && "$orphan_output" == *'orphan command record'* ]] || fail_test 'orphan command record was accepted'

printf '%s\n' 'repo|no-commands|/does/not/exist||' >"$registry"
output="$(run_map show no-commands)"
[[ "$output" == *'Status: missing'* && "$output" == *'Commands:'* ]] || fail_test 'missing repository was not reported clearly'
set +e
missing_output="$(run_map get no-commands 2>&1)"
missing_status=$?
set -e
[[ "$missing_status" -ne 0 && "$missing_output" == *'path is missing'* ]] || fail_test 'missing get did not fail clearly'

printf '%s\n' 'not-a-record' >"$registry"
set +e
malformed_output="$(run_map list 2>&1)"
malformed_status=$?
set -e
[[ "$malformed_status" -ne 0 && "$malformed_output" == *'malformed registry line'* ]] || fail_test 'malformed registry was not rejected'

printf '%s\n' 'repo-map tests passed'
