# Framework Work LUKS Reinstall

This host uses the standard NixOS encrypted-root layout for a laptop:

- UEFI `/boot` remains unencrypted so `systemd-boot` can load the kernel and initrd.
- The root partition is a LUKS container opened as `/dev/mapper/cryptroot`.
- `/` is an ext4 filesystem inside that LUKS container.
- The old plain swap partition is removed. Swap is provided by the global `zramSwap` config.
- GNOME autologin is enabled only when a LUKS root is configured, so boot requires the LUKS passphrase and screen unlock still requires the `jet` password.

This follows the NixOS manual's manual install flow and the NixOS encrypted-root examples. It also matches what the Oneleet agent checks: root must be mounted from a `crypt` block-device stack.

## Current Device Map

- Internal disk: `/dev/nvme0n1`
- EFI partition: `/dev/nvme0n1p1`, UUID `D21C-F860`
- Root partition to encrypt: `/dev/nvme0n1p2`, PARTUUID `90aab143-4d2f-4a77-b08e-95fad9ee08af`
- Old plain swap partition to remove: `/dev/nvme0n1p3`

## Before Rebooting To The Installer

Back up the config and SSH keys to the EFI partition. The SSH key backup is temporarily stored on unencrypted `/boot`; delete it after the reinstall succeeds.

```bash
sudo tar -C /home/jet/Documents -czf /boot/nix-config-before-luks.tar.gz nix-config
sudo tar -C /home/jet -czf /boot/jet-ssh-before-luks.tar.gz .ssh
```

## Installer Commands

Boot the NixOS USB installer, open a terminal, and verify the disk layout first:

```bash
lsblk -o NAME,PATH,SIZE,FSTYPE,MOUNTPOINTS,PARTUUID,UUID
```

Stop any active swap, remove the old plain swap partition, and expand the root partition to the end of the disk:

```bash
sudo swapoff -a || true
sudo parted /dev/nvme0n1 --script rm 3
sudo parted /dev/nvme0n1 --script resizepart 2 100%
sudo partprobe /dev/nvme0n1
sudo udevadm settle
```

Verify that partition 2 still has the expected PARTUUID. If it changed, update `hosts/framework-work/hardware-configuration.nix` before installing.

```bash
lsblk -o NAME,SIZE,PARTUUID /dev/nvme0n1
```

Create and open the LUKS root container:

```bash
sudo cryptsetup luksFormat /dev/disk/by-partuuid/90aab143-4d2f-4a77-b08e-95fad9ee08af
sudo cryptsetup open /dev/disk/by-partuuid/90aab143-4d2f-4a77-b08e-95fad9ee08af cryptroot
```

Create the root filesystem and mount it with the existing EFI partition:

```bash
sudo mkfs.ext4 -L nixos-root /dev/mapper/cryptroot
sudo mount /dev/mapper/cryptroot /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-uuid/D21C-F860 /mnt/boot
```

Restore this config and SSH keys:

```bash
sudo mkdir -p /mnt/home/jet/Documents /mnt/home/jet
sudo tar -C /mnt/home/jet/Documents -xzf /mnt/boot/nix-config-before-luks.tar.gz
sudo tar -C /mnt/home/jet -xzf /mnt/boot/jet-ssh-before-luks.tar.gz
sudo chown -R 1000:100 /mnt/home/jet
sudo chmod 700 /mnt/home/jet/.ssh
sudo chmod 600 /mnt/home/jet/.ssh/id_ed25519
```

Install NixOS from the flake:

```bash
sudo nixos-install --flake /mnt/home/jet/Documents/nix-config#framework-work
```

Set the `jet` password for screen unlock and sudo:

```bash
sudo nixos-enter --root /mnt -c 'passwd jet'
```

Remove the temporary unencrypted SSH key backup, then reboot:

```bash
sudo rm -f /mnt/boot/jet-ssh-before-luks.tar.gz
sudo reboot
```

## After First Boot

Check the block-device stack:

```bash
lsblk -o NAME,TYPE,FSTYPE,MOUNTPOINTS
findmnt -no SOURCE,FSTYPE /
```

Expected shape:

```text
nvme0n1p2 crypto_LUKS
└─cryptroot ext4 /
```

Then restart Oneleet and rerun the check:

```bash
sudo systemctl restart oneleet-daemon
systemctl status oneleet-daemon
```

## References Checked

- NixOS manual, manual installation and UEFI `/boot` mounting flow: `https://nixos.org/manual/nixos/stable/`
- NixOS Wiki, Full Disk Encryption examples: `https://nixos.wiki/wiki/Full_Disk_Encryption`
- ArchWiki, dm-crypt encrypted root tradeoffs and LUKS-on-partition layout: `https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system`
