# LUKS2 + btrfs disk layout, as a parameterised module.
#
# Upstream's installer partitions interactively and then hands the machine to Limine and
# Snapper. Neither has a port here: NixOS generations replace snapshot browsing, so the
# subvolume layout only has to keep the volatile trees separable, not feed a snapshot
# rotation policy.
#
# NO KEY MATERIAL MAY EVER ENTER THIS REPOSITORY. No `keyFile`, no `passwordFile`, no
# passphrase, no recovery key, not even as an example or a placeholder. The passphrase is
# typed once into `disko --mode disko` at install time and once into the initrd at every
# boot. A repository that is public and a repository that holds a key are two things that
# cannot be the same repository.
{
  lib,
  config,
  ...
}:

let
  cfg = config.omarchy.disk;
in
{
  options.omarchy.disk = {
    enable = lib.mkEnableOption "the encrypted btrfs disk layout";

    device = lib.mkOption {
      type = lib.types.str;
      description = ''
        The whole disk to wipe and repartition, as a `/dev/disk/by-id/...` path.

        `/dev/sdX` and `/dev/nvmeXnY` are assigned in device-discovery order, so they move
        between boots and between kernels once a second disk, a USB stick or an SD card is
        present. Naming the wrong one here does not fail — it silently destroys the wrong
        disk. A by-id path is derived from the drive's own model and serial, so it names one
        physical drive and nothing else.
      '';
      example = "/dev/disk/by-id/nvme-eui.0123456789abcdef";
    };

    swapSize = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Size of the on-disk swap file, or `null` for none.

        Ordinary swap is zram, configured with the rest of the system and sized against RAM;
        it is faster than any disk and needs no partition. This option exists only for
        hibernation, which has to write the whole of RAM somewhere that survives power loss.
        Set it to at least the size of physical RAM if hibernation must work, and leave it
        `null` otherwise — an unused swap file costs the space whether it is touched or not.

        This option alone does not make hibernation work. It creates the swap file; the
        host's configuration still has to name it with `boot.resumeDevice` and pass the
        file's physical `resume_offset` as a kernel parameter, neither of which can be known
        until the file exists on the installed machine.
      '';
      example = "32G";
    };

    espSize = lib.mkOption {
      type = lib.types.str;
      default = "1G";
      description = ''
        Size of the EFI system partition.

        The conventional 512M is sized for a distribution that keeps one kernel. Every NixOS
        generation kept in the bootloader menu pins its own kernel and initrd, and an initrd
        carrying firmware and a full hardware set runs to a few hundred megabytes, so 512M
        starts failing rebuilds after a handful of generations — and it fails during the
        bootloader install step, when the new system is already half in place. 1G is cheap
        insurance and cannot be resized later without moving every partition after it.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    disko.devices.disk.main = {
      type = "disk";
      inherit (cfg) device;
      content = {
        type = "gpt";
        partitions = {
          # Ordered first so the ESP lands at the start of the disk, where every firmware
          # implementation is known to look for it.
          ESP = {
            priority = 1;
            name = "ESP";
            size = cfg.espSize;
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              # vfat has no ownership bits, so without an explicit umask /boot is
              # world-readable. The initrds there describe the machine's hardware and the
              # unlock path; there is no reason for a normal user to read them.
              mountOptions = [ "umask=0077" ];
            };
          };

          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              settings = {
                # TRADEOFF, decide before you install: with discards on, the SSD learns
                # which blocks are unused and can garbage-collect them, which keeps write
                # performance and endurance where the drive's specification claims they are.
                # The cost is that the pattern of allocated blocks is visible to anyone who
                # can read the raw device — how full the disk is, roughly where the data
                # sits, and that it changed since they last looked. It does not expose file
                # contents. Set this to false if an attacker with repeated physical access
                # to the powered-off machine is in your threat model; leave it true if the
                # threat is a lost or stolen laptop.
                allowDiscards = true;
              };
              # cryptsetup's own defaults already land close to this, but a default is a
              # thing that changes under you between releases. The header is written once
              # and lives for the life of the disk, so it is written from explicit values.
              extraFormatArgs = [
                "--type luks2"
                "--cipher aes-xts-plain64"
                "--key-size 512"
                "--hash sha512"
                # Memory-hard KDF: the point is that a brute-force rig cannot trade RAM for
                # parallelism. 512 MiB has to be available to unlock, and the initrd unlocks
                # before most of the system exists, so this is also a floor on usable RAM.
                # Raising it strengthens the passphrase and raises that floor with it.
                "--pbkdf argon2id"
                "--pbkdf-memory 524288"
                "--pbkdf-parallel 4"
                # Four seconds of work per attempt, paid once per boot by you and once per
                # guess by an attacker.
                "--iter-time 4000"
                # The LUKS encryption sector size, not the drive's. 4096 matches the
                # underlying page size on current NVMe, so one logical write is one
                # physical write rather than a read-modify-write. cryptsetup refuses a
                # device whose size is not a multiple of it, so an older 512-byte-only
                # drive needs this line dropped.
                "--sector-size 4096"
              ];
              content = {
                type = "btrfs";
                # -f so re-running the installer over a previous attempt is not a puzzle.
                extraArgs = [
                  "-f"
                  "-L"
                  "omarchy"
                ];
                # Flat subvolume names, all at the top level, rather than nested paths that
                # mirror the mountpoints: a subvolume can only be created inside a directory
                # that already exists, and at format time nothing exists yet. The mountpoint
                # is what matters to the running system, and it is set independently.
                subvolumes = {
                  "@root" = {
                    mountpoint = "/";
                    # noatime on / as well, not just on the data subvolumes. The usual
                    # reason to keep atime is age-based cleanup, and systemd-tmpfiles falls
                    # back to mtime and ctime when atime is frozen, so /var/tmp is still
                    # collected. Nothing else on a NixOS root reads atime, and every read
                    # would otherwise cost a metadata write.
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };

                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };

                  "@nix" = {
                    mountpoint = "/nix";
                    # Deliberately nothing beyond compression here. The store is the one
                    # tree that benefits most from copy-on-write — every rebuild shares
                    # unchanged files with the generations before it — so nodatacow, which
                    # people reach for on database and VM-image directories, would trade
                    # that away for nothing. autodefrag would likewise fight the sharing it
                    # is supposed to preserve.
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };

                  "@log" = {
                    mountpoint = "/var/log";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };

                  # Nothing here writes snapshots — NixOS generations are what replaces
                  # upstream's Snapper rotation. The subvolume exists so that a host that
                  # wants btrfs snapshots has the conventional place to put them, and so
                  # they land somewhere the root subvolume is not.
                  "@snapshots" = {
                    mountpoint = "/.snapshots";
                    mountOptions = [
                      "compress=zstd"
                      "noatime"
                    ];
                  };
                }
                // lib.optionalAttrs (cfg.swapSize != null) {
                  "@swap" = {
                    mountpoint = "/.swapvol";
                    # No compression and no other rewriting on this subvolume: the kernel
                    # writes swap pages by offset into a file whose extents must not move.
                    mountOptions = [ "noatime" ];
                    swap.swapfile.size = cfg.swapSize;
                  };
                };
              };
            };
          };
        };
      };
    };

    # /var/log is neededForBoot because NixOS marks it so itself; restating it here would
    # only be a second place to keep in sync.
  };
}
