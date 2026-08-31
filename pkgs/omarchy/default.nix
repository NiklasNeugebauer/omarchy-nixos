# The upstream Omarchy tree, vendored into the store.
#
# Upstream resolves everything through $OMARCHY_PATH and already supports pointing that
# somewhere other than /usr/share/omarchy (that is what `omarchy dev link` does, via
# /etc/omarchy.conf). This derivation lays the tree out exactly the way upstream expects to
# find it, so the NixOS module only has to name the path.
#
# Everything this derivation changes about upstream is one of the numbered operations in
# docs/porting-steps.md. Nothing else is touched.
{
  lib,
  stdenvNoCC,
  src,
  release,
  bash,
  python3,
  # Kept out of the closure deliberately: the runtime tools upstream expects on PATH are
  # installed system-wide by modules/omarchy/packages.nix, the way a distribution would.
}:

let
  # The pinned upstream release, not the `version` file in the tree — that file reads
  # "4.0.0.alpha" on every 4.x tag and so identifies nothing. See release.nix.
  version = "${release.upstream}-${toString release.portRevision}";
  archOnly = import ./nixos-commands.nix;
  requiredPaths = import ./upstream-paths.nix;

  # The PAM services the lock screen asks for, as string literals in its QML. Getting these
  # wrong is the worst failure in the repo: NixOS creates services under the old names, the
  # shell requests ones that do not exist, and the lock screen cannot authenticate — which
  # you discover while locked out. Declared here so a rename fails the build instead.
  lockPamServices = [
    "omarchy-lock-password"
    "omarchy-lock-fingerprint"
  ];

  # Commands that mention Arch tooling but are deliberately left alone. Each ships as
  # upstream wrote it and degrades by printing a raw error from a command that is not there,
  # which for a diagnostic or an optional installer is better than refusing to run at all.
  archAllowlist = [
    "omarchy-debug" # collects diagnostics; the pacman section comes out empty
    "omarchy-upload-log" # ditto
    "omarchy-install-gaming-retroarch" # optional installer, fails at the pkg-add stub
    "omarchy-remove-launcher-entry" # only its cleanup path touches pacman
    "omarchy-remove-dev-env" # mise handles every language but php, whose branch is || true
    "omarchy-setup-security-fingerprint" # fprintd setup, guarded on the binary being present
  ];

  # A stub that reports the NixOS equivalent instead of failing inside pacman. The summary
  # header is what the router lists it under, so it has to be there.
  stubFor = name: hint: ''
    #!/bin/bash

    # omarchy:summary=Not applicable on NixOS: ${hint}

    echo "${name} is not available on omarchy-nixos." >&2
    echo >&2
    echo "${hint}" >&2
    exit 1
  '';
