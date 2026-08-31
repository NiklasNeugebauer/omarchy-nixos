# $HOME, which upstream fills from /etc/skel at `useradd -m` time and then never again.
#
# home-manager replaces that seeding, but not uniformly, because upstream's own design
# splits the tree in two:
#
#   * Shipped defaults the user is not meant to hand-edit. Upstream's answer to a user who
#     changed one is `omarchy-reinstall-configs`, which copies /etc/skel back over $HOME.
#     Here they are store symlinks, so they are always the shipped default and the resync
#     command has nothing left to do.
#
#   * Files upstream explicitly invites the user to own — the Hyprland override modules
#     ("Put your personal overrides in these files"), the menu and hook extensions, the
#     runtime toggles, and the git identity. A read-only store symlink would break the
#     documented workflow, so these are seeded once if absent and then left alone. That is
#     the same contract /etc/skel has, and it is the one deliberate non-declarative corner
#     of this port; see docs/divergences.md.
{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.omarchy;
  omarchyPath = "${cfg.package}/share/omarchy";

  # Listed from the package's own pinned source, not from its output: the source is already
  # a realised store path, so evaluation never has to build the derivation to learn what is
  # in it. A config directory added upstream is picked up on the next pin bump with no edit
  # here — but read the classification below before assuming the default is right for it.
  upstreamSrc = cfg.package.src;

  configEntries = builtins.attrNames (builtins.readDir "${upstreamSrc}/config");

  # Seeded once if absent, then never touched again. Two different reasons, both of which
  # rule out a read-only store symlink:
  #
  #   * upstream tells the user to edit the file ("Put your personal overrides in these
  #     files"), and a symlink into the store would make that impossible;
  #   * the application rewrites its own config — btop and xournalpp save settings on exit,
  #     chromium and obsidian own their whole Electron profile directories, and fcitx5's
  #     config tool and lazygit write back what the user changes in their UI. A symlinked
  #     directory turns every one of those into a silent write failure, and a symlinked file
  #     into a lost setting.
  seeded = [
    "hypr"
    "omarchy"
    "git"
    "btop"
    "chromium"
    "fcitx5"
    "lazygit"
    "obsidian"
    "opencode"
    "xournalpp"
  ];

  # Configured system-wide by another module instead, so linking it here would be a second
  # copy of the same policy that only applies to one user.
  systemOwned = [ "wireplumber" ];

  # Everything else: a shipped default the user is not meant to hand-edit. Upstream's answer
  # to a user who changed one is omarchy-reinstall-configs, which copies the shipped tree
  # back. A store symlink is permanently that shipped tree, so the resync has nothing to do.
  shippedDefaults = lib.subtractLists (seeded ++ systemOwned) configEntries;

  # home-manager activation runs with a minimal PATH of its own, so anything it invokes from
  # the vendored tree has to be handed one. omarchy-theme-set takes a flock, renders its
  # templates by calling omarchy-theme-set-templates as a sibling command, and shells out to
  # the usual text tools; without this it half-succeeds — writing the theme name and the
  # background while silently rendering none of the terminal, GTK or shell colour files.
  activationPath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.util-linux
    pkgs.gnused
    pkgs.gnugrep
    pkgs.gawk
    pkgs.findutils
    pkgs.bash
    pkgs.jq
    pkgs.imagemagick
  ];

  # Desktop entries have to sit directly in ~/.local/share/applications for XDG to see
  # them, so they are linked one by one rather than as a directory.
  desktopEntries = lib.filter (name: lib.hasSuffix ".desktop" name) (
    builtins.attrNames (builtins.readDir "${upstreamSrc}/applications")
  );
