# Jet's NixOS Config

NixOS and Home Manager configuration for Jet's Framework laptop and devbox.

This flake defines two hosts:

- `devbox`: headless T3 Code host
- `framework`: Framework laptop

## Layout

- `flake.nix`: flake inputs, host wiring, formatter, and dev shell
- `flake.lock`: pinned flake input revisions
- `overlays/`: nixpkgs overlays and package overrides
- `modules/nixos/common/`: shared NixOS system modules
- `modules/home/common/`: shared Home Manager modules
- `modules/home/optional/`: optional Home Manager modules not imported by default
- `hosts/framework/`: NixOS and Home Manager configuration for the Framework laptop
- `hosts/devbox/`: NixOS and Home Manager configuration for the T3 Code host
- `pkgs/`: local package definitions
- `gnome-extensions/`: local GNOME Shell extensions
- `secrets/`: agenix-encrypted secrets

## Validation

Run these before switching a machine:

```sh
nix flake check --print-build-logs path:.
nix build --no-link --print-build-logs path:.#nixosConfigurations.devbox.config.system.build.toplevel
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

## T3 Code

OpenCode remains available independently on HTTPS port `443`. T3 Code runs alongside it with:

- The desktop client on Framework.
- A Framework server owned by `jet`, using `/home/jet/Documents/nix-config` and local port `3774`.
- A devbox server owned by `jet`, using `/home/jet/dev` and local port `3773`.
- Tailscale Serve HTTPS endpoints on port `8443`.

Create a fresh mobile pairing link on either host:

```sh
t3code-pair --label pixel-10 --ttl 1h
```

The mobile endpoints are:

```text
https://framework.taile9e84e.ts.net:8443
https://devbox.taile9e84e.ts.net:8443
```

The official Android client is built from the pinned matching upstream revision in the dedicated shell:

```sh
nix develop .#t3code-android
build-t3code-mobile
```

Its private signing key is retained under `~/.local/share/t3code-mobile-signing` so later self-built preview APKs can upgrade the existing installation.

## Codex Desktop And Remote Hosts

The unofficial [ChatGPT Desktop for Linux](https://github.com/ilysenko/codex-desktop-linux) runs on Framework with experimental Linux Remote support. Framework and devbox are separate Codex hosts:

- Framework threads use `/home/jet/.codex` and are remotely available while ChatGPT Desktop is running and the laptop is awake.
- Devbox threads use `/home/jet/.codex` and are served continuously by T3 Code from `/home/jet/dev`.
- ChatGPT mobile can pair with both hosts.
- Framework Desktop works locally on Framework and uses **Control other devices** for devbox.

Codex Remote uses OpenAI's outbound relay. The app-server Unix socket is not exposed through Tailscale.

Devbox uses agenix-managed Anthropic and OpenAI API credentials rather than subscription logins. See `hosts/devbox/README.md` for provisioning and rotation instructions.

Generate a separate short-lived pairing code for ChatGPT mobile and Framework Desktop:

```sh
codex-remote-pair
```

On Framework, enable mobile access for the local host from ChatGPT Desktop's Connections settings. Pair devbox under **Control other devices**. On the phone, use **Remote** to switch between the Framework and devbox thread catalogs.

### Development Previews

Both hosts reserve tailnet TCP ports `5100-5199` for development previews. The local firewalls restrict Framework previews to `pixel-10` and devbox previews to Framework plus `pixel-10`.

Bind a preview server to `0.0.0.0` on an available port in that range, then open the matching MagicDNS URL:

```text
http://framework:5173
http://devbox:5173
```

Direct HTTP preview traffic is encrypted by Tailscale, but browsers do not treat it as a secure context. Use a dedicated Tailscale Serve HTTPS endpoint when testing service workers, secure cookies, WebAuthn, or other HTTPS-only browser features. Keep databases, debuggers, Chrome DevTools, MCP servers, and app-server transports bound to localhost.

## Ghostty And Zellij

Ghostty uses its GTK single-instance/systemd integration and runs one persistent Zellij session named `main`.

Launching Ghostty attaches to that session through:

```sh
zellij attach --create main
```

The helper `ghostty-zellij` opens Ghostty with single-instance behavior. Zellij tab names sync from the current working directory on prompt updates.
