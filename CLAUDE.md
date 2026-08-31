# CLAUDE.md — omarchy-nixos

This repo ports the complete Omarchy experience (basecamp/omarchy, Arch/Hyprland/Quickshell)
to a NixOS base. Read `omarchy-nixos-plan.md` first; it is the authoritative plan.
`docs/porting-steps.md` is the complete list of what we do to upstream — read that second.

## Prime directives

1. **Vendor, don't fork.** Upstream omarchy is a pinned flake input. Consume its themes, QML,
   Lua defaults, and configs from the vendored tree. Divergence happens only in `patches/` and
   is logged in `docs/divergences.md` with a reason. Never copy upstream files into this repo
   when a symlink/patch to the vendored tree works.
2. **Replace Arch machinery, don't emulate it.** omarchy-update → nixos-rebuild; Snapper/Limine →
   generations; Reset → reinstall from flake; pacman anything → nixpkgs. If a task seems to
   require porting pacman-touching code, stop and log it as a divergence instead.
3. **VM before hardware.** Any change to modules/, home/, or patches/ must pass
   `nixos-rebuild build-vm --flake .#<host>` and a smoke test before being applied with
   `nixos-rebuild switch`. Never run `switch` unprompted.
4. **Everything declarative.** No imperative system changes, no `nix-env -i`, no manual file
   edits outside the repo. If it isn't in the flake, it doesn't exist. The one deliberate
   exception is the seed-if-absent half of `modules/omarchy/home.nix`, which is documented.
5. **Encryption is non-negotiable.** Disk layout is LUKS2+btrfs via disko. Never generate a
   config that weakens or bypasses it. Never print, log, or commit passphrases, LUKS headers,
   or key material.

## Workflow rules

- Work phase by phase per the plan; keep a checklist state in `docs/progress.md`.
- Small commits, one concern each; reference the plan phase in the message.
- When translating packages, update `docs/omarchy-package-inventory.md` (upstream name →
  nixpkgs attr → status: ported / substituted / dropped / unavailable).
- When patching vendored files, prefer `substituteInPlace` / patch files over sed-in-activation.
  Each patch gets a one-line comment saying which FHS assumption it fixes.
- Version skew (Quickshell, Hyprland): prefer building from the upstream project's flake at
  the rev omarchy pins over waiting for nixpkgs. Record the pin and why.
- Nothing personal in this repo: no real hostnames, usernames, disk IDs or client names. It
  is public.

## Upstream sync (maintenance loop)

Trigger: new tag on basecamp/omarchy. Follow `scripts/sync-upstream.md`:
diff upstream → classify (vendored / package / script / ignore) → bump pin → re-read
`docs/porting-steps.md` → build-vm smoke test → propose switch. Produce a short sync report in
the PR/commit body: what changed upstream, what was translated, what was ignored and why.

## Smoke test checklist (VM)

`nix flake check` cannot see any of this. It has to be run by a human, once per release.
The one exception is the greeter: `nix build .#greeter-screenshots` boots a VM to
`graphical.target` and saves a screenshot of it, so that line can be checked without
hardware.

- [ ] boots to Hyprland via UWSM autologin
- [ ] Quickshell bar renders: workspaces, clock, tray, battery, volume
- [ ] Super+Space unified menu opens and launches apps
- [ ] notifications appear; OSD on volume/brightness keys
- [ ] lock screen engages and unlocks
- [ ] polkit prompt appears (e.g. systemctl restart something)
- [ ] theme switch propagates to terminal + shell + GTK
- [ ] firewall: only 22 and 53317 open

## Don'ts

- Don't chase pixel-perfect parity on installer/reset/update UIs — those are replaced by design.
- Don't add channels; flakes only.
- Don't upgrade nixpkgs and the omarchy pin in the same commit.
- Don't disable the firewall, sshd password auth stays off, no secrets in the repo.
