# sourced by ~/.zshrc on macos

# Prefer the prefixed GNU commands (gdate, gstat, etc.) over replacing macOS tools.
if [[ -n ${HOMEBREW_PREFIX:-} ]]; then
	path=(${path:#${HOMEBREW_PREFIX}/opt/coreutils/libexec/gnubin})
	path=(${path:#${HOMEBREW_PREFIX}/opt/findutils/libexec/gnubin})
	path=(${path:#${HOMEBREW_PREFIX}/opt/gnu-sed/libexec/gnubin})
	path=(${path:#${HOMEBREW_PREFIX}/opt/grep/libexec/gnubin})
fi

# Rust toolchain
path=("/opt/homebrew/opt/rustup/bin" $path)

start-ng() {
	local location="${1:-au}"
	local environment="${2:-test}"
	local repo

	case "$location" in
		nz) repo="$HOME/clone/content-apps-nz" ;;
		2) repo="$HOME/clone/content-apps-au_two" ;;
		*) repo="$HOME/clone/content-apps-au" ;;
	esac

	if [[ ! -d "$repo" ]]; then
		print -u2 "start-ng: repository not found: $repo"
		return 1
	fi

	cd "$repo" || return

	local full_branch branch
	full_branch=$(command git branch --show-current) || return
	branch="${full_branch%%/*}"

	if [[ -z "$branch" ]]; then
		print -u2 "start-ng: cannot determine the current branch"
		return 1
	fi

	npm run task client leap "$location" "$environment" "$branch"
}

# Let terminal pinentry follow the active TTY for signed commits.
if [[ -t 0 ]] && (( $+commands[gpg-connect-agent] )); then
	export GPG_TTY=$(tty)
	gpg-connect-agent updatestartuptty /bye >/dev/null 2>&1
fi
