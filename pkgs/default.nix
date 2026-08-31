# Overlay carrying everything this repo adds to nixpkgs.
#
# `omarchySrc` is the pinned upstream tree from the flake input, threaded in here so the
# overlay stays usable standalone:
#   nixpkgs.overlays = [ (import ./pkgs { omarchySrc = <omarchy tree>; }) ];
{ omarchySrc }:

final: prev: {
  omarchy = final.callPackage ./omarchy { src = omarchySrc; };

  # Quickshell comes from nixpkgs unchanged. Upstream omarchy pins no version, and the
  # QML modules its shell imports (Networking, Bluetooth, Services.Polkit) are all present
  # in nixpkgs' 0.3.x. If a module ever goes missing, override here and log it in
  # docs/divergences.md rather than patching the vendored shell.
}
