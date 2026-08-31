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
#   - home-manager activation for the user succeeded, and left behind a seeded
#     user-owned file, a store-symlinked shipped default, and a theme whose
#     per-application colour files were rendered and not just named
#   - a greeter unit exists and is wanted by graphical.target, and a Hyprland uwsm
#     session desktop file is installed
#
# WHAT THIS TEST DOES NOT COVER — a green run here is NOT a verified desktop
#
# Everything that needs a GPU or a pair of eyes stays in the hardware smoke-test
# checklist in docs/progress.md and has to be run by hand once per release: Hyprland actually
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
  # modules/omarchy/home.nix configures home-manager, so the home-manager NixOS module
  # has to be in the same evaluation.
  homeManagerModule,
  ...
}:

pkgs.testers.runNixOSTest {
  name = "omarchy-session";

  nodes.machine = import ./machine.nix { inherit lib; } {
    inherit nixosModules homeManagerModule;
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

    # --- home-manager, which owns everything under $HOME ------------------------
    # Its unit is wanted by multi-user.target, and a failed wanted unit does not stop
    # the target — so waiting on multi-user.target alone would pass with the whole
    # $HOME layer broken.
    machine.wait_for_unit("home-manager-omarchy.service")

    # A user-owned file, seeded once because upstream invites the user to edit it.
    machine.succeed("test -f /home/omarchy/.config/hypr/hyprland.lua")
    # A shipped default, which has to be a symlink into the store and not a copy.
    alacritty = machine.succeed(
        "readlink -f /home/omarchy/.config/alacritty"
    ).strip()
    assert alacritty.startswith("/nix/store/"), \
        f"a shipped default was copied instead of linked: {alacritty!r}"
    # The theme switcher ran headlessly during activation. A theme name proves nothing on
    # its own: the switcher writes that first and renders the per-application colour files
    # afterwards, so one that ran without a usable PATH leaves a named theme and no
    # rendered files, and every application comes up unstyled while looking, from the
    # outside, like theming worked.
    theme = machine.succeed(
        "cat /home/omarchy/.local/state/omarchy/current/theme.name"
    ).strip()
    assert theme, "no theme was applied during home-manager activation"

    theme_dir = "/home/omarchy/.local/state/omarchy/current/theme"
    rendered = machine.succeed(f"ls {theme_dir}").split()
    for name in ("alacritty.toml", "btop.theme", "foot.ini", "hyprland.lua", "shell.toml"):
        assert name in rendered, \
            f"{name} was not rendered into {theme_dir}; it holds {sorted(rendered)}"

    # --- the greeter and the session desktop file -------------------------------
    # The sddm module builds display-manager.service but leaves its WantedBy empty, so
    # this is the assertion that catches a system booting to a text console.
    #
    # Checked as the enablement symlink rather than through `systemctl show -p WantedBy`:
    # systemd derives that property when the *depending* unit loads, and this VM stops at
    # multi-user.target, so graphical.target is never loaded and the property is empty
    # whether the greeter is wired up or not.
    machine.succeed(
        "test -L /etc/systemd/system/graphical.target.wants/display-manager.service"
    )
    # NixOS wraps every unit's ExecStart in a generated start script, so the property
    # names that script and never the greeter. Read what the script actually runs.
    start_script = machine.succeed(
        "systemctl show -p ExecStart --value display-manager.service "
        "| sed -n 's/.*path=\\([^ ;]*\\).*/\\1/p'"
    ).strip()
    assert start_script, "display-manager.service has no ExecStart"
    runs = machine.succeed(f"cat {start_script}")
    assert "sddm" in runs.lower(), f"the greeter is not sddm:\n{runs}"

    # The greeter's generated config has to name the vendored theme, or the login screen
    # is stock sddm and the port's most visible piece is silently absent.
    sddm_conf = machine.succeed("cat /etc/sddm.conf.d/00-nixos.conf")
    assert "omarchy" in sddm_conf.lower(), \
        f"sddm is not using the omarchy theme:\n{sddm_conf}"

    desktops = machine.succeed(
        "find /run/current-system/sw/share/wayland-sessions "
        "/etc/xdg/wayland-sessions -name '*.desktop' 2>/dev/null || true"
    ).strip()
    assert desktops, "no wayland session desktop file is installed"
    uwsm_sessions = [p for p in desktops.splitlines() if "uwsm" in p.lower()]
    assert uwsm_sessions, f"no uwsm session among:\n{desktops}"
    entry = machine.succeed(f"cat {uwsm_sessions[0]}")
    assert "hyprland" in entry.lower(), \
        f"the uwsm session is not Hyprland:\n{entry}"
  '';
}
