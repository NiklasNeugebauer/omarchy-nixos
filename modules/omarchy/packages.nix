# The applications and command-line tools upstream pacstraps, as a system closure.
#
# `docs/omarchy-package-inventory.md` is the source of truth: every package below has a
# `ported` or `substituted` row there, and the lists are grouped to match its sections so
# the two can be diffed by eye after an upstream bump.
#
# Deliberately absent, because another module owns the option that installs them:
# pipewire and wireplumber (audio.nix); cups, cups-filters, avahi and the printer GUI
# (printing.nix); NetworkManager and the firewall (network.nix); Hyprland, uwsm, SDDM, the
# XDG portals and everything registered through `fonts.packages` (session.nix); Quickshell
# (shell.nix); Docker, bluez, fcitx5, plymouth, zram, plocate, gnome-keyring, gvfs, upower,
# power-profiles-daemon, thermald and the graphics drivers (system.nix). Adding one of those
# here would install the binary without the unit, service user or environment it needs.
{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.omarchy;

  # Tools the vendored `bin/omarchy-*` commands shell out to. Upstream gets most of these
  # for free as transitive pacman dependencies, so they are absent from its package lists
  # and their absence only shows up as a command that fails halfway through.
  omarchyRuntime = with pkgs; [
    coreutils
    gnugrep
    gnused
    gawk
    findutils
    diffutils
    util-linux # setsid, script, column, setpriv, rfkill
    procps # pgrep, pkill, pidwait
    psmisc
    file
    which
    bc
    curl
    rsync
    openssl
    zip
    unzip
    gnutar
    gzip
    libnotify # notify-send, for the commands that do not go through the shell's IPC
    desktop-file-utils
    shared-mime-info
    xdg-utils # xdg-open, xdg-mime, xdg-settings
    xdg-user-dirs
    glib # gsettings, gdbus
    gtk3 # gtk-update-icon-cache
    dconf
    # dbus-monitor, which omarchy-system-sleep-monitor execs to watch for the prepare-sleep
    # signal. Without it omarchy-sleep-lock.service restart-loops and the session never
    # locks before suspend.
    dbus
    # xkbcli, which the shell's keyboard-layout widget shells out to.
    libxkbcommon
  ];

  terminals = with pkgs; [
    foot
  ];

  shellTools = with pkgs; [
    bat
    btop
    dua
    eza
    fastfetch
    fd
    fzf
    gum
    cliamp
    herdr
    inetutils
    inotify-tools
    inxi
    jq
    less
    ripgrep
    socat
    starship
    tldr
    tmux
    try
    usage
    whois
    zoxide
    wl-clipboard
    wtype
  ];

  devTools = with pkgs; [
    git
    lazygit
    lazydocker
    clang
    llvm
    neovim
    mise
    tree-sitter
    lua5_1
    luarocks
    ruby
    dotnet-runtime
    autoconf-archive
    python3Packages.pygobject3
    python3Packages.poetry-core
  ];

  # Libraries upstream pacstraps by name because Arch packages them separately. Kept in the
  # system profile so a script or an interpreter that dlopen()s one finds it.
  libraries = with pkgs; [
    libsecret
    libyaml
    libpq
    libmysqlclient
    libpulseaudio
    vips
    gtk4-layer-shell
    egl-wayland
    webp-pixbuf-loader
  ];

  media = with pkgs; [
    grim
    slurp
    gpu-screen-recorder
    imagemagick
    ffmpegthumbnailer
    imv
    # Upstream pacstraps mpv-mpris beside mpv; in nixpkgs an mpv script is composed into
    # the wrapper rather than installed next to it, or the player never loads it.
    (mpv.override { scripts = [ mpvScripts.mpris ]; })
    obs-studio
    kdePackages.kdenlive
    pinta
    moonlight-qt
    yt-dlp
    zbar
    qrencode
    tesseract
    lsp-plugins # the LV2 limiter every shipped speaker tuning ends in
    alsa-utils
    pamixer
  ];

  gui = with pkgs; [
    chromium
    nautilus
    nautilus-python
    sushi
    gnome-disk-utility
    gnome-themes-extra
    yaru-theme
    evince
    libreoffice-stable
    obsidian
    localsend
    xournalpp
    udiskie
  ];

  # Hyprland's own side tools. The compositor, the session manager and the portals are
  # session.nix's; these are the utilities its keybinds and the share picker invoke.
  hyprlandTools = with pkgs; [
    hyprland-qtutils
    hyprland-preview-share-picker
    hyprpicker
    hyprsunset
  ];

  hardwareTools = with pkgs; [
    brightnessctl
    ddcutil
    dosfstools
    exfatprogs
    wireless-regdb
    tzupdate
  ];
in
{
  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      omarchyRuntime
      ++ terminals
      ++ shellTools
      ++ devTools
      ++ libraries
      ++ media
      ++ gui
      ++ hyprlandTools
      ++ hardwareTools;

    # Upstream pacstraps these as packages; NixOS has an option that installs them together
    # with the state they need, so the option is the honest translation.
    documentation.man.enable = true;
    programs.bash.completion.enable = true;

    # `omarchy-brightness-display` drives external monitors over DDC/CI, which reads and
    # writes the i2c character devices. The option also creates the group that may.
    hardware.i2c.enable = true;

    # obsidian is unfree, and a host that forgets this gets an eval error naming the
    # wrong thing. Fail early instead, with the reason. Read off the pkgs instance rather
    # than nixpkgs.config, because a flake that hands the system a pre-built pkgs (as this
    # one does) never populates nixpkgs.config at all.
    assertions = [
      {
        assertion = pkgs.config.allowUnfree or false;
        message = ''
          omarchy installs Obsidian, which is unfree. Allow it with
          nixpkgs.config.allowUnfree = true, or drop obsidian by overriding
          modules/omarchy/packages.nix.
        '';
      }
    ];
  };
}
