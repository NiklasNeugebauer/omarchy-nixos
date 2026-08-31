# Package inventory

Every entry in upstream's two pacstrap lists — `install/omarchy-base.packages` and `install/omarchy-other.packages` — with what it became on NixOS. This file is the source of truth for `modules/omarchy/packages.nix`: a package appears in that module only if it has a `ported` or `substituted` row here, and a row here that no module acts on is a bug in one or the other.

Re-checked on every upstream bump. `scripts/sync-upstream.md` says how: diff the two `.packages` files, then add, retire or reclassify rows to match. A new upstream entry with no row is the signal that a bump needs work.

Status meanings:

- **ported** — a nixpkgs attribute exists under the same or an obvious name.
- **substituted** — the capability is there, but the name or the shape differs. NixOS often expresses it as an option rather than a package; the note names the option.
- **dropped** — Arch machinery with no NixOS meaning. The note says what replaces the *need*, not the package.
- **unavailable** — genuinely not packaged for Nix. The note says what is lost.

Attributes were confirmed against the nixpkgs revision `flake.lock` pins. Where a row names a NixOS option instead of an attribute, the option is what `modules/omarchy/` sets.

## Desktop core

| upstream (Arch) | nixpkgs attribute | status | note |
| --- | --- | --- | --- |
| `hyprland` | `hyprland` | ported | Set through `programs.hyprland`, not `systemPackages`. |
| `hyprland-guiutils` | `hyprland-qtutils` | substituted | Renamed upstream of Arch; provides the same `hyprland-dialog` / update-screen helpers. |
| `hyprland-preview-share-picker` | `hyprland-preview-share-picker` | ported | |
| `hyprpicker` | `hyprpicker` | ported | |
| `hyprsunset` | `hyprsunset` | ported | |
| `quickshell` | `quickshell` | ported | Owned by `modules/omarchy/shell.nix`. |
| `uwsm` | `uwsm` | substituted | `programs.uwsm`; the session entry point, not a plain package. |
| `sddm` | `kdePackages.sddm` | substituted | Top-level `sddm` is gone; set through `services.displayManager.sddm`. |
| `xdg-desktop-portal-gtk` | `xdg-desktop-portal-gtk` | substituted | `xdg.portal.extraPortals`. |
| `xdg-desktop-portal-hyprland` | `xdg-desktop-portal-hyprland` | substituted | `xdg.portal.extraPortals`. |
| `xdg-terminal-exec` | `xdg-terminal-exec` | ported | `$TERMINAL` resolves through it. |
| `plymouth` | `plymouth` | substituted | `boot.plymouth`; upstream's branded theme ships in the vendored tree. |
| `gnome-keyring` | `gnome-keyring` | substituted | `services.gnome.gnome-keyring`, plus the PAM hook. |
| `libsecret` | `libsecret` | ported | |
| `gvfs-mtp`, `gvfs-nfs`, `gvfs-smb` | `gvfs` | substituted | One gvfs build in nixpkgs covers all backends; enabled via `services.gvfs`. |
| `udiskie` | `udiskie` | ported | Autostarted from the session, as upstream does. |
| `power-profiles-daemon` | `power-profiles-daemon` | substituted | `services.power-profiles-daemon`. |
| `qt6-imageformats` | `qt6.qtimageformats` | substituted | Namespaced under the Qt 6 set. |
| `qt6-wayland` | `qt6.qtwayland` | substituted | Namespaced under the Qt 6 set. |
| `gtk4-layer-shell` | `gtk4-layer-shell` | ported | |
| `egl-wayland` | `egl-wayland` | ported | |
| `gnome-themes-extra` | `gnome-themes-extra` | ported | |
| `yaru-icon-theme` | `yaru-theme` | substituted | nixpkgs ships the icon, GTK and sound themes as one package. |
| `webp-pixbuf-loader` | `webp-pixbuf-loader` | ported | |
| `fontconfig` | `fontconfig` | substituted | `fonts.fontconfig`; upstream's `50-omarchy.conf` is applied as a fontconfig drop-in. |
| `fcitx5`, `fcitx5-gtk`, `fcitx5-qt` | `fcitx5` and friends | substituted | `i18n.inputMethod.type = "fcitx5"` wires the daemon, the module set and the environment together. |

