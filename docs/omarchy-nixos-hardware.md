# Hardware notes

Upstream detects hardware at install time and runs a matching script from
`install/hardware/`. There is no equivalent here on purpose: a NixOS host declares its own
hardware in `hosts/<name>/hardware.nix`, and guessing at build time would be guessing about a
machine the build has never seen.

This file is the map from upstream's per-vendor scripts to the NixOS option that replaces
each one, so a new machine can be set up without reading upstream's shell.

| Upstream | NixOS equivalent |
| --- | --- |
| `install/hardware/nvidia.sh`, `nvidia-*-dkms` | `hardware.nvidia`, `hardware.nvidia.open`, `services.xserver.videoDrivers = [ "nvidia" ]` |
| `install/hardware/intel.sh`, `vulkan-intel`, `intel-media-driver`, `libvpl` | `hardware.graphics.extraPackages` |
| `vulkan-radeon`, AMD | `hardware.graphics.extraPackages = [ pkgs.amdvlk ]`, or leave it to Mesa |
| `asusctl`, `supergfxctl`, `install/hardware/asus/` | `services.asusd.enable` |
| `install/hardware/framework/`, `qmk-hid` | `hardware.framework.*` from `nixos-hardware` |
| `intel-lpmd`, `thermald` | `services.thermald.enable`; `intel-lpmd` is not in nixpkgs |
| `broadcom-wl`, `yt6801-dkms`, `tuxedo-drivers`, `macbook12-spi-driver` | `boot.extraModulePackages` — each needs its own derivation |
| T2 MacBook stack (`linux-t2`, `apple-bcm-firmware`, `t2fanrd`) | not packaged; a T2 Mac needs a kernel fork this repo does not carry |
| `install/hardware/microcode.sh` | `hardware.cpu.{intel,amd}.updateMicrocode` |
| `install/hardware/set-wireless-regdom.sh` | `hardware.wirelessRegulatoryDatabase` — the kernel picks the domain from the AP, so upstream's timezone-derived guess is unnecessary |
| `bolt` (Thunderbolt authorisation) | `services.hardware.bolt.enable` |
| `asdcontrol` (Apple Studio Display brightness) | not packaged; `ddcutil` covers normal monitors |
| `install/hardware/speaker-tuning.sh`, `default/audio/tunings/` | stays a runtime feature; see `docs/divergences.md` |
| fingerprint (`omarchy setup security fingerprint`) | `services.fprintd.enable`, which also arms the shell's `omarchy-lock-fingerprint` PAM service |

## Starting a real host

    cp -r hosts/omarchy-laptop hosts/<yourname>
    nixos-generate-config --show-hardware-config > hosts/<yourname>/hardware.nix
    # set omarchy.disk.device in hosts/<yourname>/disko.nix to a /dev/disk/by-id path
    # add hosts/<yourname> to nixosConfigurations in flake.nix

For a laptop model that [nixos-hardware](https://github.com/NixOS/nixos-hardware) covers, add
it as a flake input and import its module before `hardware.nix`; it does the same job as
upstream's per-vendor script and is maintained by people who own the machine.
