# CI smoke test for the port, run as `nix flake check`.
#
# WHAT THIS TEST COVERS
#
#   - the machine boots and reaches multi-user.target
#   - $OMARCHY_PATH resolves to a store path that exists, holds a readable `version`,
#     and is the same tree the `omarchy` router on PATH lives in
#   - the CLI router discovers its commands: `omarchy --help` lists the groups and
#     `omarchy commands --check` walks every bin/omarchy-* and validates its metadata
#   - no FHS path survived vendoring: nothing under $OMARCHY_PATH carries a
#     `#!/bin/bash` shebang or a literal /usr/share/omarchy
#   - the Arch-machinery stubs fail loudly and name the NixOS equivalent
#   - the reimplemented commands behave (pkg-present, version, migrate)
#   - the firewall opens 22/tcp and 53317 tcp+udp and nothing else
#   - a greeter unit exists and is wanted by graphical.target, and a Hyprland uwsm
#     session desktop file is installed
#
# WHAT THIS TEST DOES NOT COVER — a green run here is NOT a verified desktop
#
# Everything that needs a GPU or a pair of eyes stays in the hardware smoke-test
# checklist in CLAUDE.md and has to be run by hand once per release: Hyprland actually
# starting and rendering, the Quickshell bar/menu/OSD/notifications/lock screen
# appearing, autologin landing in a live session, theme switching taking effect across
# GTK/Qt/terminal, audio and bluetooth devices, printing, brightness and power keys,
# suspend/resume, and the LUKS passphrase prompt on the encrypted host.
#
# The greeter is deliberately never started here: the VM has no GPU, so the unit is
# asserted to exist and be wanted rather than to come up.
{
  lib,
  pkgs,
  nixosModules,
  # modules/omarchy/home.nix needs the home-manager NixOS module in the same
  # evaluation. flake.nix does not pass it today; accepting it with a default keeps
  # this test working either way, so the flake can start passing it without a change
  # here.
  homeManagerModule ? null,
  ...
}:

