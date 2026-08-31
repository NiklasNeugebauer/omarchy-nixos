# Divergences

Where omarchy-nixos does not do what upstream Omarchy does, and why. Each entry says what
upstream does, what happens here instead, and what a user actually notices.

`docs/porting-steps.md` covers the mechanical translation. This file is for the places where
the *behaviour* differs — the ones a bug report will land on.

## Replaced by design

These are the point of the port, not regressions.

| Upstream | Here | What a user notices |
| --- | --- | --- |
| `omarchy update` → pacman transaction, snapshot, migrations | `nixos-rebuild` from the flake | Updates are atomic and the old system stays bootable. No snapshot step, no migration step. |
| Limine + Snapper snapshot browsing | NixOS generations, `omarchy snapshot` lists them | Rollback is a boot menu entry, not a btrfs snapshot restore. |
| `omarchy reset` / factory reset | Reinstall from the flake | The flake *is* the factory image. |
| `omarchy pkg add/install/remove`, the AUR | `environment.systemPackages`, then `omarchy update` | Installing software is a config edit, not a command. Every `omarchy install …` menu entry therefore fails with a pointer. |
| per-user `migrations/*.sh` | none | Nothing drifts between a flake and the system it built, so there is nothing to migrate. `omarchy-migrate` reports that and exits. |
| `omarchy dev link` / `unlink` | override `omarchy.package` | `$OMARCHY_PATH` is decided at build time; `/etc/omarchy.conf` is deliberately never written, because upstream reads its presence as a dev link and a stale one would outrank the built system. |
| `/etc/skel` seeding at `useradd -m` | home-manager | See "Seeded, not declared" below. |
| `ufw` + `ufw-docker` | `networking.firewall` on nftables | Same policy. `ufw` is not installed; `omarchy` has no command that drives it directly. |
| `mkinitcpio` hooks, `dkms`, `kernel-modules-hook` | `boot.initrd`, `boot.extraModulePackages` | Kernel modules are built with the kernel, declaratively. |

## Seeded, not declared

The one deliberately non-declarative corner. Upstream's `config/` tree has two halves, and its
own documentation says so: files it ships as defaults, and files it tells the user to edit
("Put your personal overrides in these files. They're loaded after Omarchy's defaults so
package updates can improve the defaults without rewriting your `~/.config/hypr` files.").

- **Shipped defaults** are store symlinks. They are always the shipped default, which makes
  `omarchy-reinstall-configs` redundant rather than broken.
- **Seeded files** are copied once if absent and then never touched. Two things land here: a
  file upstream invites the user to edit, and a file the *application* rewrites — an Electron
  profile, or a TUI that saves settings on exit. A store symlink breaks both, silently in the
  second case. The list is `seeded` in `modules/omarchy/home.nix`; it is not repeated here,
  because a copy of it in prose would drift out of date without anything noticing.

The consequence is real and worth stating plainly: after an upstream bump, an improvement to
a *user-owned* default does not reach a user who already has that file. That is exactly the
`/etc/skel` contract upstream has, so the behaviour matches — but on a system that is
otherwise fully declarative it is a surprise, so it is written down here.

## Runtime tools live in the system profile

Porting step 7 puts the tools the vendored `omarchy-*` commands shell out to in
`environment.systemPackages` rather than wrapping each command, because wrapping would break
the CLI router's own sibling discovery. The consequence is that a tool nobody
listed fails at runtime, not at build time — and the places that bit are worth naming, because
they are the shape of the next one:

- **systemd user units** get a PATH from NixOS holding only coreutils, findutils, grep, sed
  and systemd. The shipped units' scripts call ordinary tools by name, so they are given the
  system profile explicitly; without it `omarchy-sleep-lock.service` restart-loops on a
  missing `dbus-monitor` and the session never locks before suspend.
- **home-manager activation** has a PATH of its own. The initial `omarchy theme set` runs
  there, and without a PATH it half-succeeds: theme name and background written, none of the
  terminal, GTK or shell colour files rendered.

`nix build .#desktop-screenshots` fails if anything in a live session reported a command it
could not find, which is the check for this.

## Session

- **Session name.** Upstream ships `wayland-sessions/omarchy.desktop` ("Omarchy (Hyprland
  uwsm)"). Here the session is NixOS' `hyprland-uwsm.desktop`, built by
  `programs.hyprland.withUWSM`. Identical mechanics; the greeter shows a different label.
- **Greeter compositor.** Upstream runs the SDDM greeter on Hyprland with
  `default/sddm/hyprland.lua`. Here it runs on whatever NixOS' SDDM module uses. The omarchy
  SDDM *theme* is unchanged, which is the part anyone sees.
- **fzf and bash-completion.** Upstream's `default/bash/init` and `default/bash/shell`
  source their integrations from `/usr/share`, which does not exist here. Both guard with a
  `-f` test and no-op silently; home-manager wires up the same integrations from the store.
- **`faillock` lockout.** Upstream raises the failed-attempt limit from 3 to 10 by editing
  `/etc/security/faillock.conf` and the PAM stacks. NixOS' PAM stack uses `pam_faillock`
  only to log failures, never as a lockout enforcer, so there is no 3-attempt lockout to
  raise. `sudo`'s `passwd_tries` is ported, which is what actually governs retries here.

## Moved between layers

Same behaviour, different owner — worth knowing because the file you would edit is not the
file upstream tells you to edit.

- **WirePlumber's Bluetooth A2DP autoconnect** is a system-level drop-in here, not
  `~/.config/wireplumber/`. It is device policy about how a bluez card advertises profiles,
  so it should hold for a fresh user with no dotfiles; upstream only put it in `$HOME`
  because `/etc/skel` was the only seeding mechanism Arch gave it.
- **cups-browsed hardening** comes from `systemd.services.cups-browsed.serviceConfig` rather
  than a `/etc/systemd/system/…d/` drop-in, and uses `DynamicUser` in place of upstream's
  `sysusers.d` account. NixOS' own cups-browsed unit sets an `ExecStart` and nothing else, so
  without this the daemon would run unconfined as root — the drop-in is not optional here.
- **mDNS is not reachable from the network.** `services.avahi.openFirewall` is off, because
  it would open UDP 5353 and the stated policy is 22 and 53317 only. Avahi still browses
  outbound, so finding a printer works; being found does not. A host that needs to answer
  mDNS queries opens the port itself.

## Not available

Basecamp ships several of its own applications through the AUR. Where nixpkgs has no
package, the command is absent and its menu entry fails. The full list, with what each one
costs, is in `docs/omarchy-package-inventory.md` under *unavailable*; the ones that change
day-to-day use are:

- **`tensaku`** — the default screenshot annotator. Capture still works and honours
  `OMARCHY_SCREENSHOT_EDITOR`, but "edit" on a screenshot and Ctrl+E in `imv` are dead.
- **`ttfx`** — renders the animated ASCII branding for `omarchy screensaver`. The screensaver
  blanks instead. Locking is unaffected.

## Deliberately not enabled

Shipped in the package, off by default, because each needs runtime state that does not exist
on a fresh install: `omarchy-speaker-tuning.service` (needs a per-model tuning rendered
first) and `omarchy-tailscale-receive.service` (needs tailscale). Enable per host.

Upstream's per-model speaker tunings stay a runtime feature on purpose. They are measured
per laptop model and applied by matching the live PipeWire sink; making that declarative
would mean encoding a hardware match table that upstream already maintains better.
