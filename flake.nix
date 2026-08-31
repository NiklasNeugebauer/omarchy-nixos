{
  description = "The Omarchy desktop on a NixOS base — upstream vendored, not forked";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The upstream desktop, consumed as a source tree. Bumped on its own, never in the
    # same commit as nixpkgs — see scripts/sync-upstream.md.
    omarchy = {
      url = "github:basecamp/omarchy";
      flake = false;
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      home-manager,
      disko,
      omarchy,
      ...
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;

      # Our packages, as an overlay so hosts and `nix build` see the same tree.
      overlay = import ./pkgs { omarchySrc = omarchy; };

      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          overlays = [ overlay ];
          config.allowUnfree = true;
        };

      mkHost =
        { system, host }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            { nixpkgs.pkgs = pkgsFor system; }
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            self.nixosModules.omarchy
            host
          ];
        };
    in
    {
      overlays.default = overlay;

      nixosModules = {
        omarchy = ./modules;
        default = ./modules;
      };

      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          inherit (pkgs) omarchy;
          default = pkgs.omarchy;
        }
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
          # Boots a VM to a rendered greeter and saves screenshots. Deliberately a package
          # and not a check: it needs a graphics-capable VM, so CI cannot run it, but it is
          # the only automated look at whether the desktop draws at all.
          greeter-screenshots = pkgs.callPackage ./tests/greeter.nix {
            inherit (self) nixosModules;
            homeManagerModule = home-manager.nixosModules.home-manager;
          };
        }
      );

      nixosConfigurations = {
        # Smoke-test target. Plain disk, autologin, no encryption — never installed to metal.
        omarchy-vm = mkHost {
          system = "x86_64-linux";
          host = ./hosts/omarchy-vm;
        };

        # Generic encrypted laptop. Copy this directory for a real machine and drop in
        # the hardware scan plus the disk's by-id path.
        omarchy-laptop = mkHost {
          system = "x86_64-linux";
          host = ./hosts/omarchy-laptop;
        };
      };

      checks = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          omarchy-package = pkgs.omarchy;
        }
        // nixpkgs.lib.optionalAttrs (system == "x86_64-linux") {
          vm-toplevel = self.nixosConfigurations.omarchy-vm.config.system.build.toplevel;
          session = pkgs.callPackage ./tests/session.nix {
            inherit (self) nixosModules;
            homeManagerModule = home-manager.nixosModules.home-manager;
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              nixfmt
              statix
              deadnix
              jq
              shellcheck
            ];
          };
        }
      );

      # nixfmt-tree rather than nixfmt itself: `nix fmt` hands the formatter a path, and
      # bare nixfmt only accepts files.
      formatter = forAllSystems (system: (pkgsFor system).nixfmt-tree);
    };
}
