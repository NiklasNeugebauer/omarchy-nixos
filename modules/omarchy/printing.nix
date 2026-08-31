# Printing and local service discovery.
#
# Upstream's contribution here is small: two cups-browsed directives that narrow what gets
# auto-added, and a hardening drop-in plus a system user for the browsing daemon. NixOS runs
# cups-browsed under its own unit and creates its own user, so only the policy carries over.
{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.omarchy;
in
{
  config = lib.mkIf cfg.enable {
    services.printing = {
      enable = true;

      # Driverless IPP is what a printer bought this decade speaks, and the generic drivers
      # cover the rest without asking the user which PPD they need.
      drivers = with pkgs; [
        gutenprint
        cups-filters
        foomatic-db-ppds
      ];

      browsed.enable = true;
      # From etc/cups/cups-browsed.conf. Auto-creating a queue for every remote CUPS server
      # on the network fills the print dialog with printers in other rooms; driverless IPP
      # devices are the ones worth adding without being asked. Remote CUPS queues can still
      # be added by hand.
      browsedConf = ''
        CreateIPPPrinterQueues Driverless
        CreateRemoteCUPSPrinterQueues No
      '';
    };

    # Discovery for both printers and the `.local` names the shell's network panel resolves.
    # This is also why resolved's own MulticastDNS is off in network.nix — one responder.
    services.avahi = {
      enable = true;
      # From etc/nsswitch.conf: mdns_minimal ahead of dns, so a .local lookup never leaves
      # the link and a non-.local name never waits on mDNS.
      nssmdns4 = true;
      openFirewall = true;
      publish = {
        enable = true;
        userServices = true;
      };
    };

    # The upstream drop-in that runs cups-browsed as its own user with ProtectSystem=strict
    # has no counterpart: NixOS' cups-browsed unit already runs confined and its
    # etc/sysusers.d user is created by the module. The one thing upstream moves that NixOS
    # does not is the cache directory away from /var/cache/cups, which the print filters can
    # write; NixOS gives the unit its own CacheDirectory, so that is already true here.

    environment.systemPackages = with pkgs; [
      system-config-printer
      cups-pk-helper # the polkit agent the printer dialog uses to add a queue
    ];
  };
}
