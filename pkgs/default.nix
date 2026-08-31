# Overlay carrying everything this repo adds to nixpkgs.
#
# `omarchySrc` is the pinned upstream tree from the flake input, threaded in here so the
# overlay stays usable standalone:
#   nixpkgs.overlays = [ (import ./pkgs { omarchySrc = <omarchy tree>; }) ];
{ omarchySrc }:

final: prev: {
  omarchy = final.callPackage ./omarchy { src = omarchySrc; };

  # Quickshell otherwise comes from nixpkgs unchanged: upstream omarchy pins no version, and
  # the QML modules its shell imports (Networking, Bluetooth, Services.Polkit) are all built
  # by default in nixpkgs' 0.3.x.
  #
  # The one addition is an image-format plugin. quickshell is wrapped by wrapQtAppsHook,
  # which pins QT_PLUGIN_PATH to quickshell's own closure, so a plugin package in the system
  # profile is invisible to it. 79 of the shipped theme backgrounds are WebP and Qt has no
  # built-in reader for it, so without this most stock themes come up with no background at
  # all — and nothing fails, which is why it has to be stated here rather than discovered.
  quickshell = prev.quickshell.overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ final.qt6.qtimageformats ];
  });
}
