# devbox

Dedicated Hetzner agent/development box.

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

## Tailnet Development Ports

The final profile exposes development ports only on `tailscale0`, not on the public Hetzner interface. Run dev servers on devbox with an external bind address, then open them from the laptop with the `devbox` MagicDNS name:

```sh
npm run dev -- --host 0.0.0.0 --port 5173
next dev -H 0.0.0.0 -p 3000
python manage.py runserver 0.0.0.0:8000
```

Local browser URLs:

```text
http://devbox:5173
http://devbox:3000
http://devbox:8000
```

Open tailnet-only TCP ports/ranges:

- `443` for opencode via Tailscale Serve
- `3000-3999`
- `5000-5999`
- `6006`
- `8000-8999`
- `8080`