in
{
  config = lib.mkIf cfg.enable {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;

      users.${cfg.user} = homeArgs: {
        home.stateVersion = config.system.stateVersion;

        xdg.enable = true;

        # Shipped defaults, straight from the vendored tree.
        xdg.configFile =
          lib.listToAttrs (
            map (entry: {
              name = entry;
              value.source = "${omarchyPath}/config/${entry}";
            }) shippedDefaults
          )
          // {
            # btop reads its theme from a fixed filename while the theme switcher rewrites
            # what the state directory points at, so this has to stay a live symlink rather
            # than a store path resolved at build time. It can only sit beside a seeded
            # btop.conf, not inside a store-symlinked btop directory.
            "btop/themes/current.theme".source =
              homeArgs.config.lib.file.mkOutOfStoreSymlink "${homeArgs.config.home.homeDirectory}/.local/state/omarchy/current/theme/btop.theme";
          };

        home.file = {
          # Nautilus gains its LocalSend and transcode actions from these.
          ".local/share/nautilus-python/extensions".source =
            "${omarchyPath}/default/nautilus-python/extensions";

          # Upstream symlinks the shipped agent skills into every agent's skills directory
          # so a pin bump updates them in place.
          ".claude/skills/omarchy".source = "${omarchyPath}/default/agents/skills/omarchy";
          ".claude/skills/diagnose-crash".source = "${omarchyPath}/default/agents/skills/diagnose-crash";
          ".agents/skills/omarchy".source = "${omarchyPath}/default/agents/skills/omarchy";
          ".agents/skills/diagnose-crash".source = "${omarchyPath}/default/agents/skills/diagnose-crash";

          # Upstream's XCompose sequences, included rather than copied so a pin bump
          # carries new sequences and anything the user adds above the include survives.
          ".XCompose".text = ''
            include "${omarchyPath}/default/xcompose"
          '';
        }
        // lib.listToAttrs (
          map (entry: {
            name = ".local/share/applications/${entry}";
            value.source = "${omarchyPath}/applications/${entry}";
          }) desktopEntries
        );

        # Upstream's ~/.bashrc sources default/bash/rc for aliases, functions, the prompt
        # and its inputrc. Composed into home-manager's bashrc instead of replacing it, so
        # home-manager's own session-variable and package plumbing still applies.
        # default/bash/init and default/bash/shell source fzf's and bash-completion's
        # integration from /usr/share, which does not exist here. Both files guard the
        # source with a -f test, so they no-op silently; home-manager wires up the same
        # integrations from the store instead.
        programs.bash = {
          enable = true;
          enableCompletion = true;

          # Above the interactive guard, which is where upstream's own .bashrc puts it: an
          # `ssh host omarchy-…` runs no interactive rc, and without this it has no
          # $OMARCHY_PATH and no omarchy-* on PATH.
          bashrcExtra = ''
            source "${omarchyPath}/default/bash/env-bootstrap"
          '';

          initExtra = ''
            source "${omarchyPath}/default/bash/rc"
          '';
        };

        programs.fzf = {
          enable = true;
          enableBashIntegration = true;
        };

        programs.starship = {
          enable = true;
          enableBashIntegration = true;
        };

        # Seeded once, then the user's. `install -D` creates the parent and never clobbers,
        # which is exactly what /etc/skel does at user creation.
        home.activation.omarchySeedUserFiles = homeArgs.lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          seed() {
            local src=$1 dest=$2
            if [[ ! -e $dest ]]; then
              run mkdir -p "$(dirname "$dest")"
              run install -m "$(stat -c %a "$src")" "$src" "$dest"
            fi
          }

          seed_tree() {
            local src=$1 dest=$2 entry
            while IFS= read -r -d "" entry; do
              seed "$entry" "$dest/''${entry#"$src"/}"
            done < <(find "$src" -type f -print0)
          }

          ${lib.concatMapStringsSep "\n" (dir: ''
            seed_tree ${omarchyPath}/config/${dir} "$HOME/.config/${dir}"
          '') seeded}

          # Hyprland's runtime toggle flags, which the compositor rewrites in place.
          seed_tree ${omarchyPath}/default/hypr/toggles \
            "$HOME/.local/state/omarchy/toggles/hypr"

          seed ${omarchyPath}/default/tensaku/state.toml \
            "$HOME/.local/state/tensaku/state.toml"

          seed ${omarchyPath}/logo.txt "$HOME/.config/omarchy/branding/about.txt"
          seed ${omarchyPath}/logo.txt "$HOME/.config/omarchy/branding/screensaver.txt"
        '';

        # First login has no theme yet, and every generated theme file — the terminal
        # colours, the shell palette, the GTK and btop themes, the Hyprland colour module —
        # comes from running the switcher once. Headless because activation has no session
        # to notify.
        home.activation.omarchySetInitialTheme =
          homeArgs.lib.hm.dag.entryAfter [ "omarchySeedUserFiles" ]
            ''
              if [[ ! -s $HOME/.local/state/omarchy/current/theme.name ]]; then
                run env \
                  PATH="${activationPath}:${omarchyPath}/bin" \
                  OMARCHY_PATH=${omarchyPath} \
                  OMARCHY_THEME_HEADLESS=1 \
                  ${omarchyPath}/bin/omarchy-theme-set ${lib.escapeShellArg cfg.theme} || true
              fi
            '';
      };
    };
  };
}
