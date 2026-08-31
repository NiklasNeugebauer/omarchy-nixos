#!/usr/bin/env bash
# Bump the pinned omarchy input and report what changed, classified the way
# scripts/sync-upstream.md classifies it. Read-only apart from flake.lock: it never edits a
# module, never builds, and never switches. The judgement calls stay with a person.

set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo"

rev_of() { nix flake metadata --json | jq -r '.locks.nodes.omarchy.locked.rev'; }

old=$(rev_of)
echo "omarchy is pinned at $old"

nix flake update omarchy
new=$(rev_of)

if [[ $old == "$new" ]]; then
  echo "Already up to date."
  exit 0
fi

echo "Bumped to $new"
echo

# The diff comes from a throwaway clone: the flake input is a bare source tree in the store
# with no git history to diff against.
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
# Blobs are fetched on demand by the diff below; a full history clone of this repo is
# hundreds of megabytes of theme backgrounds nobody is diffing.
git clone --quiet --bare --filter=blob:none https://github.com/basecamp/omarchy.git "$work/omarchy.git"

changed=$(git -C "$work/omarchy.git" diff --name-only "$old" "$new")

echo "=== commits ==="
git -C "$work/omarchy.git" log --oneline "$old..$new"
echo

classify() {
  local label=$1 pattern=$2
  local matched
  matched=$(grep -E "$pattern" <<<"$changed" || true)
  [[ -n $matched ]] || return 0
  printf '=== %s ===\n%s\n\n' "$label" "$matched"
}

classify "vendored — ships as-is, no action" \
  '^(bin|default|shell|themes|config|applications)/|^(version|logo\.[a-z]+|icon\.[a-z]+)$'
classify "package — update packages.nix and the inventory" \
  '^install/omarchy-.*\.packages$'
classify "script — translate into a modules/omarchy/*.nix option" \
  '^(install/(config|hardware|login|post-install|provisioning|helpers|user)/|etc/)'
classify "ignore — not shipped, or no NixOS meaning" \
  '^(test|manual|plans|docs|agents|migrations)/|^(README|CLAUDE|AGENTS)\.md$|^LICENSE$'

# Everything the four buckets above did not claim. `version` alone would otherwise land
# here on every single release, and a warning that always fires is a warning nobody reads.
unclassified=$(grep -vE '^(bin|default|shell|themes|config|applications|test|manual|plans|docs|agents|migrations)/|^install/|^etc/|^(version|logo\.[a-z]+|icon\.[a-z]+|LICENSE)$|^(README|CLAUDE|AGENTS)\.md$' <<<"$changed" || true)
if [[ -n $unclassified ]]; then
  printf '=== UNCLASSIFIED — decide before committing ===\n%s\n\n' "$unclassified"
fi

# A command we stub or replace that upstream renamed fails the build with a porting-steps
# message. Saying so here is cheaper than finding out at the end of a build.
for command in $(nix eval --raw --apply 'p: builtins.concatStringsSep " " (builtins.attrNames p.archOnly)' .#omarchy.passthru 2>/dev/null || true); do
  git -C "$work/omarchy.git" cat-file -e "$new:bin/$command" 2>/dev/null ||
    echo "gone upstream, drop from pkgs/omarchy/nixos-commands.nix: $command"
done
for replacement in pkgs/omarchy/commands/*; do
  name=$(basename "$replacement")
  git -C "$work/omarchy.git" cat-file -e "$new:bin/$name" 2>/dev/null ||
    echo "gone upstream, drop from pkgs/omarchy/commands/: $name"
done

cat <<'NEXT'

Next, by hand:
  1. Re-read docs/porting-steps.md — steps 7 to 10 are not self-verifying.
  2. nix flake check && nix build .#omarchy
  3. nix build .#nixosConfigurations.omarchy-vm.config.system.build.vm
     ./result/bin/run-omarchy-vm-vm, then the hardware checklist in docs/progress.md
  4. Write the sync report into the commit body.
NEXT
