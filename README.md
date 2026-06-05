# Jet's NixOS Config

NixOS and Home Manager configuration for Jet's Framework laptop.

This flake defines one host:

- `framework`: Framework laptop

## Layout

- `flake.nix`: flake inputs, host wiring, formatter, and dev shell
- `flake.lock`: pinned flake input revisions
- `overlays/`: nixpkgs overlays and package overrides
- `modules/nixos/common/`: shared NixOS system modules
- `modules/home/common/`: shared Home Manager modules
- `modules/home/optional/`: optional Home Manager modules not imported by default
- `hosts/framework/`: NixOS and Home Manager configuration for the Framework laptop
- `pkgs/`: local package definitions
- `gnome-extensions/`: local GNOME Shell extensions
- `secrets/`: agenix-encrypted secrets

## Validation

Run these before switching a machine:

```sh
nix flake check --print-build-logs path:.
nix build --no-link --print-build-logs path:.#nixosConfigurations.framework.config.system.build.toplevel
```

The repository uses direnv via `.envrc` with `use flake path:.`.
