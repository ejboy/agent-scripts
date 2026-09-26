#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/agent-scripts-install-test.XXXXXX")"
cleanup() {
	rm -rf -- "$test_root"
}
trap cleanup EXIT

fail_test() {
	printf 'FAIL: %s\n' "$1" >&2
	exit 1
}

assert_contains() {
	local value="$1" expected="$2" message="$3"
	[[ "$value" == *"$expected"* ]] || fail_test "$message"
}

make_tool_path() {
	local path="$1" tool
	mkdir -p "$path"
	for tool in bash uname curl tar gzip mktemp mkdir mv rm chmod ln dirname readlink basename date; do
		ln -s "$(command -v "$tool")" "$path/$tool"
	done
}

make_archive() {
	local source="$1" archive="$2"
	tar --exclude=.git -czf "$archive" -C "$(dirname -- "$source")" "$(basename -- "$source")"
}

make_fixture() {
	local fixture="$1"
	mkdir -p "$fixture"
	cp -R "$root/scripts" "$root/skills" "$fixture/"
}

run_installer() {
	local home="$1" path="$2" archive="$3" output="$4"
	HOME="$home" PATH="$path" AGENT_SCRIPTS_ARCHIVE_URL="file://$archive" \
		/bin/bash "$root/install.sh" >"$output" 2>&1
}

