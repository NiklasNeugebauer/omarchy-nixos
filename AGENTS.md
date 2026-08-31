# AGENTS.md — omarchy-nixos

Ports the Omarchy desktop (basecamp/omarchy, Arch/Hyprland/Quickshell) to NixOS. Upstream is
a pinned flake input, vendored and never forked.

**This file holds only what does not change.** Anything that tracks state or detail lives in
one place and is linked from here — do not restate it, or the two copies will disagree:

| Question | File |
| --- | --- |
| What is the plan, and what is out of scope? | `omarchy-nixos-plan.md` |
| What exactly do we do to upstream? | `docs/porting-steps.md` |
| Where does behaviour differ from upstream? | `docs/divergences.md` |
| What is done, what is unverified? | `docs/progress.md` |
| Which nixpkgs attr replaces an Arch package? | `docs/omarchy-package-inventory.md` |
| Which NixOS option replaces a hardware script? | `docs/omarchy-nixos-hardware.md` |
| How are releases tracked and tagged? | `docs/releases.md` |

Read `omarchy-nixos-plan.md` and `docs/porting-steps.md` before changing anything.

Each file above owns one kind of fact and no other file repeats it. `docs/progress.md` is the
only file with a checkbox or a "not yet" in it; `docs/porting-steps.md` is the only place a
count of upstream files belongs; a list that exists in code — the `seeded` set, the command
tables, the firewall ports — is linked, never transcribed. When you find yourself writing a
fact that already exists somewhere, link it instead.

## Rules

1. **Vendor, don't fork.** Consume upstream's themes, QML, Lua and configs from the vendored
   tree. Never copy an upstream file into this repo when referencing it works. Divergence goes
   in `patches/` and is logged in `docs/divergences.md` with a reason.
2. **Replace Arch machinery, don't emulate it.** pacman, the AUR, Limine and Snapper have no
   port. If a task seems to need one, log a divergence instead.
3. **Declarative, with one documented exception** — the seed-if-absent half of
   `modules/omarchy/home.nix`. No imperative system changes, no `nix-env`, no channels.
4. **Encryption is non-negotiable.** LUKS2+btrfs via disko. Never weaken it. Never print, log
   or commit a passphrase, header or key.
5. **Public repo.** No real hostnames, usernames, disk IDs, emails or client names. No secrets.
6. **Verify before switching.** Never run `nixos-rebuild switch` unprompted.

## Making a change

    nix flake check                        # both hosts, the package, the VM test
    nix build .#desktop-screenshots        # boots a VM to a live session; look at result/

`nix flake check` cannot see the desktop. `.#greeter-screenshots` and `.#desktop-screenshots`
boot real VMs and save screenshots; the latter also fails if anything in the session called a
command that is not installed — the one bug class the package build cannot catch.

What neither can see is in `docs/progress.md` under the hardware checklist. Update that file
in the same commit as the work.

Small commits, one concern each. When a change touches an upstream package name, update
`docs/omarchy-package-inventory.md` in the same commit.

## Updating

Two kinds, never in the same commit.

**Upstream omarchy** — the pin is a release tag, so this is a deliberate move between
releases and never a side effect of updating something else.
`.github/workflows/upstream.yml` notices a new release daily and opens the PR that does it;
`docs/releases.md` is the whole story. To do it by hand:

    ./scripts/sync-upstream.sh    # bumps the pin, then classifies the diff for you

It prints each changed path as *vendored* (ships as-is, no action), *package* (translate into
`modules/omarchy/packages.nix` and the inventory), *script* (translate into a
`modules/omarchy/*.nix` option — `install/` and `etc/` are never executed), or *ignore*. It
also names any stubbed or reimplemented command upstream has since renamed.

Then, in order: re-read `docs/porting-steps.md` — six of its ten steps fail the build on
drift, the rest are marked **check by hand** and are where a bump actually goes wrong — then
`nix flake check`, then `nix build .#desktop-screenshots`, then the hardware checklist if the
session changed. `scripts/sync-upstream.md` has the long form.

**nixpkgs** — its own commit:

    nix flake update nixpkgs home-manager disko

Same verification. A nixpkgs bump breaks this port through renamed attributes and removed
options far more often than upstream does, so read the eval warnings instead of scrolling past
them.

Either way, put a three-line report in the commit body: what changed upstream, what was
translated, what was ignored and why. If a porting step had to change, say so — that list *is*
the port, and a change to it is the most important thing in the diff.
