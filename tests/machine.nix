# The VM node the three checks share.
#
# One definition, because they differ only in how far they boot and how much they need to
# render: session.nix stops at multi-user with no GPU, greeter.nix reaches the login screen,
# desktop.nix logs in. Everything else — the module import, the omarchy options, the user —
# is the same, and three copies of it drift. They already had: one carried a software-
# rendering variable the other did not.
{ lib }:

{
  # `graphical` decides both whether qemu gets a GPU and whether the VM is allowed past
  # multi-user, because those two always go together here.
  nixosModules,
  homeManagerModule,
  graphical ? false,
  autoLogin ? true,
  memorySize ? 2048,
  cores ? 2,
  diskSize ? 4096,
}:

{ ... }:
{
  imports = [
    nixosModules.omarchy
    homeManagerModule
  ];

  omarchy = {
    enable = true;
    user = "omarchy";
    inherit autoLogin;
  };

  # mkDefault throughout so a definition in modules/omarchy/* wins instead of colliding.
  users.users.omarchy = {
    isNormalUser = lib.mkDefault true;
    extraGroups = [ "wheel" ];
    # Only where a greeter has to accept it. The non-graphical check drives the VM as root
    # over the test driver's backdoor and needs no password at all.
    password = lib.mkIf graphical "omarchy";
  };

  # Nothing here reads a man page, and building them for every run is minutes per test.
  documentation.enable = lib.mkForce false;

  virtualisation = {
    inherit memorySize cores diskSize;
    graphics = graphical;
    qemu.options = lib.mkIf graphical [
      # A virtio GPU *instead of* the default emulated card, not alongside it. Hyprland's
      # renderer opens a DRM node, which the default card does not expose — and leaving both
      # in place puts the compositor on one device while the screenshot is taken from the
      # other, which looks exactly like a compositor that failed to draw.
      "-vga none"
      "-device virtio-gpu-pci"
    ];
  };

  # No GPU to pass through, so Mesa's software rasteriser serves both the greeter's
  # compositor and Hyprland. Named explicitly to avoid a fallback to a driver that is not
  # there, which presents as a blank screen with nothing in the journal.
  environment.sessionVariables = lib.mkIf graphical {
    LIBGL_ALWAYS_SOFTWARE = "1";
    WLR_RENDERER_ALLOW_SOFTWARE = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
  };

  # Without a GPU the greeter cannot render, so a non-graphical check must not wait on it.
  systemd.defaultUnit = lib.mkIf (!graphical) (lib.mkForce "multi-user.target");
}
