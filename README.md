# Jet's NixOS Config

NixOS and Home Manager configuration for Jet's machines.

This flake defines two hosts:

- `framework`: personal Framework laptop
- `framework-work`: work Framework laptop

## Layout

- `flake.nix`: flake inputs, host wiring, formatter, and dev shell
- `flake.lock`: pinned flake input revisions
- `lib/hosts.nix`: per-host metadata used by NixOS and Home Manager modules
- `overlays/`: nixpkgs overlays and package overrides
- `modules/nixos/common/`: shared NixOS system modules
- `modules/nixos/profiles/`: work and personal NixOS profiles
- `modules/home/common/`: shared Home Manager modules
- `modules/home/profiles/`: work and personal Home Manager profiles
- `modules/home/optional/`: optional Home Manager modules not imported by default
- `hosts/<hostname>/`: host-specific NixOS and Home Manager entrypoints
- `pkgs/`: local package definitions
- `gnome-extensions/`: local GNOME Shell extensions
- `secrets/`: agenix-encrypted secrets

## Validation

Run these before switching a machine:

```sh
nix flake check --print-build-logs path:.
nix build --no-link --print-build-logs path:.#nixosConfigurations.framework.config.system.build.toplevel path:.#nixosConfigurations.framework-work.config.system.build.toplevel
```

The repository uses direnv via `.envrc` with `use flake path:.`.
