# The porting steps

Everything omarchy-nixos does to upstream Omarchy, in ten steps. This is the whole port: if
a step is not here, we did not do it.

Read this list on **every** upstream bump. Most steps verify themselves at build time and
will fail loudly if upstream moves under them; the ones that cannot are marked
**check by hand**. Keep the list short — a step that grows into a paragraph is a sign the
port has started emulating Arch instead of replacing it.

Nothing here is a fork. Upstream's files are used as shipped except where a step says
otherwise, and each step names the FHS or pacman assumption it fixes.

---

### 1. Vendor the tree at `$OMARCHY_PATH`

`pkgs/omarchy` copies upstream's `bin/ default/ shell/ themes/ config/ applications/
install/ migrations/` and `version` into `$out/share/omarchy`, the layout upstream expects
to find at `$OMARCHY_PATH`. `test/ manual/ plans/ agents/ docs/` are left out — no upstream
package ships them either.

*Verified by:* the build fails if a directory upstream renames goes missing.

### 2. Stub the Arch-machinery commands

The commands whose entire job is pacman, the AUR, Limine or Snapper are replaced by a stub
that exits non-zero and names the NixOS equivalent. The table is
`pkgs/omarchy/nixos-commands.nix`, one line per command. They stay present rather than being
deleted, because the CLI router discovers commands by scanning its own directory and several
commands call each other.

*Verified by:* the build fails if a listed command no longer exists upstream.

### 3. Reimplement the handful of commands that matter

`pkgs/omarchy/commands/` holds real replacements, not stubs: `omarchy-update` (rebuild and
switch), `omarchy-update-available` (compare the flake lock), `omarchy-pkg-present` /
`omarchy-pkg-missing` (answer "can I run this" instead of querying pacman — every
`omarchy install …` command and a lot of conditionals depend on their exit codes),
`omarchy-version`, `omarchy-snapshot` (list and roll back generations) and `omarchy-migrate`
(nothing to migrate).

*Verified by:* the build fails if a replaced command no longer exists upstream.

### 4. Rewrite the shebangs

Upstream is uniformly `#!/bin/bash` (439 files) and `#!/usr/bin/python3` (5). Neither path
exists on NixOS. Every occurrence is rewritten, not only line 1 — two commands write helper
scripts from heredocs, and the shipped hooks, `.sample` files and `system-sleep` scripts are
not executable, so nixpkgs' own `patchShebangs` does not reach them.

*Verified by:* the build fails if any `#!/bin/bash` or `#!/usr/bin/python3` survives.

### 5. Rewrite `/usr/share/omarchy` to the store path

Upstream uses that literal both as the fallback for `$OMARCHY_PATH` and as the value its
"am I running from a dev checkout?" comparisons test against. Pointing it at the derivation
makes the store path *the packaged location*, so those comparisons stay true and nothing at
runtime has to be told where the tree lives. `/etc/omarchy.conf` is therefore never written;
the module explicitly disables it, because upstream reads its presence as a dev link and a
stale one would outrank the built system.

*Verified by:* the build fails if the literal survives anywhere outside markdown.

### 6. Rewrite `/usr/bin/` to the system profile

The shipped systemd user units name their `ExecStart` absolutely, as systemd requires, and a
few commands call tools by absolute path. `/run/current-system/sw/bin` is the honest
equivalent: it holds exactly what the NixOS configuration installed, and it follows the
booted generation, so a unit body stays correct across rebuilds.

*Verified by:* the build fails if `/usr/bin/` survives anywhere outside markdown.

### 7. Put the commands on `PATH`

`$out/bin/omarchy-*` are symlinks into `$out/share/omarchy/bin`, not wrappers, so the CLI
router's own `dirname "$BASH_SOURCE"` sibling discovery keeps working. The runtime tools the
commands shell out to are installed system-wide by `modules/omarchy/packages.nix` — the way
a distribution provides them — rather than wrapped per command.

**Check by hand:** a new upstream command that calls a tool nothing else installs will fail
at runtime, not at build time. `docs/omarchy-package-inventory.md` is where that gets fixed.

### 8. Translate the root-side setup into module options

`install/config/*.sh`, `install/hardware/*.sh`, `install/login/*.sh` and the `etc/**`
drop-ins are **never executed**. They are expressed as NixOS options under
`modules/omarchy/`, one module per area, with each value's upstream source file named in a
comment so the next bump can be diffed against it.

**Check by hand:** diff `install/` and `etc/` on every bump. A new tuning or service there
is a module edit here.

### 9. Replace `/etc/skel` with home-manager

Upstream seeds `$HOME` once at `useradd -m` and resyncs with `omarchy-reinstall-configs`.
`modules/omarchy/home.nix` splits that tree the way upstream's own documentation does:
shipped defaults become store symlinks (permanently the shipped default, so the resync
command has nothing to do), and the files upstream invites the user to own — the Hyprland
override modules, menu and hook extensions, runtime toggles, git identity — are seeded once
if absent. That last part is the one deliberately non-declarative corner of the port; it is
recorded in `docs/divergences.md`.

**Check by hand:** a new directory under upstream's `config/` is picked up automatically; a
new *user-owned* one has to be added to the `userOwned` list in `home.nix`.

### 10. Replace the update, rollback and reset story

`omarchy update` becomes `nixos-rebuild`; Limine plus Snapper snapshots become NixOS
generations; `omarchy reset` becomes a reinstall from the flake; migrations do not exist,
because nothing drifts between a flake and the system it built. This is a replacement, not a
port: none of the Arch machinery has an equivalent here, and pretending otherwise is how
this repo would turn into a fork.

*Verified by:* nothing. It is a design decision, restated here so it does not get quietly
re-litigated during a bump.