## Terminals

| upstream (Arch) | nixpkgs attribute | status | note |
| --- | --- | --- | --- |
| `foot` | `foot` | ported | The default terminal. |

Upstream ships configs for Ghostty, Kitty and Alacritty too (`config/ghostty`, `config/kitty`, `config/alacritty`) without pacstrapping them; `omarchy-install-terminal` adds one on demand. Those three are left out of the system closure for the same reason, and are one line in `omarchy.extraPackages` for anyone who wants them.

## Shell tools

| upstream (Arch) | nixpkgs attribute | status | note |
| --- | --- | --- | --- |
| `bash-completion` | `bash-completion` | substituted | `programs.bash.completion`. |
| `bat` | `bat` | ported | |
| `btop` | `btop` | ported | Themed from the active omarchy theme. |
| `dua-cli` | `dua` | substituted | The Arch package name carries the `-cli` suffix; the attribute does not. |
| `eza` | `eza` | ported | |
| `fastfetch` | `fastfetch` | ported | |
| `fd` | `fd` | ported | |
| `fzf` | `fzf` | ported | Drives every picker in the CLI. |
| `gum` | `gum` | ported | Load-bearing: 42 files in `bin/` prompt through it. |
| `herdr` | `herdr` | ported | Basecamp's terminal workspace manager, and in nixpkgs. |
| `inetutils` | `inetutils` | ported | |
| `inotify-tools` | `inotify-tools` | ported | |
| `inxi` | `inxi` | ported | |
| `jq` | `jq` | ported | Load-bearing: 77 files. |
| `less` | `less` | ported | |
| `man-db` | `man-db` | substituted | `documentation.man`. |
| `plocate` | `plocate` | substituted | `services.locate` owns the index and its timer. |
| `ripgrep` | `ripgrep` | ported | |
| `socat` | `socat` | ported | Shell IPC transport. |
| `starship` | `starship` | ported | Themed from the active omarchy theme. |
| `tldr` | `tldr` | ported | |
| `tmux` | `tmux` | ported | Themed from the active omarchy theme. |
| `tobi-try` | `try` | substituted | Arch prefixes the author; the attribute is the upstream project name. |
| `unzip` | `unzip` | ported | |
| `usage` | `usage` | ported | mise's spec tool; mise shells out to it. |
| `whois` | `whois` | ported | |
| `zoxide` | `zoxide` | ported | |
| `wl-clipboard` | `wl-clipboard` | ported | `wl-copy` / `wl-paste`, used across the clipboard commands. |
| `wtype` | `wtype` | ported | Synthetic typing for the emoji and clipboard pickers. |

## Media and graphics

| upstream (Arch) | nixpkgs attribute | status | note |
| --- | --- | --- | --- |
| `grim` | `grim` | ported | |
| `slurp` | `slurp` | ported | |
| `gpu-screen-recorder` | `gpu-screen-recorder` | ported | |
| `imagemagick` | `imagemagick` | ported | Provides `magick`; the `convert` alias is deprecated but present. |
| `libvips` | `vips` | substituted | Attribute drops the `lib` prefix. |
| `ffmpegthumbnailer` | `ffmpegthumbnailer` | ported | Nautilus video thumbnails. |
| `imv` | `imv` | ported | Default image viewer. |
| `mpv` | `mpv` | ported | |
| `mpv-mpris` | `mpvScripts.mpris` | substituted | Composed into the mpv wrapper (`mpv.override { scripts = […]; }`) rather than installed alongside it, which is the only way the player loads it. |
| `obs-studio` | `obs-studio` | ported | |
| `kdenlive` | `kdePackages.kdenlive` | substituted | Moved into the KDE package set. |
| `pinta` | `pinta` | ported | |
| `moonlight-qt` | `moonlight-qt` | ported | |
| `yt-dlp` | `yt-dlp` | ported | |
| `zbar` | `zbar` | ported | `zbarimg`, for the QR-code reader. |
| `qrencode` | `qrencode` | ported | |
| `tesseract` | `tesseract` | ported | |
| `tesseract-data-eng` | — | dropped | nixpkgs' `tesseract` bundles the language data; there is no separate data package to add. |
| `lsp-plugins-lv2` | `lsp-plugins` | substituted | One package, LV2 included. |

