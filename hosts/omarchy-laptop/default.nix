# Generic encrypted laptop. Copy this directory to make a real host: drop in the output of
# `nixos-generate-config --show-hardware-config`, set the disk's by-id path in disko.nix,
# and change the user name.
{ lib, pkgs, ... }:

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
    # Set with `passwd` after the first boot, or declare a hashed password out of band.
    # Never a plaintext password and never a hash in this repo.
    hashedPassword = null;
  };

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  system.stateVersion = "26.05";
}
