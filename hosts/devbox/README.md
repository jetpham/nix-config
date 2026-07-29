# devbox

Dedicated Hetzner T3 Code host.

## Disk Layout

The NixOS config expects this RAID0 layout:

```text
/dev/nvme0n1p1  EFI, label BOOT, mounted at /boot
/dev/nvme0n1p2  Linux RAID member
/dev/nvme1n1p1  Linux RAID member
/dev/md/devbox-root  RAID0, ext4, label devbox-root, mounted at /
```

The layout is declarative in `hosts/devbox/disko.nix`. If partitioning manually, the equivalent rescue-system setup commands are:

```sh
sgdisk --zap-all /dev/nvme0n1
sgdisk --zap-all /dev/nvme1n1
sgdisk -n 1:1M:+1G -t 1:EF00 -c 1:BOOT /dev/nvme0n1
sgdisk -n 2:0:0 -t 2:FD00 -c 2:devbox-root-a /dev/nvme0n1
sgdisk -n 1:1M:0 -t 1:FD00 -c 1:devbox-root-b /dev/nvme1n1
mkfs.vfat -F 32 -n BOOT /dev/nvme0n1p1
mdadm --create /dev/md/devbox-root --level=0 --raid-devices=2 --metadata=1.2 --name=devbox:root /dev/nvme0n1p2 /dev/nvme1n1p1
mkfs.ext4 -L devbox-root /dev/md/devbox-root
```

Mount for installation:

```sh
mount /dev/disk/by-label/devbox-root /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-label/BOOT /mnt/boot
```

Install the bootstrap profile first. It temporarily enables public SSH with key-only auth so you do not lose access before Tailscale is enrolled:

```sh
nixos-install --flake .#devbox-bootstrap
```

After first boot, enroll Tailscale manually before disabling any temporary public SSH access:

```sh
sudo tailscale up --ssh --hostname devbox
```

Then verify from the laptop:

```sh
ssh jet@devbox
```

Then switch to the final profile, which disables public OpenSSH and keeps access through Tailscale SSH:

```sh
sudo nixos-rebuild switch --flake .#devbox
```

For later updates from Framework, run this repository's `devbox-switch` command from its dev shell:

```sh
git push origin main
nix develop -c devbox-switch
```

The command requires a clean, pushed `main` branch. SSH only triggers the command: devbox fetches the Forgejo flake and builds and activates it locally.

The equivalent manual workflow is:

```sh
ssh jet@devbox
nixos-rebuild switch \
  --refresh \
  --flake 'git+ssh://forgejo@git.extremist.software/jet/nix-config.git?ref=main#devbox' \
  --elevate=sudo
```

## AI API Credentials

Claude Code and Codex use API-only billing on devbox. Their raw API keys are encrypted for Jet's keys and the devbox SSH host key with agenix. Set or rotate them from the repository root:

```sh
RULES=secrets/secrets.nix agenix -e secrets/devbox-openai-api-key.age
RULES=secrets/secrets.nix agenix -e secrets/devbox-anthropic-api-key.age
RULES=secrets/secrets.nix agenix -e secrets/devbox-linear.env.age
```

The OpenAI and Anthropic files contain only their raw API keys. The Linear file is an environment file containing `LINEAR_API_KEY=<key>`. Activation generates Codex's API-only `auth.json` automatically, and Claude Code reads its key through a managed `apiKeyHelper`. Linear's read-write MCP server is configured for both providers and uses the shared key from their environment. None of the CLIs need an interactive login. Commit and deploy the changed `.age` files normally. After deployment, verify the active Codex method with:

```sh
ssh jet@devbox 'codex login status'
```

The devbox host private key at `/etc/ssh/ssh_host_ed25519_key` is required to decrypt these secrets. Preserve it across reinstalls or rekey the secrets for the replacement host key before deployment.

Cafe authentication is stored as an agenix environment file at `secrets/devbox-cafe.env.age`. Its `CAFE_TOKEN` value is available to T3 provider processes and interactive devbox shells; the Cafe CLI itself is supplied by the project being developed.

## Tailscale Authentication

Tailscale state persists under `/var/lib/tailscale`, and the NixOS configuration continuously enables Tailscale SSH with `jet` as the local operator. Key expiry is disabled for both Framework and devbox in the Tailscale admin console. The tailnet SSH policy uses `action: "accept"` rather than check mode, so SSH connections do not require periodic browser verification.

The canonical development workspace is `/home/jet/dev`. During the migration from the original two-user layout, `/home/agent` and `/srv/dev` remain temporary compatibility symlinks for historical sessions and paths. T3's persistent state remains at `/var/lib/t3code-agent`.

## Tailnet Development Ports

The final profile exposes development ports only on `tailscale0`, not on the public Hetzner interface. Run dev servers on devbox with an external bind address, then open them from the laptop with the `devbox` MagicDNS name:

```sh
npm run dev -- --host 0.0.0.0 --port 5173
```

Local browser URLs:

```text
http://devbox:5173
```

Open tailnet-only TCP ports/ranges:

- `8443` for T3 Code via Tailscale Serve
- `5100-5199` for development previews from Framework and Pixel