## GUI applications

| upstream (Arch) | nixpkgs attribute | status | note |
| --- | --- | --- | --- |
| `chromium` | `chromium` | ported | Default browser. Upstream's `chromium-flags.conf` loads two extensions out of the vendored tree; those paths were rewritten to the store path at package build. |
| `nautilus` | `nautilus` | ported | |
| `nautilus-python` | `nautilus-python` | ported | Carries upstream's Nautilus extensions. |
| `sushi` | `sushi` | ported | Nautilus quick preview. |
| `gnome-disk-utility` | `gnome-disk-utility` | ported | |
| `evince` | `evince` | ported | |
| `libreoffice-fresh` | `libreoffice-stable` | ported | |
| `obsidian` | `obsidian` | ported | Unfree; the host must allow it. |
| `localsend` | `localsend` | ported | The firewall opens 53317 for it. |
| `xournalpp` | `xournalpp` | ported | |
| `system-config-printer` | `system-config-printer` | ported | Owned by `modules/omarchy/printing.nix`. |

## Development tooling

| upstream (Arch) | nixpkgs attribute | status | note |
| --- | --- | --- | --- |
| `git` | `git` | ported | |
| `lazygit` | `lazygit` | ported | |
| `lazydocker` | `lazydocker` | ported | |
| `docker`, `docker-buildx`, `docker-compose` | — | substituted | `virtualisation.docker` with `daemon.settings` from upstream's `etc/docker/daemon.json`, and the compose/buildx plugins as `docker.extraPackages`. |
| `clang` | `clang` | ported | |
| `llvm` | `llvm` | ported | |
| `nvim` | `neovim` | substituted | Arch's short name; nixpkgs spells it out. |
| `omarchy-nvim` | — | dropped | An Arch package built from upstream's own repo to seed `/etc/skel`. The Neovim config belongs in home-manager, not in a package. |
| `mise-bin` | `mise` | substituted | Arch splits a prebuilt-binary variant; nixpkgs has one. |
| `tree-sitter-cli` | `tree-sitter` | substituted | The attribute is the whole project, CLI included. |
| `lua51` | `lua5_1` | substituted | Nix spells the version with an underscore. Hyprland's Lua config needs it. |
| `luarocks` | `luarocks` | ported | |
| `ruby` | `ruby` | ported | |
| `python-gobject` | `python3Packages.pygobject3` | substituted | Namespaced under the Python set; needed by upstream's Nautilus extensions. |
| `python-poetry-core` | `python3Packages.poetry-core` | substituted | Namespaced under the Python set. |
| `dotnet-runtime` | `dotnet-runtime` | ported | |
| `libyaml` | `libyaml` | ported | |
| `postgresql-libs` | `libpq` | substituted | nixpkgs splits the client library out of the server package. |
| `mariadb-libs` | `libmysqlclient` | substituted | Resolves to `mariadb-connector-c`. |
| `autoconf-archive` | `autoconf-archive` | ported | |
| `base-devel` | — | dropped | A toolchain metapackage for building AUR packages. Builds happen in the Nix sandbox from `nativeBuildInputs`. |
| `base` | — | dropped | Arch's base metapackage. NixOS' minimal profile is the equivalent and is not a package. |
| `fakeroot` | — | dropped | Only needed by `makepkg`. |

## Networking

| upstream (Arch) | nixpkgs attribute | status | note |
| --- | --- | --- | --- |
| `networkmanager` | `networkmanager` | substituted | `networking.networkmanager`, with upstream's Wi-Fi-powersave drop-in as a config setting. |
| `nss-mdns` | `nssmdns` | substituted | Enabled through `services.avahi.nssmdns4`, not installed by hand. |
| `avahi` | `avahi` | substituted | `services.avahi`. |
| `ufw` | — | substituted | `networking.firewall` (nftables). Upstream's default-deny plus 53317 is expressed as options; see `modules/omarchy/network.nix`. |
| `ufw-docker` | — | dropped | A shell script that rewrites ufw's `after.rules` so Docker's own iptables rules stop bypassing the firewall. The NixOS firewall and Docker's chain are composed by the module instead. |
| `wireless-regdb` | `wireless-regdb` | substituted | `hardware.wirelessRegulatoryDatabase`. |
| `tzupdate` | `tzupdate` | ported | Upstream's sudoers drop-in for it is translated to a `security.sudo` rule. |
| `bluez`, `bluez-tools`, `bluez-utils` | `bluez`, `bluez-tools` | substituted | `hardware.bluetooth`; nixpkgs folds `bluez-utils` into `bluez`. |

