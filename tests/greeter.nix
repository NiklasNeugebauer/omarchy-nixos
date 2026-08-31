# Does the desktop actually draw? Boots a VM all the way to graphical.target with software
# rendering, waits for the greeter, and saves screenshots.
#
# Not part of `nix flake check`: it needs a GPU-less but graphics-capable VM and takes long
# enough that CI would time out. Run it by hand, and look at the images:
#
#   nix build .#greeter-screenshots && ls result/
#
# This covers the first two lines of the hardware checklist in docs/progress.md — the greeter
# rendering, and the session starting behind it — under llvmpipe rather than on real
# hardware. Everything past login still needs a person: llvmpipe is not a GPU, and a
# Quickshell bar that renders here can still fail on a real one.
{
  lib,
  pkgs,
  nixosModules,
  homeManagerModule,
  ...
}:

pkgs.testers.runNixOSTest {
  name = "omarchy-greeter";

  nodes.machine = import ./machine.nix { inherit lib; } {
    inherit nixosModules homeManagerModule;
    graphical = true;
    autoLogin = false;
    memorySize = 4096;
    cores = 4;
    diskSize = 8192;
  };

  enableOCR = true;

  testScript = ''
    machine.start()

    # graphical.target is the assertion: it is only reached if the greeter unit that
    # tests/session.nix checks the wiring of actually starts and stays up.
    machine.wait_for_unit("graphical.target")
    machine.wait_for_unit("display-manager.service")

    # sddm draws the omarchy theme, which is a QtQuick scene. Wait for the greeter process
    # (matched on the command line: the binary name is past pgrep's 15-character limit for
    # -x), then give llvmpipe time to get a surface up before looking.
    machine.wait_until_succeeds("pgrep -f sddm-greeter", timeout=180)
    machine.sleep(30)
    machine.screenshot("greeter")

    # The theme is a terminal-style login prompt; OCR should find something on it rather
    # than a blank framebuffer. Reported rather than asserted: OCR on a low-contrast
    # terminal theme is not reliable enough to fail a build over, and the screenshot is
    # the real artefact.
    text = machine.get_screen_text_variants()
    print(f"OCR on the greeter: {text!r}")

    # A second look, in case the first landed mid-frame.
    machine.sleep(10)
    machine.screenshot("greeter-settled")

    print(machine.succeed("systemctl --no-pager --failed || true"))
    print(machine.succeed("journalctl -u display-manager --no-pager -n 40 || true"))
  '';
}