in
stdenvNoCC.mkDerivation {
  pname = "omarchy";
  inherit version src;

  # In buildInputs, not nativeBuildInputs: patchShebangs resolves #! interpreters for the
  # host platform out of these.
  buildInputs = [
    bash
    python3
  ];

  dontConfigure = true;
  dontBuild = true;

  # The order matters: our own stubs and replacements are written first so the FHS
  # rewrites below cover them too, and the check at the end then covers the whole tree.
  postPatch = ''
    # Porting step 2 — replace Arch-machinery commands with stubs naming the NixOS
    # equivalent. The table lives in nixos-commands.nix.
    ${lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: hint: ''
        if [[ ! -e bin/${name} ]]; then
          echo "porting-steps: bin/${name} is gone upstream; drop it from nixos-commands.nix" >&2
          exit 1
        fi
        # Commands upstream hides are internal helpers other commands call. Carrying the
        # flag over keeps them out of `omarchy commands`, which would otherwise advertise a
        # list of things that cannot work.
        hidden=0
        grep -q '^# omarchy:hidden=true' bin/${name} && hidden=1
        install -m755 ${builtins.toFile "${name}.stub" (stubFor name hint)} bin/${name}
        if (( hidden )); then
          sed -i '/^# omarchy:summary=/a # omarchy:hidden=true' bin/${name}
        fi
      '') archOnly
    )}

    # Porting step 3 — swap in the handful of commands we genuinely reimplement.
    for replacement in ${./commands}/*; do
      name=$(basename "$replacement")
      if [[ ! -e bin/$name ]]; then
        echo "porting-steps: bin/$name is gone upstream; drop pkgs/omarchy/commands/$name" >&2
        exit 1
      fi
      install -m755 "$replacement" "bin/$name"
    done

    # Porting step 4 — NixOS has no /bin/bash and no /usr/bin/python3. Every occurrence is
    # rewritten, not just line 1: two commands write helper scripts from heredocs, and the
    # shipped hooks, .sample files and systemd system-sleep scripts are not executable, so
    # nixpkgs' own patchShebangs (which only touches line 1 of executables) misses them.
    grep -rlZ --exclude='*.md' -e '#!/bin/bash' -e '#!/usr/bin/python3' . \
      | xargs -0 --no-run-if-empty sed -i \
        -e 's|#!/bin/bash|#!${bash}/bin/bash|g' \
        -e 's|#!/usr/bin/python3|#!${python3}/bin/python3|g'

    # Porting step 5 — /usr/share/omarchy is upstream's packaged location, both as the
    # fallback for $OMARCHY_PATH and as the literal its "am I a dev checkout?" comparisons
    # test against. Pointing it at this derivation makes the store path the packaged
    # location, so those comparisons stay true and nothing at runtime has to be told where
    # the tree lives.
    grep -rlZ --exclude='*.md' '/usr/share/omarchy' . \
      | xargs -0 --no-run-if-empty sed -i 's|/usr/share/omarchy|${placeholder "out"}/share/omarchy|g'

    # Porting step 6 — /usr/bin does not exist. The shipped systemd user units name their
    # ExecStart absolutely (systemd requires it), and a handful of commands call tools by
    # absolute path. The system profile is the honest equivalent: it holds exactly what the
    # NixOS configuration installed, and it follows the booted generation, so a unit body
    # stays correct across rebuilds instead of pinning the store path it was built against.
    grep -rlZ --exclude='*.md' '/usr/bin/' . \
      | xargs -0 --no-run-if-empty sed -i 's|/usr/bin/|/run/current-system/sw/bin/|g'

    # The rewrites are self-verifying: an upstream release that introduces a new FHS
    # assumption fails the build here instead of at runtime in the VM.
    leftovers=$(grep -rl --exclude='*.md' -e '#!/bin/bash' -e '#!/usr/bin/python3' -e '/usr/share/omarchy' -e '/usr/bin/' . || true)
    if [[ -n $leftovers ]]; then
      echo "porting-steps: unported FHS paths remain in:" >&2
      echo "$leftovers" >&2
      exit 1
    fi

    # Everything a module names by path. See upstream-paths.nix for why this is not optional.
    missing=()
    for path in ${lib.escapeShellArgs requiredPaths}; do
      [[ -e $path ]] || missing+=("$path")
    done
    if (( ''${#missing[@]} )); then
      echo "porting-steps: upstream no longer has paths this repo references:" >&2
      printf '  %s\n' "''${missing[@]}" >&2
      echo "Update the reference, then update pkgs/omarchy/upstream-paths.nix." >&2
      exit 1
    fi

    # The lock screen's PAM service names, read out of the QML that asks for them.
    for service in ${lib.escapeShellArgs lockPamServices}; do
      grep -rqF "config: \"$service\"" shell/plugins/lock/ || {
        echo "porting-steps: no plugin asks for PAM service '$service' any more." >&2
        echo "Reconcile shell/plugins/lock/ with security.pam.services in modules/omarchy/shell.nix." >&2
        exit 1
      }
    done

    # A command that still drives Arch machinery. Both tables above catch a *listed* command
    # disappearing; this catches the other direction — a new upstream command reaching for
    # pacman, the AUR, Limine or Snapper and shipping as live Arch code, which no test would
    # notice because it only fails when a user runs it.
    handled=$(printf '%s\n' ${lib.escapeShellArgs (lib.attrNames archOnly)} \
      ${lib.escapeShellArgs archAllowlist} | sort -u)
    for replacement in ${./commands}/*; do handled+=$'\n'$(basename "$replacement"); done
    offenders=$(comm -23 \
      <(grep -rlE '\b(pacman|yay|paru|pacstrap|makepkg|expac|checkupdates|limine|snapper|mkinitcpio)\b' bin/ \
        | xargs -r -n1 basename | sort -u) \
      <(sort -u <<<"$handled"))
    if [[ -n $offenders ]]; then
      echo "porting-steps: these commands drive Arch machinery and are neither stubbed nor" >&2
      echo "reimplemented. Add each to nixos-commands.nix, to commands/, or to the" >&2
      echo "archAllowlist in default.nix with a reason:" >&2
      printf '  %s\n' $offenders >&2
      exit 1
    fi
  '';

  installPhase = ''
    runHook preInstall

    share=$out/share/omarchy

    # Porting step 1 — the tree upstream expects at $OMARCHY_PATH, laid out unchanged.
    # test/, manual/, plans/, agents/ and docs/ ship in no upstream package either.
    mkdir -p "$share"
    cp -r bin default shell themes config applications install migrations "$share/"
    cp version logo.txt logo.svg icon.txt icon.png "$share/"

    # Porting step 7 — every omarchy-* command on PATH. Symlinks rather than wrappers so
    # the CLI router's own `dirname "$BASH_SOURCE"` discovery keeps finding its siblings.
    mkdir -p "$out/bin"
    for command in "$share"/bin/*; do
      ln -s "$command" "$out/bin/$(basename "$command")"
    done

    # Package-owned system files, at the paths NixOS looks for them rather than the
    # /usr/lib and /usr/share paths upstream's PKGBUILD uses.
    #
    # systemd user units, picked up via `systemd.packages`.
    # nullglob, because an unmatched glob would otherwise symlink a literal "*.service" and
    # exit 0: systemd.packages would then find nothing, and shell.nix's five drop-ins would
    # silently apply to units that do not exist.
    mkdir -p "$out/lib/systemd/user"
    shopt -s nullglob
    units=("$share"/default/systemd/user/*.service)
    shopt -u nullglob
    if (( ''${#units[@]} < 5 )); then
      echo "porting-steps: expected upstream user units, found ''${#units[@]}." >&2
      echo "Reconcile default/systemd/user/ with systemd.user.services in modules/omarchy/shell.nix." >&2
      exit 1
    fi
    for unit in "''${units[@]}"; do
      name=$(basename "$unit")
      # omarchy-migrate-notify exists to nag about pending migrations, and a system rebuilt
      # from its flake has none.
      if [[ $name != omarchy-migrate-notify.service ]]; then
        ln -s "$unit" "$out/lib/systemd/user/$name"
      fi
    done

    # The SDDM and Plymouth themes, so services.displayManager.sddm.theme and
    # boot.plymouth.theme can name them without a second derivation.
    mkdir -p "$out/share/sddm/themes" "$out/share/plymouth/themes"
    ln -s "$share/default/sddm/omarchy" "$out/share/sddm/themes/omarchy"
    ln -s "$share/default/sddm/hyprland.lua" "$out/share/sddm/hyprland.lua"
    ln -s "$share/default/plymouth" "$out/share/plymouth/themes/omarchy"

    # The branded font and the generated web-app icons, where XDG looks for them.
    install -Dm644 default/fonts/omarchy/omarchy.ttf \
      -t "$out/share/fonts/truetype/omarchy"
    for icon in applications/icons/*.png; do
      install -Dm644 "$icon" "$out/share/icons/hicolor/256x256/apps/$(basename "$icon")"
    done
    install -Dm644 icon.png "$out/share/icons/hicolor/256x256/apps/omarchy.png"
    install -Dm644 icon.png "$out/share/pixmaps/omarchy.png"

    runHook postInstall
  '';

  # postPatch already rewrote every shebang; leave the automatic hook on as a net for
  # anything a future upstream release adds in a form the sed above does not match.

  passthru = {
    inherit archOnly release;
    upstreamRev = src.rev or "unpinned";
  };

  meta = {
    description = "The Omarchy desktop tree, vendored for NixOS";
    homepage = "https://omarchy.org";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "omarchy";
  };
}
