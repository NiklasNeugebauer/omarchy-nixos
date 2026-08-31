# Networking: NetworkManager, the resolver, and the firewall.
#
# Upstream's firewall is ufw plus ufw-docker, configured once by install/config/firewall.sh.
# ufw has no place here — it writes iptables rules imperatively into a file nothing else
# owns, which is precisely the state NixOS exists to avoid. The same policy is stated
# declaratively below, and NixOS' docker module already installs the bridge rules that
# ufw-docker was patching in.
{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.omarchy;

  # The docker bridge address from etc/docker/daemon.json, which the resolved stub listener
  # and the firewall allowance below both have to agree with.
  dockerBridge = "172.17.0.1";
in
{
  config = lib.mkIf cfg.enable {
    networking.networkmanager = {
      enable = true;
      # From etc/NetworkManager/conf.d/omarchy-wifi-powersave.conf. Power save trades
      # 20-300ms latency spikes on an idle link for a fraction of a watt, and firmware on
      # some Intel BE200/BE211 parts drops the link outright when the radio naps.
      wifi.powersave = false;
      dns = "systemd-resolved";
    };

    # Nothing in the session blocks on the network, and letting graphical.target wait on
    # DHCP or Wi-Fi association just delays the greeter. Upstream masks the same unit.
    systemd.services.NetworkManager-wait-online.enable = false;

    services.resolved = {
      enable = true;
      settings.Resolve = {
        # Avahi owns mDNS on this system (see printing.nix), and two responders on the same
        # port means neither answers reliably.
        LLMNR = "no";
        MulticastDNS = "no";
        # From etc/systemd/resolved.conf.d/20-docker-dns.conf. Containers get the host's
        # resolver by pointing at the bridge address, which needs a listener there.
        DNSStubListenerExtra = dockerBridge;
      };
    };

    # Regulatory data for the wireless channels a radio is allowed to use in this region.
    hardware.wirelessRegulatoryDatabase = true;

    # nftables rather than iptables: one table, atomically replaced on rebuild, so a failed
    # rebuild cannot leave the machine half-open.
    networking.nftables.enable = true;

    networking.firewall = {
      enable = true;
      # Deny inbound, allow outbound — NixOS' default, restated because it is the policy
      # install/config/firewall.sh sets explicitly and a reader should not have to know it.
      rejectPackets = false;

      allowedTCPPorts = [
        22 # sshd, key-only
        53317 # LocalSend
      ];
      allowedUDPPorts = [
        53317 # LocalSend discovery
      ];

      # From install/config/firewall.sh. Containers resolve through the stub listener on the
      # bridge, so the bridge address has to accept DNS from container subnets — and only
      # from those, on that address, for that port.
      extraInputRules = ''
        ip saddr 172.16.0.0/12 ip daddr ${dockerBridge} udp dport 53 accept
        ip saddr 192.168.0.0/16 ip daddr ${dockerBridge} udp dport 53 accept
      '';

      # docker0 is deliberately NOT a trusted interface. Trusting it would accept every
      # packet a container sends to the host, where upstream's ufw rules allow exactly one
      # thing: DNS to the bridge address, which is the rule above. Container egress and
      # published ports do not depend on this — they are forward-chain and docker's own
      # chains, both of which the NixOS docker module sets up.
    };

    # The shell's network panel talks to NetworkManager over D-Bus, but the CLI helpers
    # behind the menu shell out to these.
    environment.systemPackages = with pkgs; [
      networkmanagerapplet
      iw
      ethtool
      dnsutils
    ];
  };
}
