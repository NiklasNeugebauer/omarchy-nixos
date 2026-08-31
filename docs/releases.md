# Releases

This repo tracks upstream omarchy releases and tags its own against them.

    upstream v4.0.2  →  omarchy-nixos v4.0.2-1   the first port of that release
                        omarchy-nixos v4.0.2-2   a packaging fix, upstream unchanged
    upstream v4.0.3  →  omarchy-nixos v4.0.3-1

The upstream release lives in exactly one place: the `omarchy` input's URL in `flake.nix`.
`release.nix` reads it back out of `flake.lock`, so the package version, `omarchy version` and
`/etc/omarchy-nixos.conf` all follow it with nothing to keep in sync.

Upstream's own `version` file is not used for this. It reads `4.0.0.alpha` on `v4.0.0`,
`v4.0.1` and `v4.0.2` alike, so it cannot tell you which release you are running.

## Pinning a release as a user

    inputs.omarchy-nixos.url = "github:NiklasNeugebauer/omarchy-nixos/v4.0.2-1";

Following `main` gets you whatever upstream release has been adopted and reviewed. Following a
tag gets you a pairing that was built and smoke tested together.

## Adopting an upstream release

`.github/workflows/upstream.yml` checks daily and opens a PR when upstream publishes a release
that is not the pinned one. It bumps the tag in `flake.nix`, resets `portRevision` to 1,
relocks, and puts the classified upstream diff in the PR body. It never merges.

Review it against the PR body's checklist. The short version of why a human is required: CI
proves the port still evaluates and builds, and the package build fails loudly on every kind
of upstream drift it can detect — but CI has no KVM, so nothing in it has booted a session.
Run `nix build .#desktop-screenshots` locally and look at the screenshots.

To do it by hand instead, `scripts/sync-upstream.sh` does the same bump and classification
locally.

## Cutting a release here

After the upstream PR is merged, or after a packaging fix:

    # upstream moved: portRevision is already 1
    # packaging-only fix: bump portRevision in release.nix first, and commit it
    nix flake check
    nix build .#desktop-screenshots      # look at result/
    git tag -a v4.0.2-1 -m 'omarchy v4.0.2, packaging revision 1'
    git push origin v4.0.2-1

Then write the release notes on GitHub. Three things belong in them, and nothing else:

- what changed upstream, in a sentence or two;
- what this repo had to translate for it — especially any change to
  `docs/porting-steps.md`, which is the port and therefore the most important thing in the
  diff;
- what is newly broken or newly working, so a user can decide whether to move.

## Version skew

The upstream release pins the desktop. It does not pin nixpkgs, and a nixpkgs bump is a
separate commit and a separate reason for a `portRevision`. A tag here identifies the pairing
of an upstream release with a `flake.lock`, which is the thing that was actually tested.
