# Upstream paths that something outside this derivation names.
#
# The modules reference files inside the vendored tree by path — `environment.etc` sources,
# home-manager `source =` entries, the SDDM and Plymouth theme links. Every one of those is a
# bare `ln -s` somewhere downstream, in NixOS' etc module and in home-manager's file module
# alike, with no check that the target exists. So an upstream release that renames one of
# these produces a dangling symlink, a green build, and a feature that silently stops
# working: no input method, no default applications, a greeter that falls back to stock SDDM.
#
# Asserting them here turns each of those into a build error naming the file.
#
# **Add an entry whenever a module starts referencing a new upstream path.** That is the one
# manual step; nothing detects it, because this derivation cannot see the modules.
[
  # Session and system drop-ins — modules/omarchy/session.nix
  "default/uwsm/env.d/10-omarchy"
  "default/environment.d/10-omarchy-fcitx.conf"
  "default/xdg-terminal-exec/hyprland-xdg-terminals.list"
  "default/applications/mimeapps.list"
  "default/systemd/system-sleep/force-igpu"
  "default/systemd/system-sleep/keyboard-backlight"
  "default/systemd/system-sleep/unmount-fuse"
  "default/fontconfig/conf.avail/50-omarchy.conf"

  # Shipped user units — modules/omarchy/shell.nix, via this package's lib/systemd/user
  "default/systemd/user"

  # $HOME — modules/omarchy/home.nix
  "default/bash/env-bootstrap"
  "default/bash/rc"
  "default/xcompose"
  "default/hypr/toggles"
  "default/tensaku/state.toml"
  "default/nautilus-python/extensions"
  "default/agents/skills/omarchy"
  "default/agents/skills/diagnose-crash"
  "logo.txt"

  # Re-exported at NixOS paths by this derivation's installPhase
  "default/sddm/omarchy"
  "default/sddm/hyprland.lua"
  "default/plymouth"
  "default/fonts/omarchy/omarchy.ttf"

  # Named by the reimplemented commands and by the initial theme activation
  "bin/omarchy-theme-set"
  "bin/omarchy-theme-set-templates"
  "version"
]