## Audio

| upstream (Arch) | nixpkgs attribute | status | note |
| --- | --- | --- | --- |
| `pipewire`, `pipewire-alsa`, `pipewire-jack`, `pipewire-pulse` | — | substituted | One `services.pipewire` with `alsa`, `jack` and `pulse` sub-options. |
| `wireplumber` | `wireplumber` | substituted | `services.pipewire.wireplumber`; upstream's Bluetooth A2DP drop-in is applied as config. |
| `gst-plugin-pipewire` | — | dropped | Pulled in by `services.pipewire`; not a separate thing to install. |
| `libpulse` | `libpulseaudio` | substituted | Attribute name differs. |
| `alsa-utils` | `alsa-utils` | ported | |
| `pamixer` | `pamixer` | ported | Volume control for the OSD and the bar. |
| `sof-firmware` | `sof-firmware` | substituted | `hardware.firmware`; also covered by `hardware.enableAllFirmware`. |

## Printing

| upstream (Arch) | nixpkgs attribute | status | note |
| --- | --- | --- | --- |
| `cups` | `cups` | substituted | `services.printing`. |
| `cups-filters` | `cups-filters` | substituted | `services.printing.drivers`. |
| `cups-pk-helper` | `cups-pk-helper` | ported | The polkit helper the printer GUI needs. |

## Hardware, kernel and firmware

