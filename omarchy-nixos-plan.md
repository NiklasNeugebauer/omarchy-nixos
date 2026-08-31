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

Each phase ends with `nix flake check` green and, from phase 3 on, a VM build.

- **Phase 0 — scaffolding.** Flake with pinned inputs (`nixpkgs`, `home-manager`, `disko`,
  `omarchy` as `flake = false`), repo layout, CI, docs skeleton, license/attribution.
- **Phase 1 — the omarchy package.** Vendor the upstream tree into the store: patch shebangs,
  expose `bin/omarchy-*` on `PATH`, keep the tree layout upstream expects. No behaviour
  changes beyond what `docs/porting-steps.md` records.
- **Phase 2 — base system.** `modules/omarchy/system.nix`, `network.nix`, `audio.nix`,
  `printing.nix`: the `etc/**` drop-ins and `install/config/*.sh` translated to options.
  Firewall: deny in, allow out, 22/tcp + 53317 tcp+udp open.
- **Phase 3 — session.** Hyprland (Lua config, 0.56+), UWSM, SDDM with the omarchy theme,
  portals, polkit. VM boots to a session.
- **Phase 4 — the shell.** Quickshell at the version upstream targets; the bar, menu, OSD,
  notifications, lock screen and polkit agent all come from the vendored `shell/` tree.
- **Phase 5 — `$HOME`.** home-manager module rendering `config/**` into `~/.config`, plus the
  bits `omarchy-provision-user` did that stay meaningful declaratively.
- **Phase 6 — packages.** Translate both `.packages` lists; log every entry in
  `docs/omarchy-package-inventory.md` as ported / substituted / dropped.
- **Phase 7 — theming.** `omarchy theme set` works end to end against the vendored themes;
  GTK/Qt/terminal/shell all follow.
- **Phase 8 — disks and hardware.** disko LUKS2 + btrfs subvolumes, generic laptop host.
- **Phase 9 — tests.** `nix flake check`, a NixOS VM test asserting the session comes up, and
  the hardware checklist in `docs/progress.md` run by hand once on hardware.

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
