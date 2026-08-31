# What this repo calls its own releases.
#
# `upstream` is read from flake.lock rather than written here, so the release tag exists in
# exactly one place: the omarchy input's URL in flake.nix. `portRevision` counts packaging
# releases against the same upstream release — bumped when this repo ships a fix that does
# not move upstream, reset to 1 by the upstream bump itself.
#
#   upstream v4.0.2  →  omarchy-nixos v4.0.2-1, v4.0.2-2, …
#
# Upstream's own `version` file is deliberately not used as the version: it reads
# "4.0.0.alpha" on v4.0.0, v4.0.1 and v4.0.2 alike, so it distinguishes nothing.
{ lock }:

let
  ref = lock.nodes.omarchy.original.ref or null;

  # A tag looks like "v4.0.2". Anything else means the input has been repointed at a branch
  # or a bare revision, which is not a release — say so in the version rather than inventing
  # one, so `omarchy version` cannot claim to be a release it is not.
  tagged = ref != null && builtins.match "v[0-9].*" ref != null;
in
{
  portRevision = 1;

  upstream = if tagged then builtins.substring 1 (-1) ref else "unreleased";

  upstreamRef = if ref != null then ref else lock.nodes.omarchy.locked.rev;
}