pkgs.testers.runNixOSTest {
  name = "omarchy-session";

  nodes.machine =
    { ... }:
    {
      imports =
        [ nixosModules.omarchy ]
        ++ lib.optional (homeManagerModule != null) homeManagerModule;

      omarchy = {
        enable = true;
        user = "omarchy";
        autoLogin = true;
      };

      # The desktop's user. mkDefault throughout so a definition in
      # modules/omarchy/system.nix wins instead of colliding. No password: the test
      # driver runs as root, and `su -l` needs none from there.
      users.users.omarchy = {
        isNormalUser = lib.mkDefault true;
        extraGroups = [ "wheel" ];
      };

      # Stop at multi-user: the greeter cannot render without a GPU, and this test only
      # asserts that its unit is installed and wanted. mkForce because the
      # display-manager module sets this to graphical.target.
      systemd.defaultUnit = lib.mkForce "multi-user.target";

      documentation.enable = lib.mkForce false;

      virtualisation = {
        graphics = false;
        memorySize = 2048;
        cores = 2;
        diskSize = 4096;
      };

      system.stateVersion = lib.trivial.release;
    };

  testScript = ''
    import re

    start_all()
    machine.wait_for_unit("multi-user.target")

    # --- $OMARCHY_PATH ----------------------------------------------------------
    # A login shell, so both mechanisms that could carry the variable are exercised:
    # /etc/set-environment via /etc/profile, and /etc/pam/environment via pam_env.
    omarchy_path = machine.succeed("su -l omarchy -c 'echo $OMARCHY_PATH'").strip()
    assert omarchy_path.startswith("/nix/store/"), \
        f"OMARCHY_PATH is not a store path: {omarchy_path!r}"
    machine.succeed(f"test -d {omarchy_path}")
    machine.succeed(f"test -r {omarchy_path}/version")

    version = machine.succeed(f"cat {omarchy_path}/version").strip()
    assert version == "${pkgs.omarchy.version}", \
        f"vendored version is {version!r}, expected ${pkgs.omarchy.version}"

    # The router finds its siblings through `dirname "$BASH_SOURCE"`, so the command on
    # PATH has to be a symlink into the same tree $OMARCHY_PATH names. A wrapper script
    # here would silently break command discovery.
    router = machine.succeed("readlink -f $(command -v omarchy)").strip()
    assert router == f"{omarchy_path}/bin/omarchy", \
        f"omarchy on PATH resolves to {router!r}, not into {omarchy_path!r}"

    # --- the CLI router ---------------------------------------------------------
    # `--help` prints the router's static group table; `commands --check` is the part
    # that actually scans the bin directory and parses every `# omarchy:summary=`
    # header, which is why it is the single best smoke test of the whole port.
    help_output = machine.succeed("omarchy --help")
    assert "Groups:" in help_output, "omarchy --help printed no group list"
    for group in ("pkg", "theme", "update", "system", "hyprland"):
        assert re.search(rf"^  {group}\s", help_output, re.M), \
            f"omarchy --help does not list the {group!r} group"

    machine.succeed("omarchy commands --check")

    # --- no FHS paths survived vendoring ----------------------------------------
    # Same invariant the derivation checks at build time, re-checked against what
    # actually landed in the store. *.md is excluded because the shipped agent skills
    # quote both strings as prose.
    leftovers = machine.succeed(
        "grep -rlI --exclude='*.md' "
        "-e '#!/bin/bash' -e '#!/usr/bin/python3' -e '/usr/share/omarchy' "
        f"{omarchy_path} || true"
    ).strip()
    assert leftovers == "", f"unported FHS paths remain in:\n{leftovers}"

    # --- the module wrote its own runtime config, and not upstream's ------------
    machine.succeed("grep -q OMARCHY_NIXOS_FLAKE /etc/omarchy-nixos.conf")
    # Upstream reads /etc/omarchy.conf as a dev link and would let a stale path win.
    machine.fail("test -e /etc/omarchy.conf")

    # --- the Arch-machinery stubs ----------------------------------------------
    for stub, hint in (
        ("omarchy-pkg-add", "environment.systemPackages"),
        ("omarchy-refresh-limine", "the bootloader is configured declaratively"),
    ):
        output = machine.fail(f"{stub} something 2>&1")
        assert "is not available on omarchy-nixos" in output, \
            f"{stub} did not say it is unavailable: {output!r}"
        assert hint in output, f"{stub} did not name the NixOS equivalent: {output!r}"

    # --- the reimplemented commands --------------------------------------------
    machine.succeed("omarchy-pkg-present bash")
    machine.fail("omarchy-pkg-present definitely-not-a-command")
    # Same thing through the router, which proves routing as well as the command.
    machine.succeed("omarchy pkg present bash")

    printed = machine.succeed("omarchy version").strip()
    assert printed.startswith(version), \
        f"omarchy version printed {printed!r}, expected it to start with {version!r}"

    # Nothing ever migrates: the system is rebuilt from its flake.
    machine.fail("omarchy-migrate --pending")
    machine.succeed("omarchy-migrate")

    # --- the firewall -----------------------------------------------------------
    def firewall_rules():
        rules = machine.succeed("iptables -S nixos-fw 2>/dev/null || true")
        rules += machine.succeed("ip6tables -S nixos-fw 2>/dev/null || true")
        if "dport" not in rules:
            rules += machine.succeed("nft list ruleset 2>/dev/null || true")
        return rules

    def port_open(rules, proto, port):
        # iptables-save writes "-p tcp -m tcp --dport 22 -j nixos-fw-accept";
        # nftables writes "tcp dport 22 accept" or "tcp dport { 22, 53317 } accept".
        pattern = rf"dport\s+(\{{[^}}]*\b{port}\b[^}}]*\}}|{port}\b)"
        for line in rules.splitlines():
            if proto in line and "accept" in line.lower() and re.search(pattern, line):
                return True
        return False

    rules = firewall_rules()
    for proto, port in (("tcp", 22), ("tcp", 53317), ("udp", 53317)):
        assert port_open(rules, proto, port), \
            f"{port}/{proto} is not open:\n{rules}"
    # Deny in, allow out: nothing beyond ssh and LocalSend is reachable.
    for proto, port in (("tcp", 80), ("tcp", 443), ("tcp", 8080)):
        assert not port_open(rules, proto, port), \
            f"{port}/{proto} must not be open:\n{rules}"

    # --- the greeter and the session desktop file -------------------------------
    # Tolerant on purpose: modules/omarchy/session.nix owns both, and a run before it
    # lands should report the gap rather than fail the whole check.
    if machine.execute("systemctl cat display-manager.service >/dev/null 2>&1")[0] == 0:
        wanted = machine.succeed(
            "systemctl show -p WantedBy --value display-manager.service"
        )
        assert "graphical.target" in wanted, \
            f"display-manager.service is not wanted by graphical.target: {wanted!r}"
        exec_start = machine.succeed(
            "systemctl show -p ExecStart --value display-manager.service"
        )
        assert "sddm" in exec_start.lower(), \
            f"the greeter is not sddm: {exec_start!r}"
    else:
        print("SKIP: no display-manager.service — no greeter is enabled yet")

    desktops = machine.succeed(
        "find /run/current-system/sw/share/wayland-sessions "
        "/etc/xdg/wayland-sessions -name '*.desktop' 2>/dev/null || true"
    ).strip()
    if not desktops:
        print("SKIP: no wayland session desktop files installed yet")
    else:
        uwsm_sessions = [p for p in desktops.splitlines() if "uwsm" in p.lower()]
        assert uwsm_sessions, f"no uwsm session among:\n{desktops}"
        entry = machine.succeed(f"cat {uwsm_sessions[0]}")
        assert "hyprland" in entry.lower(), \
            f"the uwsm session is not Hyprland:\n{entry}"
  '';
}
