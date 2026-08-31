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

Four buckets, and every changed file lands in exactly one:

| Changed path | Bucket | What to do |
| --- | --- | --- |
| `bin/`, `default/`, `shell/`, `themes/`, `config/`, `applications/` | **vendored** | Nothing. It ships as-is. |
| `install/omarchy-*.packages` | **package** | Translate the diff into `modules/omarchy/packages.nix` and update `docs/omarchy-package-inventory.md`. |
| `install/config/`, `install/hardware/`, `install/login/`, `etc/` | **script** | Translate into a `modules/omarchy/*.nix` option. These are never executed. |
| `test/`, `manual/`, `plans/`, `docs/`, `agents/`, `migrations/` | **ignore** | Not shipped, or has no NixOS meaning. |

Two things to watch for specifically, because they are how upstream breaks this port:

- A **new command that manages packages, the bootloader or snapshots** needs a row in
  `pkgs/omarchy/nixos-commands.nix`. Nothing detects this automatically.
- A **command in `nixos-commands.nix` or `pkgs/omarchy/commands/` that upstream deleted or
  renamed** fails the build with a `porting-steps:` message naming the file. That is the
  check working, not a bug — remove the stale entry.

## 3. Re-read the porting steps

Walk `docs/porting-steps.md`. Steps 1–6 verify themselves during the build. Steps 7–10 are
marked **check by hand**; do that now, not after the VM boots.

## 4. Build and smoke test

    nix flake check
    nix build .#omarchy
    nix build .#nixosConfigurations.omarchy-vm.config.system.build.vm
    ./result/bin/run-omarchy-vm-vm

Then the checklist in `CLAUDE.md`. A green `nix flake check` is not a verified desktop: it
cannot see the bar, the menu or the lock screen.

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
