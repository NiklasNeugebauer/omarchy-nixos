# The omarchy-nixos NixOS module.
#
# Everything upstream does from `install/config/*.sh`, `install/hardware/*.sh` and its
# `etc/**` drop-ins is expressed here as NixOS options — porting step 8. Nothing in this
# tree executes an upstream install script at runtime.
{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.omarchy;
in
{
  imports = [
    ./omarchy/system.nix
    ./omarchy/network.nix
    ./omarchy/audio.nix
    ./omarchy/printing.nix
    ./omarchy/session.nix
    ./omarchy/shell.nix
    ./omarchy/packages.nix
    ./omarchy/home.nix
  ];

  options.omarchy = {
    enable = lib.mkEnableOption "the Omarchy desktop";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.omarchy;
      defaultText = lib.literalExpression "pkgs.omarchy";
      description = ''
        The vendored upstream tree. `$OMARCHY_PATH` resolves into
        `''${package}/share/omarchy`, and every `omarchy-*` command comes from here.

        Overriding this is supported, but `modules/omarchy/home.nix` reads the package's own
        `src` with `builtins.readDir` to learn which config directories upstream ships. That
        is free when `src` is an already-fetched flake input, and becomes an
        import-from-derivation — which `nix flake check --no-build` refuses — if it is
        replaced by something that has to be built or fetched at evaluation time.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      description = ''
        The desktop's primary user. Gets the home-manager configuration, the audio,
        video, input and network groups, and the autologin session if that is enabled.
      '';
    };

    theme = lib.mkOption {
      type = lib.types.str;
      default = "Tokyo Night";
      description = ''
        Theme applied on first login, by name as `omarchy theme set` takes it. Switching
        later is a runtime action and is not tracked here.
      '';
    };

    flake = lib.mkOption {
      type = lib.types.str;
      default = "/etc/nixos";
      description = ''
        Where this repo lives on the target. `omarchy update` rebuilds from it.

        A path the user cannot write to still works, but `omarchy update` then skips the
        input bump and only rebuilds — updating `flake.lock` is a write. Point this at a
        checkout in the user's home to get the whole command.
      '';
    };

    autoLogin = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Log `omarchy.user` straight into the session without a password prompt. Only
        sensible on a disposable VM: it defeats disk-independent access control.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Extra system packages, on top of the translated upstream lists.";
    };
  };

  config = lib.mkIf cfg.enable {
    # `omarchy update` and `omarchy version` read these.
    environment.etc."omarchy-nixos.conf".text = ''
      OMARCHY_NIXOS_FLAKE=${cfg.flake}
      OMARCHY_NIXOS_REV=${
        if config.system.configurationRevision == null then "dirty" else config.system.configurationRevision
      }
    '';

    # Upstream's env-bootstrap forces $OMARCHY_PATH to the packaged location when
    # /etc/omarchy.conf is absent, and porting step 5 made the packaged location this
    # store path — so login shells and the uwsm session agree without further help.
    # Exporting it here as well covers what never sources a bash rc: systemd user units,
    # and anything launched straight from the compositor.
    environment.sessionVariables.OMARCHY_PATH = "${cfg.package}/share/omarchy";

    environment.systemPackages = [ cfg.package ] ++ cfg.extraPackages;

    # Nothing here writes /etc/omarchy.conf. Upstream reads its presence as a dev link, and
    # porting step 5 already made the store path the packaged location, so the file has no
    # job to do — but a hand-written one would still be sourced by env-bootstrap and would
    # outrank the built system. That is why `omarchy dev link`, which is what writes it, is
    # stubbed rather than left working.
  };
}
