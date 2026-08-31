# Syncing an upstream release

Trigger: a new tag on [basecamp/omarchy](https://github.com/basecamp/omarchy). One sync, one
commit (or one PR), never mixed with a nixpkgs bump.

## 1. See what moved

    old=$(nix flake metadata --json | jq -r '.locks.nodes.omarchy.locked.rev')
    nix flake update omarchy
    new=$(nix flake metadata --json | jq -r '.locks.nodes.omarchy.locked.rev')

    git -C <omarchy checkout> log --oneline "$old..$new"
    git -C <omarchy checkout> diff --stat "$old..$new"

## 2. Classify every changed path

`./scripts/sync-upstream.sh` does the bump and prints every changed path in its bucket, so
there is no table here to fall out of step with the script that implements it. Read its
output, and note two things it cannot infer:

- A **new command that manages packages, the bootloader or snapshots** needs a row in
  `pkgs/omarchy/nixos-commands.nix`. The package build now catches this — it fails naming any
  `bin/` command that reaches for pacman, the AUR, Limine or Snapper and is in neither table
  nor the allowlist — but the build cannot decide *which* of the three it belongs in.
- The **vendored** bucket says "ships as-is", and that is true of the tree, not of this repo.
  The modules reach into `default/` and `config/` by path. A new `config/<app>/` that the
  application writes to has to go in `home.nix`'s `seeded` list, or every write to it fails
  silently; see porting step 9.

## 3. Re-read the porting steps

Walk `docs/porting-steps.md`. Most steps verify themselves during the build; the ones marked
**check by hand** do not. Do those now, not after the VM boots.

## 4. Build and smoke test

The procedure is the one in `AGENTS.md` under *Making a change* — it is not repeated here so
that there is one copy of it. In short: `nix flake check`, then
`nix build .#desktop-screenshots`, then the checklist in `docs/progress.md` if the session
changed.

## 5. Write the sync report

Put it in the commit body or the PR description, three short sections:

    Upstream:   <old rev> → <new rev>, <n> commits. What changed, in a sentence or two.
    Translated: which modules changed and why.
    Ignored:    what was skipped, and the reason for each.

If a step in `docs/porting-steps.md` had to change, say so explicitly. That list is the port,
and a change to it is the most important thing in the diff.

## Bumping nixpkgs instead

Separate commit, always:

    nix flake update nixpkgs home-manager disko

Then the same build and smoke test. A nixpkgs bump breaks this port through renamed
attributes and removed options far more often than upstream does, so read the eval warnings
rather than skipping past them.
