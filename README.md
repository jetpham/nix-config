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

The repository uses direnv via `.envrc` with `use flake`.

## Switching

Enter the dev shell automatically with direnv, or explicitly with:

```sh
nix develop
```

Switch the current host:

```sh
nhs
```

Without an already-loaded dev shell:

```sh
nix develop -c nhs
```

Build and make the new generation the next boot without switching now:

```sh
nhb
```

## Updating

Update inputs:

```sh
nix flake update
```

The interactive Bash alias `nfu` also runs `nix flake update`.

After updates, validate and switch:

```sh
nix flake check --print-build-logs path:.
nix build --no-link --print-build-logs path:.#nixosConfigurations.framework.config.system.build.toplevel
nhs
```

## OpenCode

The system starts one background OpenCode server for user `jet`:

```sh
opencode serve
```

The server host and port are declared in `~/.config/opencode/opencode.json`:

```text
127.0.0.1:4096
```

In interactive Bash, both `opencode` and `o` attach to that background server from the current directory:

```sh
opencode
o
```

To bypass the shell function and run the underlying binary directly:

```sh
command opencode --help
```

OpenCode is configured with permissive permissions and only the Chrome DevTools MCP globally enabled.

The Framework also exposes OpenCode to the tailnet with Tailscale Serve:

```sh
opencode-tailnet-url
opencode-tailnet-url --qr
```

Tailnet policy also restricts access to `framework`: broad tailnet and exit-node access remains enabled, but `framework` is removed from the broad tailnet grant and added back only for `pixel-10`. The live policy uses `pixel-10`'s Tailscale IPs plus built-in Android posture (`node:os == 'android'`, stable release track, encrypted Tailscale state) because custom device posture attributes are not available on the current Tailscale plan. The local firewall additionally limits the Serve HTTPS endpoint to `pixel-10` (`100.106.98.89` / `fd7a:115c:a1e0::1433:6259`).

## Ghostty And Zellij

Ghostty uses its GTK single-instance/systemd integration and runs one persistent Zellij session named `main`.

Launching Ghostty attaches to that session through:

```sh
zellij attach --create main
```

The helper `ghostty-zellij` opens Ghostty with single-instance behavior. Zellij tab names sync from the current working directory on prompt updates.