| upstream (Arch) | nixpkgs attribute | status | note |
| --- | --- | --- | --- |
| `linux`, `linux-headers` | — | substituted | `boot.kernelPackages`. The host picks the kernel; naming a package here would fight it. |
| `linux-ptl`, `linux-ptl-headers` | — | dropped | Arch's Panther Lake kernel variant. A recent `boot.kernelPackages` covers the same silicon. |
| `linux-firmware` | `linux-firmware` | substituted | `hardware.enableRedistributableFirmware`. |
| `linux-firmware-marvell` | — | dropped | Split out by Arch; part of `linux-firmware` in nixpkgs. |
| `dkms` | — | dropped | Out-of-tree modules are built against the declared kernel via `boot.extraModulePackages`, so nothing rebuilds on the running system. |
| `kernel-modules-hook` | — | dropped | Keeps the running kernel's modules alive across a pacman upgrade. A NixOS generation keeps its own kernel and modules by construction. |
| `nvidia-dkms`, `nvidia-open-dkms`, `nvidia-580xx-dkms` | — | substituted | `hardware.nvidia.package`, choosing `stable` / `production` / `open` from `linuxPackages.nvidiaPackages`. |
| `nvidia-utils`, `nvidia-580xx-utils` | — | substituted | Installed by `hardware.nvidia`, not separately. |
| `lib32-nvidia-utils`, `lib32-nvidia-580xx-utils` | — | substituted | `hardware.graphics.enable32Bit`. |
| `libva-nvidia-driver` | `nvidia-vaapi-driver` | substituted | Goes in `hardware.graphics.extraPackages`. |
| `intel-media-driver` | `intel-media-driver` | substituted | `hardware.graphics.extraPackages`. |
| `libva-intel-driver` | `intel-vaapi-driver` | substituted | `hardware.graphics.extraPackages`; for pre-Broadwell parts. |
| `libvpl`, `vpl-gpu-rt` | `libvpl`, `vpl-gpu-rt` | substituted | `hardware.graphics.extraPackages`. |
| `vulkan-intel`, `vulkan-radeon` | — | substituted | Mesa carries both Vulkan drivers in nixpkgs; `hardware.graphics.enable` is enough. |
| `vulkan-asahi` | — | dropped | Apple-silicon Mesa. Out of scope for an x86 host; a `aarch64` Asahi host would come from `nixos-hardware`. |
| `btrfs-progs` | `btrfs-progs` | substituted | Pulled in by `fileSystems.*.fsType = "btrfs"`; disko's config carries it. |
| `dosfstools` | `dosfstools` | ported | Needed for the ESP. |
| `exfatprogs` | `exfatprogs` | ported | |
| `bolt` | `bolt` | substituted | `services.hardware.bolt`, for Thunderbolt authorisation. |
| `ddcutil` | `ddcutil` | ported | External-monitor brightness. Needs the `i2c-dev` module and the `i2c` group. |
| `brightnessctl` | `brightnessctl` | ported | Internal-panel and keyboard backlight. |
| `thermald` | `thermald` | substituted | `services.thermald`. |
| `asusctl` | `asusctl` | substituted | `services.asusd`. |
| `intel-lpmd` | — | unavailable | Intel's low-power-mode daemon is not in nixpkgs. Cost is a little idle battery life on recent Intel laptops; `services.thermald` and `power-profiles-daemon` still work. |
| `broadcom-wl` | `linuxPackages.broadcom_sta` | substituted | `boot.extraModulePackages`; unfree. Only needed for old Broadcom Wi-Fi. |
| `macbook12-spi-driver-dkms` | — | unavailable | Not in nixpkgs. Costs keyboard and trackpad on 2015–2017 MacBooks; those need `nixos-hardware` anyway. |
| `tuxedo-drivers-nocompatcheck-dkms` | — | unavailable | Not in nixpkgs. Costs fan and keyboard-backlight control on TUXEDO laptops. |
| `yt6801-dkms` | — | unavailable | Motorcomm 2.5GbE driver, not in nixpkgs. Costs wired Ethernet on a few recent boards; the in-tree `yt6801` driver covers newer kernels. |
| `intel-ipu7-camera` | — | unavailable | Not in nixpkgs. Costs the MIPI webcam on the newest Intel laptops. |
| `apple-bcm-firmware`, `apple-t2-audio-config`, `linux-t2`, `linux-t2-headers`, `t2fanrd` | — | unavailable | The T2 MacBook stack has no nixpkgs equivalent. A T2 Mac needs a dedicated hardware flake, not this one. |
| `dell-xps-touchpad-haptics`, `dell-xps13-sidecar-amps` | — | unavailable | Dell XPS quirk packages, not in nixpkgs. Costs haptic-trackpad tuning and the sidecar speaker amps on those models. |
| `qmk-hid` | — | unavailable | Framework 16 keyboard-firmware tool, not in nixpkgs. Costs reflashing that keyboard from this machine. |
| `asdcontrol` | — | unavailable | Apple Studio Display brightness control, not in nixpkgs. `omarchy-brightness-display-apple` degrades to a no-op; `ddcutil` still covers ordinary DDC/CI monitors. |
| `qemu-user-static-binfmt` | — | substituted | `boot.binfmt.emulatedSystems`, which registers the same handlers. |
| `zram-generator` | — | substituted | `zramSwap`, configured to match upstream's `90-omarchy.conf`. |
| `upower` | `upower` | substituted | `services.upower`; `omarchy-battery-status` calls the CLI it installs. |

## Arch-only machinery

| upstream (Arch) | nixpkgs attribute | status | note |
| --- | --- | --- | --- |
| `yay`, `yay-debug` | — | dropped | An AUR helper. There is no AUR; a package that is not in nixpkgs gets a derivation under `pkgs/`. |
| `pacman-contrib` | — | dropped | `checkupdates`, `paccache` and friends. `omarchy update` and `nix-collect-garbage` cover the need. |
| `expac` | — | dropped | Queries the pacman database. |
| `limine`, `limine-mkinitcpio-hook`, `limine-snapper-sync` | — | dropped | The bootloader and its snapshot menu. NixOS generations are the boot menu; the host sets `boot.loader`. |
| `snapper` | — | dropped | Btrfs snapshots as rollback. A generation already is the rollback, and `omarchy snapshot` reports them. |

## Basecamp's own applications

Everything here is first-party to Omarchy or its author. Three are in nixpkgs; the rest are not, and the note says exactly what the desktop loses.

