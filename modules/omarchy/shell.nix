# omarchy-shell: the single Quickshell instance that is the desktop.
#
# The bar, panels, overlays, menu, OSD, lock screen, notification server and polkit agent
# are all plugins inside it, loaded from the vendored shell/ tree. Nothing here reimplements
# any of that — this module only makes sure Quickshell can run it and that nothing else on
# the system competes for the interfaces it claims.
{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.omarchy;
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      quickshell
      # The shell renders theme backgrounds and tray icons in formats Qt does not carry
      # by default (webp, avif, and the rest), listed upstream as qt6-imageformats.
      kdePackages.qtimageformats
      kdePackages.qtsvg
      # QML needs these at runtime for the panels that talk to them directly.
      kdePackages.qtwayland
    ];

    # The shell IS the notification daemon: shell/plugins/notifications/Service.qml claims
    # org.freedesktop.Notifications on the session bus. Do not add dunst, mako or swaync to
    # a host built on this module — a second daemon wins the bus-name race about half the
    # time and then silently swallows every toast.

    # Upstream's shipped user units, from the vendored tree via the package's
    # lib/systemd/user. `asDropin` adds the enablement without replacing the unit body, so
    # an upstream change to an ExecStart or a Condition arrives with the next pin bump
    # instead of being frozen here.
    systemd.packages = [ cfg.package ];

    systemd.user.services =
      lib.mapAttrs
        (_: target: {
          overrideStrategy = "asDropin";
          wantedBy = [ target ];
        })
        {
          # Auto-accept pairing agent, so the bluetooth panel can pair without a prompt of
          # its own. Inert when there is no bluetooth adapter (ConditionPathIsDirectory).
          "bt-agent" = "graphical-session.target";

          # Holds a logind delay inhibitor and locks the session before suspend. The 15s
          # InhibitDelayMaxSec in system.nix is what gives it time to finish.
          "omarchy-sleep-lock" = "graphical-session.target";

          # Announces process crashes. Inert when the user has toggled crash capture off.
          "omarchy-crash-watch" = "graphical-session.target";

          # The input method the session's IM environment variables point at.
          "omarchy-fcitx5" = "graphical-session.target";

          # Re-enables the internal display before the session starts when the toggle that
          # disabled it survived an external monitor going away.
          "omarchy-recover-internal-monitor" = "graphical-session-pre.target";
        };

    # Deliberately not enabled: omarchy-speaker-tuning (needs a per-model tuning installed
    # at runtime first) and omarchy-tailscale-receive (needs tailscale). Both ship in the
    # package and can be enabled per host.

    # The lock screen authenticates through Quickshell.Services.Pam against two PAM
    # services of its own, named in shell/plugins/lock/Service.qml. Upstream writes them
    # from omarchy-apply-lock; here they are declared, so a broken or missing stack shows
    # up at build time rather than as a lock screen that cannot be dismissed.
    security.pam.services = {
      # Password unlock. The default NixOS stack is pam_unix plus the faillock limits set
      # in system.nix, which is what upstream's hand-written stack amounts to.
      omarchy-lock-password = { };

      # Fingerprint unlock. The shell probes this service and falls back to the password
      # path when it is absent, so it is only worth declaring where fprintd is running.
      omarchy-lock-fingerprint = lib.mkIf config.services.fprintd.enable {
        fprintAuth = true;
        unixAuth = false;
      };
    };
  };
}
