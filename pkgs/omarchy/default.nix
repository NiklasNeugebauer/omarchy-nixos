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
  bash,
  python3,
  # Kept out of the closure deliberately: the runtime tools upstream expects on PATH are
  # installed system-wide by modules/omarchy/packages.nix, the way a distribution would.
}:

let
  version = lib.fileContents "${src}/version";
  archOnly = import ./nixos-commands.nix;

  # A stub that reports the NixOS equivalent instead of failing inside pacman.
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
  buildInputs = [ bash python3 ];

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
        install -m755 ${builtins.toFile "${name}.stub" (stubFor name hint)} bin/${name}
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
    # systemd user units, picked up via `systemd.packages`. omarchy-migrate-notify is
    # deliberately not shipped: it exists to nag about pending migrations, and a system
    # rebuilt from its flake has none.
    mkdir -p "$out/lib/systemd/user"
    for unit in "$share"/default/systemd/user/*.service; do
      name=$(basename "$unit")
      [[ $name == omarchy-migrate-notify.service ]] && continue
      ln -s "$unit" "$out/lib/systemd/user/$name"
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
    inherit archOnly;
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