| upstream (Arch) | nixpkgs attribute | status | note |
| --- | --- | --- | --- |
| `cliamp` | `cliamp` | ported | The Winamp-style terminal music player on `Super + Shift + Alt + M`. |
| `herdr` | `herdr` | ported | The terminal workspace manager; also has a menu entry and a config file. |
| `tobi-try` | `try` | substituted | See "Shell tools". |
| `tensaku` | — | unavailable | Provides `tensaku-edit`, the default screenshot annotator. `omarchy-capture-screenshot` honours `OMARCHY_SCREENSHOT_EDITOR`, so a screenshot still lands on disk and in the clipboard, but Ctrl+E in `imv` and "edit" on a captured image do nothing until that variable points at another editor. The most user-visible gap in this port. |
| `ttfx` | — | unavailable | Renders the ASCII branding for `omarchy-screensaver` and the boot splash text. The screensaver blanks instead of animating; `omarchy-system-lock` still locks (it only tries to kill `ttfx`). |
| `aether` | — | unavailable | Generates a theme from a background image. Themes still switch and the 22 shipped themes all work; only generating a new one from a picture is gone. Removable preinstall upstream too. |
| `omacalc` | — | unavailable | Basecamp's floating calculator. The menu entry fails; any other calculator can be put in `omarchy.extraPackages`. |
| `omacut` | — | unavailable | Basecamp's video trimmer. `kdenlive` is installed and covers the task less conveniently. |
| `omawrite` | — | unavailable | Basecamp's Markdown editor. `obsidian` and `neovim` are both installed. |
| `ttf-ia-writer` | `ia-writer-mono`, `ia-writer-quattro`, `ia-writer-duospace` | substituted | Arch ships one package for all three families. Nothing in the tree names these fonts; they exist for `omawrite`, so they are installed for anyone who brings their own writing app. |
| `omarchy-keyring` | — | dropped | GPG keys so pacman trusts Basecamp's repository. Input integrity is `flake.lock`'s job here. |

Not in either list, but worth recording because upstream installs it on demand and the hook that does so is inert here:

| upstream (Arch) | nixpkgs attribute | status | note |
| --- | --- | --- | --- |
| `voxtype` | — | unavailable | AI dictation, installed by `install/user/first-run/install-voxtype.hook` through the AUR. Every `omarchy-voxtype-*` command already guards on the binary being absent, so the feature is simply not offered. |

## Fonts

Registered through `fonts.packages` rather than `environment.systemPackages`, so fontconfig sees them.

| upstream (Arch) | nixpkgs attribute | status | note |
| --- | --- | --- | --- |
| `ttf-jetbrains-mono-nerd-basic` | `nerd-fonts.jetbrains-mono` | substituted | nixpkgs moved every Nerd Font under the `nerd-fonts` set. `JetBrainsMono Nerd Font` is what upstream's fontconfig assigns to `monospace`, so this one is load-bearing. |
| `noto-fonts` | `noto-fonts` | ported | Also supplies `Noto Naskh Arabic` and `Noto Nastaliq Urdu`, which upstream's fontconfig names for Arabic and Urdu. |
| `noto-fonts-cjk` | `noto-fonts-cjk-sans` | substituted | nixpkgs splits sans from serif. |
| `noto-fonts-emoji` | `noto-fonts-color-emoji` | substituted | The attribute names the colour build, which is the one the fontconfig aliases accept. |
| `woff2-font-awesome` | `font-awesome` | substituted | Arch ships the web-font build; nixpkgs' package covers the desktop use the bar makes of it. |
| — | `liberation_ttf` | ported | Not in upstream's list: Arch pulls it in as a dependency, but upstream's `50-omarchy.conf` assigns `sans-serif` and `serif` to Liberation Sans and Liberation Serif by name. Without it every proportional font on the system falls back. |
| — | `nerd-fonts.caskaydia-mono`, `nerd-fonts.meslo-lg`, `nerd-fonts.fira-code`, `nerd-fonts.victor-mono`, `nerd-fonts.bitstream-vera-sans-mono`, `nerd-fonts.iosevka` | substituted | The six alternatives upstream's menu offers under _Install > Style > Font_. That menu action calls `omarchy-pkg-add`, which cannot install anything here, so the fonts ship up front and `omarchy font set` switches between them. |

The branded `omarchy.ttf` is not listed: it ships inside the vendored tree and `pkgs/omarchy` installs it under `share/fonts`.
