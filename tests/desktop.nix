# Does the desktop itself come up? Autologs in, waits for Hyprland and the Quickshell
# shell, and screenshots the result.
#
# This is the deepest an automated check can go without real hardware. Hyprland's renderer
# wants a DRM device, so the VM is given a virtio GPU and Mesa is told to use its software
# rasteriser; that is enough for the compositor to get a scene out, but it is not a GPU.
# A bar that draws here can still fail on a real one, and nothing here judges whether it
# looks right — that is what the checklist in CLAUDE.md is for.
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
  homeManagerModule ? null,
  ...
}:

pkgs.testers.runNixOSTest {
  name = "omarchy-desktop";

  nodes.machine =
    { ... }:
    {
      imports = [ nixosModules.omarchy ] ++ lib.optional (homeManagerModule != null) homeManagerModule;

      omarchy = {
        enable = true;
        user = "omarchy";
        # The point: get past the greeter without a human at the keyboard.
        autoLogin = true;
      };

      users.users.omarchy = {
        isNormalUser = lib.mkDefault true;
        password = "omarchy";
        extraGroups = [ "wheel" ];
      };

      virtualisation = {
        graphics = true;
        memorySize = 6144;
        cores = 4;
        diskSize = 8192;
        # A virtio GPU *instead of* the default emulated card, not alongside it. Hyprland's
        # renderer opens a DRM node, which the default card does not expose — and leaving
        # both in place puts the compositor on one device while the screenshot is taken
        # from the other, which looks exactly like a compositor that failed to draw.
        qemu.options = [
          "-vga none"
          "-device virtio-gpu-pci"
        ];
      };

      environment.sessionVariables = {
        LIBGL_ALWAYS_SOFTWARE = "1";
        WLR_RENDERER_ALLOW_SOFTWARE = "1";
        # Hyprland refuses to start on a driver it does not recognise unless told the
        # missing hardware is expected.
        WLR_NO_HARDWARE_CURSORS = "1";
      };

      documentation.enable = lib.mkForce false;
    };

  enableOCR = true;

  testScript = ''
    machine.start()
    machine.wait_for_unit("graphical.target")

    # Autologin means sddm starts the session itself; the compositor is a user unit, so
    # wait on the process rather than on a system unit.
    machine.wait_until_succeeds("pgrep -f Hyprland", timeout=300)
    machine.sleep(30)
    machine.screenshot("hyprland")

    # omarchy-launch-shell is what Hyprland's autostart runs; quickshell is the shell.
    shell_up = machine.execute("pgrep -f quickshell")[0] == 0
    print(f"quickshell running: {shell_up}")
    if shell_up:
        machine.sleep(30)
        machine.screenshot("shell")

    print(f"OCR: {machine.get_screen_text_variants()!r}")

    # --- the generated theme ----------------------------------------------------
    # A theme name on its own proves nothing: the switcher writes that early and renders the
    # per-application colour files afterwards, so a switcher that ran without a usable PATH
    # leaves a named theme and no rendered files, and every application comes up unstyled
    # while looking, from the outside, like theming worked.
    theme_dir = "/home/omarchy/.local/state/omarchy/current/theme"
    rendered = machine.succeed(f"ls {theme_dir}").split()
    print(f"rendered theme files: {sorted(rendered)}")
    for name in ("alacritty.toml", "btop.theme", "foot.ini", "hyprland.lua", "shell.toml"):
        assert name in rendered, \
            f"{name} was not rendered into {theme_dir}; it holds {sorted(rendered)}"

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

    missing = [
        line
        for line in journal.splitlines()
        if ("not found" in line or "Process failed to start" in line)
        and not any(tool in line for tool in allowed_missing)
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
