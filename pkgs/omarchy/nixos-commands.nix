# Upstream commands whose whole job is Arch machinery. Each is replaced in the vendored
# tree by a stub that fails loudly with the NixOS equivalent, so a caller never silently
# gets a no-op and a user never gets a confusing pacman error.
#
# Keeping the command present (rather than deleting it) matters: the CLI router discovers
# commands by filename, the metadata lint expects a summary header, and several commands
# call each other.
#
# Commands that are genuinely reimplemented live in ./commands/ instead.
{
  # Package management. Every `omarchy install …` command funnels through pkg-add, so
  # these few entries cover the whole family.
  omarchy-pkg-add = "add the package to environment.systemPackages and run: omarchy update";
  omarchy-pkg-drop = "remove the package from environment.systemPackages and run: omarchy update";
  omarchy-pkg-install = "search at https://search.nixos.org, then add it to environment.systemPackages";
  omarchy-pkg-remove = "remove the package from environment.systemPackages and run: omarchy update";
  omarchy-pkg-aur-add = "there is no AUR; look for the package in nixpkgs or write a derivation under pkgs/";
  omarchy-pkg-aur-install = "there is no AUR; look for the package in nixpkgs or write a derivation under pkgs/";
  omarchy-reinstall-pkgs = "run: omarchy update";
  omarchy-refresh-pacman = "there is no pacman; nixpkgs is pinned by flake.lock";

  # Update internals. `omarchy update` is reimplemented; these are its pacman-side steps.
  omarchy-update-system-pkgs = "run: omarchy update";
  omarchy-update-system-pkgs-when-conflicted = "run: omarchy update";
  omarchy-update-aur-pkgs = "there is no AUR";
  omarchy-update-keyring = "nixpkgs is verified by flake.lock hashes, not a pacman keyring";
  omarchy-update-orphan-pkgs = "unreferenced store paths are removed by: nix-collect-garbage -d";
  omarchy-update-pkg-prune = "clean the store with: nix-collect-garbage -d";
  omarchy-update-pacman-guard = "there is no pacman";
  omarchy-version-pkgs = "inspect the flake with: nix flake metadata";
  omarchy-version-channel = "the release is whatever the omarchy input in flake.lock points at";
  omarchy-channel-current = "the release is whatever the omarchy input in flake.lock points at";
  omarchy-channel-set = "change the omarchy input's ref in flake.nix, then run: omarchy update";
  omarchy-upgrade-to-quattro = "version-to-version upgrade paths do not apply; rebuild from the flake";

  # Boot and rollback. NixOS generations replace the Limine + Snapper snapshot story.
  omarchy-refresh-limine = "the bootloader is configured declaratively in the host's NixOS config";
  omarchy-plymouth-set = "set boot.plymouth options in the host's NixOS config";
  omarchy-hibernation-setup = "set the resume device and swap in the host's NixOS config";
  omarchy-hibernation-remove = "remove the swap device from the host's NixOS config";
  omarchy-hibernation-available = "hibernation availability follows the swap declared in the NixOS config";
  omarchy-system-factory-reset = "reinstall from the flake";
  omarchy-system-factory-reset-finish = "reinstall from the flake";

  # Install-time machinery that only ever ran from the Arch ISO.
  omarchy-provision-owner = "users are declared in the host's NixOS config";
  omarchy-provision-user = "the user's home is managed by home-manager";
  omarchy-reinstall-configs = "run: home-manager switch, or omarchy update";
  omarchy-dev-pkg-test = "build the package with: nix build .#omarchy";

  # Pointing OMARCHY_PATH elsewhere is how this port works in the first place; letting a
  # user rewrite /etc/omarchy.conf by hand would desync it from the built system.
  omarchy-dev-link = "OMARCHY_PATH already points at the store; override omarchy.package in the NixOS config to build from a checkout";
  omarchy-dev-unlink = "OMARCHY_PATH is set by the NixOS module and cannot be unlinked";
}
