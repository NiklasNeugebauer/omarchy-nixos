# Audio and Bluetooth.
#
# The shell's volume OSD and audio panel talk to PipeWire through
# Quickshell.Services.Pipewire, and its Bluetooth panel to bluez over D-Bus, so both daemons
# have to be up before the bar can render those widgets at all.
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
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      # Upstream ships pipewire-jack; the menu's audio tools and some capture paths expect a
      # JACK server to be there.
      jack.enable = true;

      wireplumber = {
        enable = true;

        # From config/wireplumber/wireplumber.conf.d/bluetooth-a2dp-autoconnect.conf.
        #
        # Upstream keeps this in ~/.config because /etc/skel is the only place an Arch
        # package can seed a per-user WirePlumber drop-in. It is not a preference, though —
        # it is device policy about how a bluez card advertises its profiles, and it should
        # hold for every account on the machine and for a fresh user who has no dotfiles
        # yet. So it lives here rather than in home-manager.
        extraConfig."51-bluetooth-a2dp-autoconnect" = {
          "monitor.bluez.rules" = [
            {
              matches = [ { "device.name" = "~bluez_card.*"; } ];
              actions.update-props = {
                "bluez5.auto-connect" = [
                  "a2dp_sink"
                  "a2dp_source"
                ];
              };
            }
          ];
        };
      };
    };

    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General = {
        # The shell's Bluetooth panel shows a battery percentage per device, which bluez only
        # exposes through its experimental battery-provider interface.
        Experimental = true;
      };
    };

    # Upstream's per-model speaker tunings (docs/audio-tuning.md, default/audio/tunings/) are
    # a PipeWire filter-chain matched to the machine at runtime by
    # install/hardware/speaker-tuning.sh and switched on and off with a command. They stay
    # runtime state: the tuning is chosen by DMI match on the live system, and rendering the
    # wrong vendor's graph into the store would be worse than not shipping one. The LV2
    # limiter every tuning ends in comes with the rest of the media tools in packages.nix.
    #
    # pactl is the one audio binary not covered there: the volume helpers call it, and
    # pipewire-pulse provides the protocol but not the client.
    environment.systemPackages = [ pkgs.pulseaudio ];
  };
}
