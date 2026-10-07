# Jet's NixOS Config

NixOS and Home Manager configuration for Jet's Framework laptop.

This flake defines the `framework` host.

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

Framework currently uses GNOME. `modules/home/optional/sway.nix` is an inactive alternative configuration and is not imported.

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

Tailnet policy also restricts access to `framework`: broad tailnet and exit-node access remains enabled, but `framework` is removed from the broad tailnet grant and added back only for `pixel-10`. The live policy uses `pixel-10`'s Tailscale IPs plus built-in Android posture (`node:os == 'android'`, stable release track, encrypted Tailscale state) because custom device posture attributes are not available on the current Tailscale plan. The local firewall additionally limits the Serve HTTPS endpoint to `pixel-10` (`100.106.98.89` / `fd7a:115c:a1e0::1433:6259`).

## T3 Code

Framework uses one T3 environment:

- `t3code.service` runs at boot as `jet`, listening on `127.0.0.1:3773`, with all server state under `~/.t3`.
- The T3 desktop client opens on workspace 2. Home Manager disables its bundled local backend; add the system server through Settings → Connections → Add environment.
- T3 manages the installed Codex CLI's app-server processes and uses the login in `~/.codex`. A separate Codex system service is unnecessary.

The server is exposed through Tailscale Serve on HTTPS port `8443`. Desktop and phone connect to the same environment and share its history. The laptop must be awake for remote access. Closing the desktop does not stop the service.

For a desktop connection on this laptop, create a pairing link with:

```sh
t3 auth pairing create --base-dir "$HOME/.t3" --base-url http://127.0.0.1:3773 --label desktop --ttl 1h
```

Paste it into Add environment. Do not start another `t3` server manually against this directory. The system service refuses to start while another process has its database open.

Create a fresh mobile pairing link for the background server:

```sh
t3code-pair --label pixel-10 --ttl 1h
```

The mobile endpoint is:

```text
https://framework.taile9e84e.ts.net:8443
```

The official Android client is built from the pinned matching upstream revision in the dedicated shell:

```sh
nix develop .#t3code-android
T3CODE_ANDROID_ARCHITECTURES=arm64-v8a build-t3code-mobile
```

Run the build command from a T3 Code checkout matching the server's pinned revision. The shell supplies Android SDK/build tools 37.0; the architecture setting builds only the Pixel 10's ARM64 target. Omit it to build all supported architectures.

Its private signing key is retained under `~/.local/share/t3code-mobile-signing` so later self-built preview APKs can upgrade the existing installation.

## Codex Desktop And Remote Access

The unofficial [ChatGPT Desktop for Linux](https://github.com/ilysenko/codex-desktop-linux) runs on Framework with experimental Linux Remote support. Local threads use `/home/jet/.codex` and are remotely available while ChatGPT Desktop is running and the laptop is awake.

Codex Remote uses OpenAI's outbound relay. The app-server Unix socket is not exposed through Tailscale.

Generate a separate short-lived pairing code:

```sh
codex-remote-pair
```

Enable mobile access from ChatGPT Desktop's Connections settings, then select Framework in ChatGPT mobile's Remote view.

### Development Previews

Framework reserves tailnet TCP ports `5100-5199` for development previews. The local firewall restricts access to `pixel-10`.

Bind a preview server to `0.0.0.0` on an available port in that range, then open the matching MagicDNS URL:

```text
http://framework:5173
```

Direct HTTP preview traffic is encrypted by Tailscale, but browsers do not treat it as a secure context. Use a dedicated Tailscale Serve HTTPS endpoint when testing service workers, secure cookies, WebAuthn, or other HTTPS-only browser features. Keep databases, debuggers, Chrome DevTools, MCP servers, and app-server transports bound to localhost.

## Ghostty And Zellij

Ghostty uses its GTK single-instance/systemd integration and runs one persistent Zellij session named `main`.

Launching Ghostty attaches to that session through:

```sh
zellij attach --create main
```

The helper `ghostty-zellij` opens Ghostty with single-instance behavior. Zellij tab names sync from the current working directory on prompt updates.
