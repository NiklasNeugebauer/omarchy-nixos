# Printing and local service discovery.
#
# Upstream's contribution here is small: two cups-browsed directives that narrow what gets
# auto-added, and a hardening drop-in that moves the browsing daemon off root and out of the
# shared cache directory. Both carry over — NixOS' cups-browsed unit sets an ExecStart and
# nothing else, so without the drop-in the daemon runs unconfined as root.
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

      # Driverless IPP is what a printer bought this decade speaks, and it needs no driver
      # package at all, and cups-filters is unconditional in
      # the NixOS module. Upstream ships no PPD collection either, so none is added here: a
      # printer that needs one is a per-host decision, not a default several hundred
      # megabytes wide.
      drivers = [ ];

      browsed.enable = true;
      # From etc/cups/cups-browsed.conf. Auto-creating a queue for every remote CUPS server
      # on the network fills the print dialog with printers in other rooms; driverless IPP
      # devices are the ones worth adding without being asked. Remote CUPS queues can still
      # be added by hand. CacheDir goes with the CacheDirectory below: the default is under
      # /var/cache/cups, which print filters can write to.
      browsedConf = ''
        CreateIPPPrinterQueues Driverless
        CreateRemoteCUPSPrinterQueues No
        CacheDir /var/cache/cups-browsed
      '';
    };

    # Discovery for both printers and the `.local` names the shell's network panel resolves.
    # This is also why resolved's own MulticastDNS is off in network.nix — one responder.
    services.avahi = {
      enable = true;
      # From etc/nsswitch.conf, which uses mdns_minimal — that covers both address families,
      # so a .local host reachable only over IPv6 resolves too.
      nssmdns4 = true;
      nssmdns6 = true;
      # Deliberately false. It would open UDP 5353, and upstream's install/config/firewall.sh
      # opens 53317 and nothing else; the firewall policy this system states is 22 and 53317
      # only. Printer discovery still works outbound — a host that needs to *answer* mDNS
      # queries opens the port itself and records why.
      openFirewall = false;
      publish = {
        enable = true;
        userServices = true;
      };
    };

    # From etc/systemd/system/cups-browsed.service.d/10-omarchy.conf. The daemon only needs
    # to talk to the network and to cupsd, so it has no business running as root with the
    # filesystem writable. DynamicUser replaces upstream's etc/sysusers.d entry: it allocates
    # the user and the cache directory together, so there is no static account to keep in
    # sync with the unit.
    systemd.services.cups-browsed.serviceConfig = {
      DynamicUser = true;
      CacheDirectory = "cups-browsed";
      CacheDirectoryMode = "0750";
      UMask = "0027";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      RestrictSUIDSGID = true;
    };

    environment.systemPackages = with pkgs; [
      system-config-printer
      cups-pk-helper # the polkit agent the printer dialog uses to add a queue
    ];
  };
}
