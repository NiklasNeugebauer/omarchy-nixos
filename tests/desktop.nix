# Does the desktop itself come up? Autologs in, waits for Hyprland and the Quickshell
# shell, and screenshots the result.
#
# This is the deepest an automated check can go without real hardware. Hyprland's renderer
# wants a DRM device, so the VM is given a virtio GPU and Mesa is told to use its software
# rasteriser; that is enough for the compositor to get a scene out, but it is not a GPU.
# A bar that draws here can still fail on a real one, and nothing here judges whether it
# looks right — that is what the hardware checklist in docs/progress.md is for.
#
# It does, however, catch the one class of bug the build cannot: a vendored command that
# shells out to a tool nothing installed. Porting step 7 is marked "check by hand" for
# exactly that reason, and this is the check.
#
#   nix build .#desktop-screenshots && ls result/
#
# Not part of `nix flake check`: needs a graphics-capable VM and several minutes.
{
  lib,
  pkgs,
  nixosModules,
  homeManagerModule,
  ...
}:

pkgs.testers.runNixOSTest {
  name = "omarchy-desktop";

  nodes.machine = import ./machine.nix { inherit lib; } {
    inherit nixosModules homeManagerModule;
    graphical = true;
    memorySize = 6144;
    cores = 4;
    diskSize = 8192;
  };

  enableOCR = true;

  testScript = ''
    import re

    machine.start()
    machine.wait_for_unit("graphical.target")

    # Autologin means sddm starts the session itself; the compositor is a user unit, so
    # wait on the process rather than on a system unit.
    machine.wait_until_succeeds("pgrep -f Hyprland", timeout=300)
    machine.sleep(30)
    machine.screenshot("hyprland")

    # omarchy-launch-shell is what Hyprland's autostart runs; quickshell is the shell.
    # Asserted, not reported: a quickshell bump that renames a QML module the shell imports
    # kills it, omarchy-launch-shell gives up after five relaunches in a minute, and a
    # printed False would leave a green test and no screenshot to look at — which is exactly
    # the failure this check exists for.
    machine.wait_until_succeeds("pgrep -f quickshell", timeout=180)
    machine.sleep(30)
    machine.screenshot("shell")

    print(f"OCR: {machine.get_screen_text_variants()!r}")

    # --- missing runtime tools --------------------------------------------------
    # Porting step 7 puts the tools the vendored commands shell out to in the system
    # profile rather than wrapping each command, which means a tool nobody listed fails at
    # runtime and not at build time. A live session is the only place that shows up, and it
    # shows up in exactly two shapes: bash reporting a command it could not exec, and Qt
    # reporting a process that would not start. Both are failures here.
    #
    # Anything genuinely optional belongs in the allowlist below with a reason, not
    # silently tolerated.
    allowed_missing = [
        # Upstream probes for these and degrades on purpose; they are user-installed.
        "mise",
        "tailscale",
        "fprintd-list",
    ]

    journal = machine.succeed(
        "journalctl --no-pager -b -o cat || true"
    ) + machine.succeed(
        "su -l omarchy -c 'journalctl --user --no-pager -b -o cat || true' || true"
    )

    # Matched on the quoted command token rather than anywhere in the line: a substring
    # test would let a genuinely missing tool through on any line that happens to contain
    # the word "promise".
    def is_allowed(line):
        return any(
            re.search(rf"""["'\s]{re.escape(tool)}["'\s:]""", line)
            for tool in allowed_missing
        )

    missing = [
        line
        for line in journal.splitlines()
        if ("not found" in line or "Process failed to start" in line) and not is_allowed(line)
    ]
    if missing:
        raise Exception(
            "the session referenced tools that are not installed — add them to "
            "modules/omarchy/packages.nix:\n" + "\n".join(sorted(set(missing)))
        )

    # Whatever happened, the journals are the useful artefact when it did not work.
    print(machine.succeed("systemctl --no-pager --failed || true"))
    print(machine.succeed(
        "journalctl --no-pager -n 80 -t omarchy-shell "
        "-u 'user@*' -u display-manager || true"
    ))
    print(machine.succeed(
        "su -l omarchy -c 'journalctl --user --no-pager -n 60 || true' || true"
    ))
  '';
}
