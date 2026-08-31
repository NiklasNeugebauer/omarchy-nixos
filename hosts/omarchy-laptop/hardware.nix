# Replace this file with the output of `nixos-generate-config --show-hardware-config` on
# the target machine. What is here is the intersection that holds for any current x86_64
# laptop, and nothing that depends on a specific model.
{ lib, pkgs, ... }:

{
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"
  ];
  boot.kernelModules = [ "kvm-intel" "kvm-amd" ];

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
  hardware.cpu.amd.updateMicrocode = lib.mkDefault true;

  # Vendor-neutral: both userspace drivers are cheap and let the same config boot on
  # either GPU. Upstream picks per-machine in install/hardware/; a NixOS host names its
  # own hardware in this file instead.
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      libvdpau-va-gl
      vulkan-loader
    ];
  };

  services.thermald.enable = lib.mkDefault true;
  services.fwupd.enable = true;
  services.fprintd.enable = lib.mkDefault false;
}
