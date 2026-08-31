# The graphical session: greeter, compositor, session manager, portals and input method.
#
# Upstream ships a `wayland-sessions/omarchy.desktop` that runs
# `uwsm start -g -1 -e -D Hyprland hyprland.desktop`. NixOS builds the same session from
# `programs.hyprland.withUWSM`, so that desktop file is not installed — see
# docs/divergences.md. Everything the session actually reads (env.d, the Hyprland Lua
# tree, the SDDM theme) still comes from the vendored tree.
{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.omarchy;
  omarchyPath = "${cfg.package}/share/omarchy";
in
{
  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };

    # Hyprland 0.56 prefers ~/.config/hypr/hyprland.lua over hyprland.conf, which is what
    # upstream ships; home-manager puts it there. Lua needs to reach the vendored modules,
    # and upstream's bootstrap.lua builds package.path from $OMARCHY_PATH itself.
    programs.uwsm.enable = true;

    environment.etc = {
      # uwsm sources uwsm/env.d/* from every directory in
      # $XDG_CONFIG_HOME:$XDG_CONFIG_DIRS:$XDG_DATA_DIRS. /etc/xdg is on XDG_CONFIG_DIRS,
      # so this drop-in reaches the session while still letting a user override it from
      # ~/.config/uwsm/env.d. Upstream installs the same file to /usr/share/uwsm/env.d.
      "xdg/uwsm/env.d/10-omarchy".source = "${omarchyPath}/default/uwsm/env.d/10-omarchy";

      # xdg-terminal-exec resolves $TERMINAL for the session; upstream's preference list
      # ships in the vendored tree.
      "xdg/xdg-terminal-exec/hyprland-xdg-terminals.list".source =
        "${omarchyPath}/default/xdg-terminal-exec/hyprland-xdg-terminals.list";

      # Upstream's shipped default associations, at the system level so a user's own
      # ~/.config/mimeapps.list still wins.
      "xdg/mimeapps.list".source = "${omarchyPath}/default/applications/mimeapps.list";
    }
    # Sleep hooks upstream installs to /usr/lib/systemd/system-sleep. systemd reads
    # /etc/systemd/system-sleep too, and these are plain scripts with no NixOS equivalent:
    # forcing the iGPU, restoring the keyboard backlight, and unmounting FUSE mounts that
    # would otherwise hang the resume.
    // lib.listToAttrs (
      map
        (name: {
          name = "systemd/system-sleep/${name}";
          value = {
            source = "${omarchyPath}/default/systemd/system-sleep/${name}";
            mode = "0755";
          };
        })
        [
          "force-igpu"
          "keyboard-backlight"
          "unmount-fuse"
        ]
    );

    # fcitx5 needs these in the session before any toolkit initialises, which is earlier
    # than a shell rc runs. From default/environment.d/10-omarchy-fcitx.conf.
    environment.sessionVariables = {
      INPUT_METHOD = "fcitx";
      QT_IM_MODULE = "fcitx";
      XMODIFIERS = "@im=fcitx";
      SDL_IM_MODULE = "fcitx";
    };

    i18n.inputMethod = {
      enable = true;
      type = "fcitx5";
      fcitx5.addons = with pkgs; [
        fcitx5-gtk
        qt6Packages.fcitx5-configtool
      ];
      # The session starts fcitx5 through omarchy-fcitx5.service, which is ordered after
      # graphical-session.target; letting the module autostart it as well would give two.
      fcitx5.waylandFrontend = true;
    };

    services.displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;
        package = pkgs.kdePackages.sddm;
        theme = "omarchy";
        # The theme is a plain QtQuick + SddmComponents theme shipped in the vendored tree
        # and re-exported by the package at share/sddm/themes/omarchy.
        extraPackages = [ cfg.package ];
        # Upstream runs the greeter on Hyprland itself, configured by
        # default/sddm/hyprland.lua. NixOS runs it on the compositor its sddm module
        # supports; the greeter's compositor is not user-visible and overriding it here
        # fights the module's generated config for no gain.
      };

      # NixOS names the uwsm-managed Hyprland session hyprland-uwsm; upstream calls the
      # same thing "Omarchy (Hyprland uwsm)".
      defaultSession = "hyprland-uwsm";

      autoLogin = lib.mkIf cfg.autoLogin {
        enable = true;
        user = cfg.user;
      };
    };

    # Upstream strips pam_gnome_keyring from /etc/pam.d/sddm (install/login/sddm.sh) so a
    # password login does not create an encrypted login keyring that fights the
    # passwordless default keyring. Here the greeter never enables it in the first place;
    # the keyring is unlocked by the login session instead. The keyring itself and polkit
    # are enabled in system.nix. No separate polkit agent is started anywhere: the shell
    # hosts one (Quickshell.Services.Polkit) and a second would race it for the session's
    # agent registration.
    security.pam.services.login.enableGnomeKeyring = true;

    xdg.portal = {
      enable = true;
      # programs.hyprland already adds xdg-desktop-portal-hyprland; GTK covers the
      # file chooser, settings and secret interfaces it does not implement.
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
    };

    # Upstream patches powerprofilesctl's shebang so mise's python does not shadow the
    # system one; the nixpkgs wrapper pins its interpreter already, so that patch has no
    # NixOS equivalent. The daemon itself is enabled in system.nix.
    services.upower.enable = true;
    programs.dconf.enable = true;

    # Nautilus' python extensions and the GTK bookmarks upstream seeds are home-manager's
    # business; thumbnailing for the file manager and the shell's image picker is not.
    services.tumbler.enable = true;

    users.users.${cfg.user}.extraGroups = [
      "video"
      "audio"
      "input"
      "networkmanager"
      "docker"
    ];
  };
}
