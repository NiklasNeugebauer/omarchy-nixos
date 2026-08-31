# omarchy-nixos

The [Omarchy](https://omarchy.org) desktop on a NixOS base. Upstream is vendored, not forked.

Omarchy is DHH's opinionated Linux distribution: Hyprland, a Quickshell desktop, a themed
terminal-first environment, and a large CLI of `omarchy-*` commands. It is built for Arch.
This repo runs the same desktop, from the same source tree, on NixOS — declaratively, with
atomic updates and bootable rollback.

> **Status: alpha.** The system builds and evaluates, and the CLI, packaging and module layer
> are tested in a VM. The desktop itself has not been verified on hardware. Treat it as
> something to read and build, not something to install on a machine you need today.

## How it works

Omarchy resolves its whole runtime tree through one variable, `$OMARCHY_PATH`, and already
supports pointing that somewhere other than `/usr/share/omarchy` — that is what
`omarchy dev link` does. This port uses that hook: **the Nix store path is the packaged
location.** Upstream's bash bootstrap, its uwsm session environment, its Hyprland Lua modules
and its Quickshell QML all agree on where the tree lives, unpatched.

Everything else follows from one split:

| Upstream layer | Arch mechanism | Here |
| --- | --- | --- |
| runtime tree (`bin/ default/ shell/ themes/ config/`) | `omarchy` pacman package | `pkgs/omarchy`, at `$OMARCHY_PATH` |
| `$HOME` defaults | `/etc/skel` + `useradd -m` | home-manager |
| root-side one-shot setup (`install/**`) | ran once in the ISO chroot | `modules/omarchy/*.nix` options |
| `/etc` drop-ins (`etc/**`) | package-owned files | native NixOS options |
| package lists | `pacstrap` | `environment.systemPackages` |
| updates, rollback, reset | pacman, Limine + Snapper | `nixos-rebuild`, generations, reinstall |

The complete list of what this repo does to upstream is
**[`docs/porting-steps.md`](docs/porting-steps.md)** — ten steps, most of which verify
themselves at build time. It is short on purpose, and it is the file to read on every
upstream bump.

## Try it in a VM

Nothing here touches your system.

    nix build .#nixosConfigurations.omarchy-vm.config.system.build.vm
    ./result/bin/run-omarchy-vm-vm

The VM host logs itself in and has no disk encryption. It exists to smoke test changes and is
not an install target.

## Install on a machine

Read [`hosts/omarchy-laptop/disko.nix`](hosts/omarchy-laptop/disko.nix) first — it will not
install until you replace the placeholder disk path, on purpose.

    # from a NixOS installer ISO, with the repo checked out
    sudo nix --experimental-features 'nix-command flakes' \
      run github:nix-community/disko -- --mode disko --flake .#omarchy-laptop
    sudo nixos-install --flake .#omarchy-laptop

The disk layout is LUKS2 over btrfs subvolumes. You are prompted for the passphrase at format
time and at every boot. No key material belongs in this repo, and none is in it.

Then, on the installed system:

    omarchy update          # nix flake update + nixos-rebuild switch
    omarchy snapshot        # list generations
    omarchy snapshot rollback

## Layout

    omarchy-nixos-plan.md      the authoritative plan: phases, decisions, non-goals
    pkgs/omarchy/              the vendored upstream tree, and the commands we replace
    modules/omarchy/           upstream's install/ and etc/ trees, as NixOS options
    modules/disko/             LUKS2 + btrfs layout
    modules/omarchy/home.nix   what /etc/skel used to seed, via home-manager
    hosts/                     omarchy-vm (smoke test), omarchy-laptop (generic, encrypted)
    tests/session.nix          NixOS VM test
    docs/porting-steps.md      what this repo does to upstream — read this one
    docs/divergences.md        where behaviour differs from upstream, and what you notice
    docs/omarchy-package-inventory.md   227 Arch packages → nixpkgs, with a status each
    scripts/sync-upstream.md   the maintenance loop for a new upstream release

## What is different from upstream

Summarised in [`docs/divergences.md`](docs/divergences.md). The short version: package
management, updates, rollback and reset are replaced rather than ported, because emulating
pacman on NixOS would turn this repo into a fork. A handful of Basecamp's own applications are
not in nixpkgs and are therefore missing — [the
inventory](docs/omarchy-package-inventory.md) says which, and what each one costs.

## Contributing

Read `CLAUDE.md` and `omarchy-nixos-plan.md`. The rules that matter:

- Vendor, don't fork. Divergence goes in `patches/` and is logged in `docs/divergences.md`.
- VM build before hardware. `nix flake check` and a VM boot, every time.
- Don't bump nixpkgs and the omarchy pin in the same commit.
- No secrets, no key material, nothing personal — this repo is public.

## Credit and licence

The desktop is [basecamp/omarchy](https://github.com/basecamp/omarchy) by David Heinemeier
Hansson and contributors, MIT licensed. This repository is the NixOS packaging around it and
is MIT licensed too; see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE). It is not affiliated
with or endorsed by Basecamp.
