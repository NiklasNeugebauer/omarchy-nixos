# Hardware notes

Upstream detects hardware at install time and runs a matching script from
`install/hardware/`. There is no equivalent here on purpose: a NixOS host declares its own
hardware in `hosts/<name>/hardware.nix`, and guessing at build time would be guessing about a
machine the build has never seen.

This file maps upstream's per-vendor *scripts* to the NixOS option that replaces each one, so
a new machine can be set up without reading upstream's shell. Package names are not repeated
here — `docs/omarchy-package-inventory.md` owns the upstream-package-to-attribute mapping,
including the driver packages, and a second copy of it would drift.

| Upstream script or concern | NixOS equivalent |
| --- | --- |
| `install/hardware/nvidia.sh` | `hardware.nvidia`, `hardware.nvidia.open`, `services.xserver.videoDrivers = [ "nvidia" ]` |
| `install/hardware/intel.sh` | `hardware.graphics.extraPackages` |
| AMD graphics | `hardware.graphics.extraPackages = [ pkgs.amdvlk ]`, or leave it to Mesa |
| `install/hardware/asus/` | `services.asusd.enable` |
| `install/hardware/framework/` | `hardware.framework.*` from `nixos-hardware` |
| thermal management | `services.thermald.enable`; `intel-lpmd` is not in nixpkgs |
| out-of-tree wireless and laptop drivers | `boot.extraModulePackages` — each needs its own derivation |
| T2 MacBook support | not packaged; a T2 Mac needs a kernel fork this repo does not carry |
| `install/hardware/microcode.sh` | `hardware.cpu.{intel,amd}.updateMicrocode` |
| `install/hardware/set-wireless-regdom.sh` | `hardware.wirelessRegulatoryDatabase` — the kernel picks the domain from the AP, so upstream's timezone-derived guess is unnecessary |
| Thunderbolt authorisation | `services.hardware.bolt.enable` |
| Apple Studio Display brightness | not packaged; `ddcutil` covers normal monitors |
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
