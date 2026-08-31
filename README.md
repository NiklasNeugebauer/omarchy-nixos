# omarchy-nixos

**[Omarchy](https://omarchy.org) on NixOS.** The same desktop, from the same source tree,
declaratively — with atomic updates and a bootable rollback.

Omarchy is DHH's opinionated Linux distribution: Hyprland, a Quickshell desktop, a themed
terminal-first environment, and a large CLI of `omarchy-*` commands. It is built for Arch.
This repo runs it on NixOS by **vendoring upstream rather than forking it** — upstream is a
pinned flake input, consumed as-is, and everything this port does to it is ten documented
steps, six of which fail the build if upstream moves under them.

> **Status: alpha, not verified on real hardware.** `nix flake check` is green and three VM
> checks pass, one of which boots to a live session and screenshots it. What is and is not
> verified is tracked in [`docs/progress.md`](docs/progress.md) — the only place it is
> tracked, so this line cannot go stale. Build it, read it, run it in a VM. Do not put it on
> a machine you need on Monday.

## Contents

- [How it works](#how-it-works)
- [Try it in a VM](#try-it-in-a-vm)
- [Install it](#install-it)
- [Living with it](#living-with-it)
- [What is different from upstream](#what-is-different-from-upstream)
- [Repository layout](#repository-layout)
- [Contributing](#contributing)
- [Credit and licence](#credit-and-licence)

## How it works

Omarchy resolves its entire runtime tree through one variable, `$OMARCHY_PATH`, and already
supports pointing that somewhere other than `/usr/share/omarchy` — that is what
`omarchy dev link` does. This port uses that hook: **the Nix store path is the packaged
location.** Upstream's bash bootstrap, its uwsm session environment, its Hyprland Lua modules
and its Quickshell QML then all agree on where the tree lives, with no patch.

Everything else follows from one split:

| Upstream layer | On Arch | Here |
| --- | --- | --- |
| runtime tree (`bin/ default/ shell/ themes/ config/`) | `omarchy` pacman package | `pkgs/omarchy`, at `$OMARCHY_PATH` |
| `$HOME` defaults | `/etc/skel` + `useradd -m` | home-manager |
| root-side one-shot setup (`install/**`) | ran once in the ISO chroot | `modules/omarchy/*.nix` options |
| `/etc` drop-ins (`etc/**`) | package-owned files | native NixOS options |
| package lists | `pacstrap` | `environment.systemPackages` |
| updates | `omarchy update` → pacman | `nixos-rebuild` from the flake |
| rollback | Limine + Snapper snapshots | NixOS generations |
| reset | `omarchy reset` | reinstall from the flake |

The complete list of what this repo does to upstream is
**[`docs/porting-steps.md`](docs/porting-steps.md)**. It is short on purpose, and it is the
file to read before anything else.

## Try it in a VM

Nothing here touches your system. You need Nix with flakes enabled.

    nix build .#nixosConfigurations.omarchy-vm.config.system.build.vm
    ./result/bin/run-omarchy-vm-vm

That host logs itself in and has no disk encryption; it exists to smoke test changes and is
not an install target.

Two automated checks go further than `nix flake check` can, and leave screenshots to look at:

    nix build .#greeter-screenshots   # boots to the login screen
    nix build .#desktop-screenshots   # logs in, waits for Hyprland and the shell
    ls result/

`.#desktop-screenshots` is also where a missing runtime tool surfaces: it fails if anything in
the session reported a command it could not find. That is the one class of bug the package
build cannot catch, because the tools the vendored commands shell out to live in the system
profile rather than in each command's wrapper.

Both need a graphics-capable VM and a few minutes, which is why they are not in
`nix flake check`.

## Install it

The disk layout is LUKS2 over btrfs subvolumes. You are prompted for the passphrase at format
time and at every boot. **No key material belongs in this repo, and none is in it.**

Read [`hosts/omarchy-laptop/disko.nix`](hosts/omarchy-laptop/disko.nix) first — it will not
install until you replace the placeholder disk path, deliberately.

    # from a NixOS installer ISO, with this repo checked out
    ls -l /dev/disk/by-id/          # find your disk; by-id, never /dev/sdX
    $EDITOR hosts/omarchy-laptop/disko.nix

    sudo nix --experimental-features 'nix-command flakes' \
      run github:nix-community/disko -- --mode disko --flake .#omarchy-laptop
    sudo nixos-install --flake .#omarchy-laptop
    sudo nixos-enter --root /mnt -c 'passwd omarchy'   # required: the greeter rejects an empty password

For a real machine, copy the host directory, drop in
`nixos-generate-config --show-hardware-config`, and add it to `nixosConfigurations`.
[`docs/omarchy-nixos-hardware.md`](docs/omarchy-nixos-hardware.md) maps upstream's per-vendor
scripts to the NixOS option that replaces each one.

## Living with it

    omarchy update             # nix flake update + nixos-rebuild switch
    omarchy snapshot           # list generations
    omarchy snapshot rollback  # boot the previous one

The rest of the `omarchy` CLI is upstream's, unchanged. Commands that manage Arch packages or
the Limine/Snapper boot story exit with a pointer to the NixOS equivalent instead of failing
inside pacman.

Installing software is a configuration edit, not a command: add it to
`environment.systemPackages` (or `omarchy.extraPackages`) and run `omarchy update`.

## What is different from upstream

The full account is [`docs/divergences.md`](docs/divergences.md). The short version:

- **Package management, updates, rollback and reset are replaced, not ported.** Emulating
  pacman on NixOS would turn this repo into a fork.
- **`$HOME` is split in two.** Shipped defaults are store symlinks; files upstream invites you
  to edit — and files an application rewrites itself — are seeded once and then yours.
- **A handful of Basecamp's own applications are not in nixpkgs** and are therefore missing.
  [`docs/omarchy-package-inventory.md`](docs/omarchy-package-inventory.md) says which, and
  what each one costs. The two that change day-to-day use are `tensaku` (the screenshot
  annotator) and `ttfx` (the screensaver's ASCII branding).

## Repository layout

    AGENTS.md                  the rules, and how to make a change or an update
    omarchy-nixos-plan.md      the core idea, non-goals, constraints
    pkgs/omarchy/              the vendored upstream tree, and the commands we replace
    modules/omarchy/           upstream's install/ and etc/ trees, as NixOS options
    modules/disko/             the LUKS2 + btrfs layout
    hosts/                     omarchy-vm (smoke test), omarchy-laptop (generic, encrypted)
    tests/                     three NixOS VM checks
    docs/porting-steps.md      what this repo does to upstream — read this one
    docs/divergences.md        where behaviour differs, and what you notice
    docs/progress.md           what is verified and what is not
    scripts/sync-upstream.sh   bump the upstream pin and classify the diff

## Contributing

Issues and pull requests are welcome, including "this does not work on my machine" — nothing
here has run on hardware other than a VM, so those reports are the most useful thing right now.

Read [`AGENTS.md`](AGENTS.md) first. The rules that matter:

- **Vendor, don't fork.** Never copy an upstream file in when referencing it works.
- **Replace Arch machinery, don't emulate it.** If a change seems to need pacman, log a
  divergence instead.
- **`nix flake check` and `nix build .#desktop-screenshots` before you push.**
- **Don't bump nixpkgs and the omarchy pin in the same commit.**
- **Nothing personal, no secrets** — not a hostname, not a disk ID, not a password hash.

## Credit and licence

The desktop is [basecamp/omarchy](https://github.com/basecamp/omarchy) by David Heinemeier
Hansson and contributors, MIT licensed. All of the design, and nearly all of the code that
runs, is theirs.

This repository is the NixOS packaging around it, MIT licensed — see
[`LICENSE`](LICENSE) and [`NOTICE`](NOTICE). It is an independent port, **not affiliated with,
sponsored by, or endorsed by Basecamp or the Omarchy project.** Please do not take Omarchy
bug reports to them for problems that turn out to be this port's.
