# omarchy-nixos — plan

Port the complete [Omarchy](https://github.com/basecamp/omarchy) desktop (Arch, Hyprland,
Quickshell) onto a NixOS base, declaratively, with upstream vendored rather than forked.

Upstream reference at time of writing: `basecamp/omarchy` `4.0.0.alpha`, rev `b686ed8`.

## The core idea

Omarchy already resolves its whole runtime tree through one variable, `$OMARCHY_PATH`, and
already supports pointing that variable somewhere other than `/usr/share/omarchy` — that is
what `omarchy dev link` does, by writing `/etc/omarchy.conf`. We use that supported hook: the
Nix store path *is* the dev link. Upstream's `default/bash/env-bootstrap`,
`default/uwsm/env.d/10-omarchy`, `default/hypr/paths.lua` and
`Quickshell.env("OMARCHY_PATH")` then all agree, unpatched.

Everything else follows from a simple split:

| Upstream layer | Arch mechanism | NixOS mechanism |
| --- | --- | --- |
| runtime tree (`bin/ default/ shell/ themes/ config/ install/`) | `omarchy` pacman package | `pkgs/omarchy` derivation, `$OMARCHY_PATH` |
| `$HOME` defaults (`config/**`, `.bashrc`, hypr toggles) | `/etc/skel` + `useradd -m` | home-manager |
| root-side one-shot setup (`install/config/*.sh`, `install/hardware/*.sh`) | ran once in chroot | `modules/omarchy/*.nix` options |
| `/etc` drop-ins (`etc/**`) | package-owned files | `environment.etc` / native NixOS options |
| package lists (`install/*.packages`) | pacstrap | `environment.systemPackages` |
| updates | `omarchy update` → pacman | `nixos-rebuild switch --flake` |
| rollback | Limine + Snapper snapshots | NixOS generations |
| reset | `omarchy reset` | reinstall from flake |
| per-user migrations | `migrations/*.sh` | not needed; marked pre-applied |

The mechanical operations that implement this are kept as a short list in
[`docs/porting-steps.md`](docs/porting-steps.md). That list is the thing to re-read and
re-verify on every upstream bump; it is deliberately short and must stay short.

## Phases

The work was organised into ten phases, and `docs/progress.md` carries them with their state.
They are not repeated here: a phase list in two files is a second progress tracker, and the
two disagree the moment one is updated.

## Non-goals

- Pixel parity for the installer, reset and update UIs. They are replaced by design.
- `pacman`/`yay`/AUR emulation. Commands that manage packages are stubbed with a pointer to
  the NixOS equivalent.
- Snapper/Limine snapshot browsing. NixOS generations cover the same need.
- Basecamp's own side applications that are not in nixpkgs are tracked in the inventory and
  packaged only if they are load-bearing for the desktop.

## Constraints

- Vendor, never fork. Divergence lives in `patches/` and is logged in `docs/divergences.md`.
- Never `switch` unprompted; VM build first.
- LUKS2 is not optional, and no key material ever enters the repo.
- nixpkgs bumps and omarchy pin bumps are separate commits.
