# Generic encrypted laptop. Copy this directory to make a real host: drop in the output of
# `nixos-generate-config --show-hardware-config`, set the disk's by-id path in disko.nix,
# and change the user name.
{ ... }:

{
  imports = [
    ../common.nix
    ./disko.nix
    ./hardware.nix
  ];

  networking.hostName = "omarchy-laptop";

  omarchy = {
    enable = true;
    user = "omarchy";
    # A real machine asks for a password at the greeter. The disk is encrypted, but the
    # greeter is what stands between a running session and whoever opens the lid.
    autoLogin = false;
    flake = "/home/omarchy/omarchy-nixos";
  };

  users.users.omarchy = {
    isNormalUser = true;
    description = "Omarchy";
    extraGroups = [ "wheel" ];
    # No password is set here, and none may be: this repo is public, so neither a plaintext
    # password nor a hash belongs in it. The consequence is that a fresh install cannot be
    # logged into — the greeter rejects an empty password — so set one during the install,
    # before the first boot:
    #
    #   nixos-enter --root /mnt -c 'passwd omarchy'
    #
    # `users.mutableUsers` stays true so that password survives every later rebuild.
  };

  # The bootloader itself is configured in modules/omarchy/system.nix, which owns the
  # generation limit that replaces upstream's Limine and Snapper story. Only the part that
  # depends on this machine's firmware belongs here.
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "26.05";
}
