# ---------------------------------------------------------------------------------------
#  READ THIS BEFORE YOU INSTALL. This host is a template, not a machine.
#
#  1. Find your disk. On the installer, run:
#
#         ls -l /dev/disk/by-id/
#
#     Pick the entry for the whole disk you intend to erase — the one whose symlink target
#     is a bare device such as `../../nvme0n1`, not a `-part1` entry and not the installer
#     medium. Confirm it is the disk you think it is:
#
#         lsblk -o NAME,SIZE,MODEL,SERIAL
#
#  2. Put that full `/dev/disk/by-id/...` path into `device` below, replacing the
#     placeholder. The placeholder is not a working default and is not meant to be one; it
#     names no device, so an install attempted without this edit stops with "device not
#     found" instead of erasing whichever disk happened to be first.
#
#  3. Install. `disko --mode disko` DESTROYS EVERYTHING on that disk. It asks for the LUKS
#     passphrase; there is no recovery if you forget it and no copy of it anywhere.
#
#         sudo nix --experimental-features "nix-command flakes" run \
#           github:nix-community/disko -- --mode disko --flake .#omarchy-laptop
#         sudo nixos-install --flake .#omarchy-laptop
#
#     `--flake` and not a path to this file: the layout is a NixOS module that reads its
#     device and sizes out of the host's configuration, so it only has values once the host
#     has been evaluated.
#
#  4. Before the first real boot, generate the hardware scan for this machine and keep it
#     next to this file — the layout here is generic, the hardware never is.
# ---------------------------------------------------------------------------------------
{
  lib,
  config,
  ...
}:

let
  placeholder = "/dev/disk/by-id/EDIT-hosts-omarchy-laptop-disko.nix-BEFORE-INSTALLING";
in
{
  imports = [ ../../modules/disko/luks-btrfs.nix ];

  omarchy.disk = {
    enable = true;
    device = placeholder;
    # Hibernation is off by default, so zram is the only swap. Set a size here — at least
    # as much as physical RAM — if this machine has to suspend to disk.
    swapSize = null;
  };

  # Evaluation deliberately still succeeds with the placeholder in place, so the flake stays
  # checkable without anyone naming a real disk in a public repository. This is the reminder
  # that the edit is still outstanding.
  warnings = lib.optional (config.omarchy.disk.device == placeholder) ''
    hosts/omarchy-laptop still carries the placeholder disk path. Replace
    omarchy.disk.device with this machine's /dev/disk/by-id/... path before installing.
  '';
}