assert_installation() {
	local home="$1" command entry symlink_count=0
	test -f "$home/.local/share/agent-scripts/skills/repolink/SKILL.md"
	test -f "$home/.local/share/agent-scripts/skills/repo-map/SKILL.md"
	test -f "$home/.local/share/agent-scripts/skills/lite-tools/SKILL.md"
	test ! -e "$home/.local/share/agent-scripts/.agents"
	for command in repolink repo-map mvn-lite npm-lite go-lite; do
		test -f "$home/.local/share/agent-scripts/scripts/$command"
		test -x "$home/.local/share/agent-scripts/scripts/$command"
		test -L "$home/.local/bin/$command"
	done
	for entry in "$home/.local/bin"/*; do
		[[ -L "$entry" ]] || continue
		symlink_count=$((symlink_count + 1))
	done
	[[ "$symlink_count" == 5 ]] ||
		fail_test 'installer must expose four core commands and one compatibility command'
}

fixture="$test_root/agent-scripts-main"
make_fixture "$fixture"
archive="$test_root/agent-scripts-main.tar.gz"
make_archive "$fixture" "$archive"
git -C "$fixture" init -q
git -C "$fixture" add scripts skills
git -C "$fixture" -c user.name=test -c user.email=test@example.test commit -q -m fixture

archive_home="$test_root/archive-home"
archive_bin="$test_root/archive-bin"
mkdir -p "$archive_home"
make_tool_path "$archive_bin"
run_installer "$archive_home" "$archive_bin" "$archive" "$test_root/archive.out"
assert_installation "$archive_home"
test ! -e "$archive_home/.local/share/agent-scripts/.git"
for command in repolink repo-map mvn-lite npm-lite go-lite; do
	case "$command" in
		repolink|repo-map) help_flag=--help ;;
		*) help_flag="--help-$command" ;;
	esac
	HOME="$archive_home" PATH="$archive_home/.local/bin:$archive_bin" \
		"$archive_home/.local/bin/$command" "$help_flag" >/dev/null ||
		fail_test "$command help failed after archive installation"
done
commands_output="$(HOME="$archive_home" PATH="$archive_home/.local/bin:$archive_bin" \
	"$archive_home/.local/bin/repolink" commands)"
for command in repolink mvn-lite npm-lite go-lite; do
	assert_contains "$commands_output" "$command" "repolink commands omitted $command"
done
[[ "$commands_output" != *'repo-map'* ]] || fail_test 'deprecated alias was presented as a registered command'
set +e
check_output="$(HOME="$archive_home" PATH="$archive_home/.local/bin:$archive_bin" \
	"$archive_home/.local/bin/repolink" commands --check)"
check_status=$?
set -e
[[ "$check_status" -ne 0 ]] || fail_test 'repolink commands --check did not report unavailable repository-only commands'
for command in repolink mvn-lite npm-lite go-lite; do
	assert_contains "$check_output" "$command" "repolink commands --check omitted $command"
done
assert_contains "$(<"$test_root/archive.out")" 'not currently on PATH' 'installer did not explain missing ~/.local/bin PATH entry'
assert_contains "$(<"$test_root/archive.out")" 'export PATH="$HOME/.local/share/agent-scripts/scripts:$PATH"' 'installer omitted full PATH guidance'
test ! -e "$archive_home/.zshrc"
test ! -e "$archive_home/.bashrc"

printf '%s\n' sentinel >"$archive_home/.local/share/agent-scripts/sentinel"
PATH="$archive_home/.local/bin:$archive_bin" \
	HOME="$archive_home" AGENT_SCRIPTS_ARCHIVE_URL="file://$archive" \
	/bin/bash "$root/install.sh" >"$test_root/archive-rerun.out" 2>&1
test ! -e "$archive_home/.local/share/agent-scripts/sentinel"
assert_installation "$archive_home"
assert_contains "$(<"$test_root/archive-rerun.out")" 'ready to use' 'installer did not recognize ~/.local/bin on PATH'

git_home="$test_root/git-home"
HOME="$git_home" AGENT_SCRIPTS_GIT_URL="$fixture" /bin/bash "$root/install.sh" >"$test_root/git.out" 2>&1
assert_installation "$git_home"
test -d "$git_home/.local/share/agent-scripts/.git"
printf '%s\n' sentinel >"$git_home/.local/share/agent-scripts/sentinel"
HOME="$git_home" AGENT_SCRIPTS_GIT_URL="$test_root/missing-repository" \
	/bin/bash "$root/install.sh" >"$test_root/git-rerun.out" 2>&1
test -f "$git_home/.local/share/agent-scripts/sentinel"
assert_contains "$(<"$test_root/git-rerun.out")" 'Installation mode: git' 'existing Git checkout was not preserved'

missing_core_fixture="$test_root/missing-core"
make_fixture "$missing_core_fixture"
rm -- "$missing_core_fixture/scripts/go-lite"
missing_core_archive="$test_root/missing-core.tar.gz"
make_archive "$missing_core_fixture" "$missing_core_archive"
set +e
missing_core_output="$(HOME="$test_root/missing-core-home" PATH="$archive_bin" AGENT_SCRIPTS_ARCHIVE_URL="file://$missing_core_archive" /bin/bash "$root/install.sh" 2>&1)"
missing_core_status=$?
set -e
[[ "$missing_core_status" -ne 0 ]] || fail_test 'archive missing a core script was accepted'
assert_contains "$missing_core_output" 'missing scripts/go-lite' 'missing core script failure was unclear'
test ! -e "$test_root/missing-core-home/.local/share/agent-scripts"

invalid_archive="$test_root/invalid.tar.gz"
printf '%s\n' 'not an archive' >"$invalid_archive"
set +e
invalid_output="$(HOME="$test_root/invalid-home" PATH="$archive_bin" AGENT_SCRIPTS_ARCHIVE_URL="file://$invalid_archive" /bin/bash "$root/install.sh" 2>&1)"
invalid_status=$?
set -e
[[ "$invalid_status" -ne 0 ]] || fail_test 'invalid archive was accepted'
assert_contains "$invalid_output" 'could not extract repository archive' 'invalid archive failure was unclear'

unsupported_bin="$test_root/unsupported-bin"
make_tool_path "$unsupported_bin"
rm -- "$unsupported_bin/uname"
printf '#!/usr/bin/env bash\nprintf "FreeBSD\\n"\n' >"$unsupported_bin/uname"
chmod +x "$unsupported_bin/uname"
set +e
unsupported_output="$(HOME="$test_root/unsupported-home" PATH="$unsupported_bin" /bin/bash "$root/install.sh" 2>&1)"
unsupported_status=$?
set -e
[[ "$unsupported_status" -ne 0 ]] || fail_test 'unsupported OS was accepted'
assert_contains "$unsupported_output" 'unsupported operating system' 'unsupported OS failure was unclear'

unusable_home="$test_root/unusable-home"
mkdir -p "$unusable_home/.local"
printf '%s\n' file >"$unusable_home/.local/share"
set +e
unusable_output="$(HOME="$unusable_home" PATH="$archive_bin" AGENT_SCRIPTS_ARCHIVE_URL="file://$archive" /bin/bash "$root/install.sh" 2>&1)"
unusable_status=$?
set -e
[[ "$unusable_status" -ne 0 ]] || fail_test 'unusable HOME target was accepted'
assert_contains "$unusable_output" 'could not create installation directories' 'unusable installation target failure was unclear'

! grep -Fq 'sudo' "$root/install.sh" || fail_test 'installer invokes sudo'
printf 'installer tests passed\n'
