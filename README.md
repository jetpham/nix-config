# Jet's NixOS Config

NixOS and Home Manager configuration for Jet's machines.

This flake defines two hosts:

- `framework`: personal Framework laptop
- `framework-work`: work Framework laptop

## Layout

- `flake.nix`: flake inputs, host wiring, overlays, formatter, and dev shell
- `flake.lock`: pinned flake input revisions
- `configuration.nix`: shared NixOS system configuration
- `hosts/<hostname>/`: host-specific NixOS configuration
- `home.nix`: shared Home Manager entrypoint
- `home-modules/`: split Home Manager modules
- `pkgs/`: local package definitions
- `gnome-extensions/`: local GNOME Shell extensions
- `secrets/`: agenix-encrypted secrets

## Validation

Run these before switching a machine:

```sh
nix flake check --print-build-logs
nix build --no-link --print-build-logs .#nixosConfigurations.framework.config.system.build.toplevel .#nixosConfigurations.framework-work.config.system.build.toplevel
```

The repository uses direnv via `.envrc` with `use flake`.
