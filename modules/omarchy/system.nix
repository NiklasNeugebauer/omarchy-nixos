# Kernel, systemd, boot and security posture.
#
# Upstream ships these as files under `etc/` that pacman drops into place, plus a handful of
# one-shot `install/config/*.sh` scripts that edit files other packages own. Both shapes exist
# because Arch has no other way to state a system-wide default; NixOS does, so the values live
# here and the scripts have no counterpart.
{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.omarchy;

  # The fontconfig rules that go beyond family defaults — Arabic Naskh over Nastaliq, the
  # Urdu exception, and the last-resort family that Chromium's per-character glyph fallback
  # needs. `fonts.fontconfig` only exposes the whole /etc/fonts tree as one symlink, so the
  # vendored file reaches it as a conf package rather than being copied into this repo.
  omarchyFontconfig = pkgs.runCommand "omarchy-fontconfig" { } ''
    install -Dm444 \
      ${cfg.package}/share/omarchy/default/fontconfig/conf.avail/50-omarchy.conf \
      "$out/etc/fonts/conf.d/50-omarchy.conf"
  '';

  # sudo resolves a command name against PATH and matches the result literally, so a grant
  # written against the store path would stop matching on the next rebuild.
  commandDir = "/run/current-system/sw/bin";
in
{
  config = lib.mkIf cfg.enable {
    # Generations are what replaces upstream's Limine + Snapper story: every rebuild leaves
    # the previous system bootable, which is the need snapshots were serving. The limit keeps
    # /boot from filling on a machine that rebuilds often.
    boot.loader.systemd-boot = {
      enable = lib.mkDefault true;
      configurationLimit = lib.mkDefault 20;
      editor = false; # a boot-time kernel command line is a root shell
    };
    boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

    # From etc/sysctl.d/90-omarchy-file-watchers.conf and 99-omarchy-sysctl.conf.
    boot.kernel.sysctl = {
      # Editors and bundlers blow past the 8192 default on a large checkout.
      "fs.inotify.max_user_watches" = 524288;

      # MTU discovery on flaky links, which is where ssh sessions hang.
      "net.ipv4.tcp_mtu_probing" = 1;

      # The reclaim block below is tuned for swap on zram, not for a disk swapfile.
      # Above 100 says evicting an anonymous page beats dropping page cache that would
      # have to be re-read; with compressed RAM that is true.
      "vm.swappiness" = 150;
      # Dentry/inode cache is expensive to rebuild and cannot spill to zram. Not 0: that OOMs.
      "vm.vfs_cache_pressure" = 50;
      # One page per swap-in fault. The default of 8 pays for a seek zram does not have.
      "vm.page-cluster" = 0;
      # Fragmentation raising the watermarks produces reclaim bursts while memory is free.
      "vm.watermark_boost_factor" = 0;
      # Keep ~1.25% free so kswapd reclaims in the background instead of stalling allocations.
      "vm.watermark_scale_factor" = 125;
      # 64M/256M instead of 10%/20% of RAM, which lets gigabytes flush in stalling bursts.
      "vm.dirty_background_bytes" = 67108864;
      "vm.dirty_bytes" = 268435456;
      # With bursts bounded above, the flusher can wake every 15s.
      "vm.dirty_writeback_centisecs" = 1500;
    };

    # Compressed swap in RAM; zstd averages about 3:1. From
    # default/systemd/zram-generator.conf.d/90-omarchy.conf.
    zramSwap = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = 100;
      # Above the pri=0 a disk swapfile would get, so zram fills first.
      priority = 100;
    };

    # zswap in front of swap-on-zram double-compresses every page and breaks zramctl
    # accounting. Upstream clears it with a boot-only tmpfiles write because the Arch kernel
    # turns it on by default; a kernel parameter settles it before any swap device exists,
    # which is the only point at which the setting still matters.
    boot.kernelParams = [ "zswap.enabled=0" ];

    # From etc/modprobe.d/omarchy-usb-autosuspend.conf. Autosuspend wakes badly on enough
    # docks, keyboards and DACs that the power saving is not worth the input drops.
    boot.extraModprobeConfig = ''
      options usbcore autosuspend=-1
    '';

    # From etc/systemd/logind.conf.d/.
    services.logind.settings.Login = {
      # The power button is a hardware key like any other; the session binds it.
      HandlePowerKey = "ignore";
      # omarchy-sleep-lock holds a delay inhibitor so the session locks before suspend.
      # A delay inhibitor is a timer, not a promise — logind suspends when it expires,
      # locked or not — and closing a lid also reconfigures displays, which the shell waits
      # out before it can secure. A healthy lock still releases in well under a second.
      InhibitDelayMaxSec = "15s";
    };

    # From etc/systemd/oomd.conf.d/10-omarchy.conf. systemd-oomd keys on PSI stall time
    # rather than free pages, so it acts while the machine is still thrashing instead of
    # after an allocation has already failed. 50% of a window spent stalled, held for 20s,
    # means the desktop is unusable and losing one app is the cheaper outcome.
    systemd.oomd = {
      enable = true;
      settings.OOM = {
        DefaultMemoryPressureDurationSec = "20s";
        DefaultMemoryPressureLimit = "50%";
      };
      # Deliberately not the whole user slice. Hyprland runs in session.slice; marking only
      # app.slice (below) keeps the compositor structurally ineligible, so oomd takes the
      # browser or terminal that caused the pressure and the session survives to report it.
      enableUserSlices = false;
      enableRootSlice = false;
      enableSystemSlice = false;
    };

    # From default/systemd/user/app.slice.d/10-oomd.conf. Everything launched through
    # uwsm-app lands in app.slice, which makes it exactly the set of processes that may be
    # killed. Swap kill is the backstop for the slower shape of the same problem.
    systemd.user.slices."app".sliceConfig = {
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMSwap = "kill";
    };

    # From etc/systemd/system.conf.d/, user.conf.d/ and the user@.service drop-in. A desktop
    # that is being shut down has nothing worth waiting 90s for, and the file-descriptor
    # ceiling is raised for the same reason the inotify limit is.
    systemd.settings.Manager = {
      DefaultTimeoutStopSec = "5s";
      DefaultLimitNOFILE = "65536:524288";
    };
    systemd.user.settings.Manager = {
      DefaultTimeoutStopSec = "5s";
      DefaultLimitNOFILE = "65536:524288";
    };
    systemd.services."user@" = {
      # A drop-in, never a replacement: user@.service belongs to systemd itself.
      overrideStrategy = "asDropin";
      serviceConfig.TimeoutStopSec = "5s";
    };

    # From install/config/locate.sh. btrfs subvolume mounts such as /home look like bind
    # mounts, so pruning them would drop /home out of the index entirely. The snapshot
    # subvolume is pruned for the opposite reason: indexing it would duplicate every
    # snapshotted path in the results.
    services.locate = {
      enable = true;
      pruneBindMounts = false;
      prunePaths = lib.mkAfter [ "/.snapshots" ];
    };
    # From etc/systemd/system/plocate-updatedb.service.d/ac-only.conf: a full-disk walk is
    # not something to spend battery on.
    systemd.services.update-locatedb.unitConfig.ConditionACPower = true;

    # From install/config/ssh-keepalive.sh. Without keepalives ssh does not notice a dead
    # link until TCP gives up, which can be hours of sitting on a hung terminal with remote
    # terminal modes still applied. ~/.ssh/config is read first, so per-host overrides win.
    programs.ssh.extraConfig = ''
      Host *
        ServerAliveInterval 15
        ServerAliveCountMax 3
        ConnectTimeout 10
    '';

    # Upstream raises pam_faillock's lockout from Arch's 3 attempts to 10. NixOS' pam stack
    # uses pam_faillock only to log failures, never to lock an account out, so there is no
    # lockout to raise — the file is written for an admin who adds faillock to the stack, and
    # the setting that actually governs retries on this system is sudo's passwd_tries below.
    environment.etc."security/faillock.conf".text = ''
      deny = 10
    '';

    security.sudo = {
      enable = true;
      # From etc/sudoers.d/omarchy-passwd-tries.
      extraConfig = ''
        Defaults passwd_tries=10
      '';
      extraRules = [
        {
          groups = [ "wheel" ];
          commands = [
            # From etc/sudoers.d/omarchy-dns. Switching between stock resolvers is a
            # one-click toggle in the network panel, with no terminal to type a password
            # into. "Custom" is deliberately absent: it points the machine at servers the
            # caller supplies, and it already runs somewhere that can ask.
            {
              command = "${commandDir}/omarchy-dns Cloudflare";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${commandDir}/omarchy-dns Google";
              options = [ "NOPASSWD" ];
            }
            {
              command = "${commandDir}/omarchy-dns DHCP";
              options = [ "NOPASSWD" ];
            }
            # From etc/sudoers.d/omarchy-theme-browser. Theme switching repaints the browser
            # accent on every switch and is a menu action with no terminal. The argument is
            # spelled out as six hex digits rather than a wildcard, and sudoers matches
            # arguments exactly, so the grant cannot be stretched past one colour.
            {
              command = "${commandDir}/omarchy-theme-set-browser-policy [0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]";
              options = [ "NOPASSWD" ];
            }
            # From etc/sudoers.d/omarchy-tzupdate. Upstream anchors its pattern with ^ and $,
            # which sudoers does not implement, but its character classes are ordinary
            # sudoers globs and are kept. A bare * would not be equivalent: sudoers matches
            # the arguments as one concatenated string, so * spans argument boundaries and
            # would grant timedatectl set-timezone followed by anything at all.
            {
              command = "${commandDir}/timedatectl set-timezone [A-Za-z0-9_+]*";
              options = [ "NOPASSWD" ];
            }
          ];
        }
      ];
    };

    security.polkit.enable = true;
    security.rtkit.enable = true;

    # The keyring backs the browser's and the shell's secret storage. Unlocked by the login
    # password through pam, which is why it is named on the greeter's pam service too.
    services.gnome.gnome-keyring.enable = true;
    security.pam.services.sddm.enableGnomeKeyring = lib.mkDefault true;

    # udisks + gvfs give the file manager and the shell's disk panel removable media.
    services.udisks2.enable = true;
    services.gvfs.enable = true;

    # Battery-aware CPU governor switching; the shell's power menu drives it.
    services.power-profiles-daemon.enable = true;

    # Upstream's per-vendor microcode and firmware handling lives in install/hardware/;
    # on NixOS the host's hardware config asks for the CPU's microcode and this covers the
    # rest of what a laptop needs at runtime.
    hardware.enableRedistributableFirmware = true;

    fonts = {
      packages = [
        cfg.package # the branded omarchy.ttf used by the bar's glyphs
        pkgs.liberation_ttf # what the fontconfig rules alias sans-serif and serif to
        # The unrestricted noto-fonts covers every Noto variant, which is what the Arabic
        # and Urdu rules in the fontconfig file above need to resolve.
        pkgs.noto-fonts
        pkgs.noto-fonts-cjk-sans
        pkgs.noto-fonts-cjk-serif
        pkgs.noto-fonts-color-emoji
        pkgs.nerd-fonts.jetbrains-mono
        pkgs.font-awesome
        pkgs.ia-writer-duospace
      ];

      # From default/fontconfig/conf.avail/50-omarchy.conf.
      fontconfig = {
        defaultFonts = {
          sansSerif = [ "Liberation Sans" ];
          serif = [ "Liberation Serif" ];
          monospace = [ "JetBrainsMono Nerd Font" ];
          emoji = [ "Noto Color Emoji" ];
        };
        confPackages = [ omarchyFontconfig ];
      };
    };

    # From etc/docker/daemon.json. The fixed bridge address is what the resolved stub
    # listener in network.nix and the firewall's DNS allowance are both written against.
    virtualisation.docker = {
      enable = true;
      daemon.settings = {
        log-driver = "json-file";
        log-opts = {
          max-size = "10m";
          max-file = "5";
        };
        dns = [ "172.17.0.1" ];
        bip = "172.17.0.1/16";
      };
      # Socket activation only. Upstream reaches the same end by telling docker.service not
      # to take default dependencies, because on Arch it is enabled at boot; here the daemon
      # simply is not in the boot path until something opens the socket.
      enableOnBoot = false;
      autoPrune.enable = true;
    };

    # Deliberately not adding anyone to the docker group. Membership is equivalent to
    # passwordless root — any process in it can bind-mount / into a container and rewrite the
    # host — so one compromised process running as the user must not be able to escalate
    # silently. The TUI reaches the daemon through a polkit prompt and the CLI runs under sudo.
    users.groups.docker = { };

    nix = {
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        auto-optimise-store = true;
        # Anyone who can rebuild the system can already run arbitrary code as root.
        trusted-users = [
          "root"
          "@wheel"
        ];
      };
      gc = {
        automatic = true;
        dates = "weekly";
        # Keep a fortnight of generations to roll back into.
        options = "--delete-older-than 14d";
      };
    };
  };
}
