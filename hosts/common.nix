# What every host shares regardless of hardware. Anything hardware- or disk-specific
# belongs in the host directory, not here.
{ lib, ... }:

{
  time.timeZone = lib.mkDefault "UTC";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  console.keyMap = lib.mkDefault "us";

  # Password auth stays off. A key is the only way in, and the firewall in
  # modules/omarchy/network.nix is what decides whether 22 is reachable at all.
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  users.mutableUsers = true;
  security.sudo.wheelNeedsPassword = true;

  documentation.nixos.enable = false;
}
