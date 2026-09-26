#!/usr/bin/env bash
set -euo pipefail

readonly repository_url="${AGENT_SCRIPTS_GIT_URL:-https://github.com/ejboy/agent-scripts.git}"
readonly archive_url="${AGENT_SCRIPTS_ARCHIVE_URL:-https://github.com/ejboy/agent-scripts/archive/refs/heads/main.tar.gz}"
readonly core_commands=(repolink mvn-lite npm-lite go-lite)
readonly compatibility_commands=(repo-map)
readonly install_commands=("${core_commands[@]}" "${compatibility_commands[@]}")

fail() {
	printf 'Error: %s\n' "$1" >&2
	exit 1
}

validate_repository() {
	local repository="$1"
	local command

	[[ -f "$repository/skills/repolink/SKILL.md" ]] || fail "installation is missing skills/repolink/SKILL.md"
	[[ -f "$repository/skills/repo-map/SKILL.md" ]] || fail "installation is missing the repo-map compatibility Skill"
	[[ -f "$repository/skills/lite-tools/SKILL.md" ]] || fail "installation is missing skills/lite-tools/SKILL.md"
	for command in "${core_commands[@]}"; do
		[[ -f "$repository/scripts/$command" ]] || fail "installation is missing scripts/$command"
		bash -n "$repository/scripts/$command" || fail "scripts/$command contains invalid Bash syntax"
	done
	for command in "${compatibility_commands[@]}"; do
		[[ -f "$repository/scripts/$command" ]] || fail "installation is missing compatibility command scripts/$command"
		/bin/sh -n "$repository/scripts/$command" || fail "scripts/$command contains invalid shell syntax"
	done
}

install_archive() {
	local staging_root archive_file staged_repository previous_repository

	command -v tar >/dev/null 2>&1 || fail 'tar is required for archive installation'
	staging_root="$(mktemp -d "$share_dir/.agent-scripts-install.XXXXXX")"
	archive_file="$staging_root/repository.tar.gz"
	staged_repository="$staging_root/repository"
	previous_repository="$staging_root/previous"
	mkdir -p "$staged_repository"
	curl -fsSL "$archive_url" -o "$archive_file" || fail "could not download repository archive"
	tar -xzf "$archive_file" -C "$staged_repository" --strip-components=1 || fail "could not extract repository archive"
	validate_repository "$staged_repository"
	if [[ -e "$install_dir" ]]; then
		mv "$install_dir" "$previous_repository" || fail "could not stage the existing installation for replacement"
	fi
	if ! mv "$staged_repository" "$install_dir"; then
		[[ ! -e "$previous_repository" ]] || mv "$previous_repository" "$install_dir"
		fail "could not install the repository archive"
	fi
	rm -rf -- "$staging_root"
}

case "$(uname -s)" in
	Darwin | Linux) ;;
	*) fail "unsupported operating system; Agent Scripts supports macOS and Linux" ;;
esac

[[ -n "${HOME:-}" ]] || fail 'HOME is not set'
[[ "$HOME" == /* && "$HOME" != / ]] || fail 'HOME must be an absolute, usable directory'
command -v bash >/dev/null 2>&1 || fail 'Bash is required'
command -v curl >/dev/null 2>&1 || fail 'curl is required'

readonly share_dir="$HOME/.local/share"
readonly install_dir="$share_dir/agent-scripts"
readonly bin_dir="$HOME/.local/bin"
mkdir -p "$share_dir" "$bin_dir" || fail 'could not create installation directories under HOME'

mode=
if [[ -d "$install_dir/.git" ]]; then
	mode=git
elif [[ -e "$install_dir" ]]; then
	mode=archive
	install_archive
elif command -v git >/dev/null 2>&1; then
	mode=git
	git clone "$repository_url" "$install_dir" || fail 'could not clone the Agent Scripts repository'
else
	mode=archive
	install_archive
fi

validate_repository "$install_dir"
chmod +x "${install_commands[@]/#/$install_dir/scripts/}"

for command in "${install_commands[@]}"; do
	link="$bin_dir/$command"
	if [[ -e "$link" && ! -L "$link" ]]; then
		fail "$link exists and is not a symbolic link"
	fi
	ln -sfn "$install_dir/scripts/$command" "$link"
done

printf 'Installed Agent Scripts in %s\n' "$install_dir"
printf 'Installation mode: %s\n' "$mode"
printf 'Core commands: %s\n' "${core_commands[*]}"
printf 'Deprecated compatibility command: %s\n' "${compatibility_commands[*]}"
if [[ ":$PATH:" == *":$bin_dir:"* ]]; then
	printf 'The four core commands are ready to use from %s.\n' "$bin_dir"
else
	printf 'The command symlinks were created in %s, which is not currently on PATH.\n' "$bin_dir"
fi
printf '\nFor all current and future Agent Scripts, add this line to your shell startup file:\n'
printf 'export PATH="$HOME/.local/share/agent-scripts/scripts:$PATH"\n'
if [[ "$mode" == git ]]; then
	printf '\nUpdate this checkout and refresh its command links with:\n'
	printf 'git -C "$HOME/.local/share/agent-scripts" pull --ff-only\n'
	printf 'bash "$HOME/.local/share/agent-scripts/install.sh"\n'
else
	printf '\nRerun this installer to update the archive snapshot.\n'
fi
