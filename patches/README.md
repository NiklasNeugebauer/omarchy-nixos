# patches

Empty, and that is the goal.

Upstream Omarchy is vendored, not forked. Everything this repo changes about it is one of the
numbered operations in `docs/porting-steps.md`, applied programmatically in
`pkgs/omarchy/default.nix` — a shebang rewrite, a path rewrite, a command stub. Those are
mechanical and survive an upstream bump untouched.

A `.patch` file here means something upstream could not be handled that way. Before adding
one, check that the change is not really a NixOS module option (`modules/omarchy/`), and
prefer `substituteInPlace` in the derivation over a context-sensitive patch, because a patch
breaks on the next release and a substitution usually does not.

Every patch added here needs:

- a one-line comment at the top of the patch naming the FHS or Arch assumption it fixes,
- an entry in `docs/divergences.md`,
- the reason it could not be a substitution or a module option.
