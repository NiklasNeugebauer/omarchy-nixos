# Smoke-test host. Never installed to metal: no encryption, and it logs itself in.
#
# `nix build .#nixosConfigurations.omarchy-vm.config.system.build.vm` produces a runnable
# VM. Every change under modules/, home/ or patches/ goes through this host first.
{ ... }:

{
  imports = [ ../common.nix ];

  networking.hostName = "omarchy-vm";

  omarchy = {
    enable = true;
    user = "omarchy";
    autoLogin = true;
    # Nothing to rebuild from inside a throwaway VM.
    flake = "/etc/nixos";
  };

  users.users.omarchy = {
    isNormalUser = true;
    description = "Omarchy";
    # A known password is acceptable only because this host is disposable and never
    # reachable from a network that matters. Do not copy this into a real host.
    initialPassword = "omarchy";
    extraGroups = [ "wheel" ];
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  # build-vm replaces the root device with its own image; this declaration is what makes
  # the configuration evaluable as a normal system as well.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  # Enough guests resources that Hyprland and the shell actually come up.
  virtualisation.vmVariant = {
    virtualisation = {
      memorySize = 4096;
      cores = 4;
      diskSize = 16384;
      # Hyprland needs a GPU it can get a DRM node from.
      qemu.options = [
        "-device virtio-vga-gl"
        "-display gtk,gl=on"
      ];
    };
  };

  system.stateVersion = "26.05";
}
