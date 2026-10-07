#!/usr/bin/env bash
# turn a branch's commits into a github stacked pr, one pr per commit (bottom = oldest)
#
#   stack-pr.sh submit <branch> <base>   push the branch, build/refresh the stack against <base>
#   stack-pr.sh merge  <branch> <base>   merge the whole stack (atomic) once its checks are green
#
# the branch itself is never rewritten: its non-merge commits are cherry-picked onto origin/<base> in
# a throwaway worktree, skipping any whose patch already landed in <base> (earlier stacks land copies,
# not the originals) and any that come out empty. each picked commit gets a branch named
# stack/<branch>/<patch-id of the original>, which stays the same while the commit does, so running
# submit again updates the same prs and adds new commits on top.
# needs: gh + the official extension (gh extension install github/gh-stack)
set -euo pipefail

die() { printf 'stack-pr: %s\n' "$*" >&2; exit 1; }

mode=${1:-}
branch=${2:-}
base=${3:-}
[[ $mode == submit || $mode == merge ]] && [[ -n $branch && -n $base ]] ||
	die "usage: stack-pr.sh submit|merge <branch> <base>"
[[ $branch != "$base" ]] || die "pick a branch other than $base"
gh stack --version >/dev/null 2>&1 || die "missing gh-stack: gh extension install github/gh-stack"

remote=origin
prefix="stack/$branch/"

# open stack prs for this branch, as "number head base" lines
stack_prs() {
	gh pr list --state open --limit 200 --json number,headRefName,baseRefName \
		--jq ".[] | select(.headRefName | startswith(\"$prefix\")) | \"\(.number) \(.headRefName) \(.baseRefName)\""
}

if [[ $mode == merge ]]; then
	prs=$(stack_prs)
	[[ -n $prs ]] || die "no open stack for $branch"
	if [[ $(wc -l <<<"$prs") -eq 1 ]]; then
		exec gh pr merge "${prs%% *}" --merge
	fi
	# the top pr is the one no other stack pr is built on
	top=$(awk '{ number[$2] = $1; based_on[$3] = 1 } END { for (head in number) if (!(head in based_on)) print number[head] }' <<<"$prs")
	[[ $(wc -l <<<"$top") -eq 1 ]] || die "can't tell which pr is the top of the stack: $(tr '\n' ' ' <<<"$top")"
	echo "merging the stack up to #$top into $base"
	exec gh stack merge "$top" --yes --merge
fi

git push --quiet "$remote" "$branch"
git fetch --quiet "$remote" "$base"

candidates=$(git rev-list --reverse --no-merges "$remote/$base..$branch")
[[ -n $candidates ]] || { echo "nothing to stack: everything on $branch is already in $base"; exit 0; }

# patch ids that reached <base> since the oldest candidate forked off
oldest=$(head -n 1 <<<"$candidates")
since=$(git rev-parse --quiet --verify "$oldest^" || true)
landed=$(git log --no-merges -p --format='commit %H' ${since:+"$since.."}"$remote/$base" |
	git patch-id --stable | cut -d ' ' -f 1)

worktree=$(mktemp -d)
cleanup() {
	git -C "$worktree" cherry-pick --abort >/dev/null 2>&1 || true
	git worktree remove --force "$worktree" >/dev/null 2>&1 || true
	rm -rf "$worktree"
}
trap cleanup EXIT
git worktree add --quiet --detach "$worktree" "$remote/$base"

branches=()
while read -r commit; do
	id=$(git show "$commit" | git patch-id --stable | cut -d ' ' -f 1)
	[[ -n $id ]] || continue # an empty commit has nothing to review
	grep -qx "$id" <<<"$landed" && continue
	before=$(git -C "$worktree" rev-parse HEAD)
	git -C "$worktree" cherry-pick --empty=drop "$commit" >/dev/null 2>&1 ||
		die "$(git log -1 --format='%h "%s"' "$commit") doesn't apply on top of $remote/$base (a conflict, or it builds on a commit $base doesn't have); sort it out on $branch, then ctrl+s again"
	[[ $(git -C "$worktree" rev-parse HEAD) != "$before" ]] || continue # already in base under another patch id
	name="$prefix${id:0:8}"
	# two commits with the same diff (a revert of a revert) would share a name
	if [[ " ${branches[*]-} " == *" $name "* ]]; then name="$name-$((${#branches[@]} + 1))"; fi
	git branch --force "$name" "$(git -C "$worktree" rev-parse HEAD)"
	branches+=("$name")
done <<<"$candidates"
[[ ${#branches[@]} -gt 0 ]] || { echo "nothing to stack: every commit on $branch is already in $base"; exit 0; }

git push --quiet --force "$remote" "${branches[@]}"
if [[ ${#branches[@]} -eq 1 ]]; then
	# one commit is a plain pr, which (unlike a stack) can take auto-merge
	echo "one commit from $branch: plain pr into $base with auto-merge"
	gh pr create --base "$base" --head "${branches[0]}" --fill >/dev/null 2>&1 || true
	gh pr merge "${branches[0]}" --auto --merge
else
	echo "stacking ${#branches[@]} commits from $branch onto $base"
	# new prs open as drafts and only turn ready once the stack exists: their ci then runs knowing its
	# place in the stack (a pr opened before the stack has no stack info, so every one would run in full)
	gh stack link --base "$base" "${branches[@]}"
	for name in "${branches[@]}"; do
		gh pr ready "$name" >/dev/null 2>&1 || true # already ready from an earlier submit
	done
fi

# local refs were only needed for the push; the stack lives on github
git branch --quiet --delete --force "${branches[@]}"

# prs from commits that no longer exist (amended, dropped) stay in the github stack until closed
stale=$(stack_prs | awk -v keep=" ${branches[*]} " 'index(keep, " " $2 " ") == 0 { print "#" $1 }' | tr '\n' ' ')
[[ -z $stale ]] || echo "stale stack prs from rewritten commits, close them by hand: $stale"
