# qBittorrent search on `framework`

Jackett runs as the NixOS `jackett` service on `127.0.0.1:9117`. Its firewall
port remains closed, and systemd permits Jackett to use only `lo` and
`tailscale0`. qBittorrent has the same interface allowlist. If Tailscale is
unavailable, neither process can fall back to a physical network interface.

FlareSolverr runs on `127.0.0.1:8191`, with the same interface allowlist and no
firewall opening. Jackett's pre-start hook links it while preserving the private
API key and other state. It helps with some browser challenges, but does not
guarantee that every site or CAPTCHA will work. Repeated live tests found 1337x
and Uindex unreliable, so both were removed from the configured indexers. The
current Jackett sources are LimeTorrents, The Pirate Bay, and YTS; all three
passed, and the qBittorrent plugin returned 140 results without error rows.
Removed public indexers can be configured again through **Add indexer**.

Both services wait for the `tailscale0` device before systemd installs their
interface allowlists. Waiting for `tailscaled.service` alone is insufficient:
the daemon can start before its interface exists. If all indexers time out,
check `journalctl -b -u jackett -u flaresolverr` for
`Couldn't find index of network interface 'tailscale0'`. After the interface
exists, `sudo systemctl restart flaresolverr.service jackett.service` rebuilds
the allowlists. Historical successful tests above do not guarantee current
indexer availability.

Jackett's state, configured indexers, and generated API key remain under
`/var/lib/jackett/.config/Jackett`; qBittorrent's copy of the key remains under
`~/.local/share/qBittorrent`. Neither location is in the Nix store or this
repository.

## First activation

After activating this NixOS configuration for the first time, wait for Jackett
to start and link its generated key without printing or placing it in shell
history:

```sh
systemctl status jackett.service
link-qbittorrent-jackett
```

The linkage command asks for `sudo`, reads the key directly from Jackett's
service-owned state, and writes `jackett.json` with mode `0600`. Open
<http://127.0.0.1:9117> locally to configure Jackett. Add only indexers and
content that you are legally authorized to access. Do not enable Jackett's
external access option.

The pinned normal-search set is Jackett plus TorrentsCSV. LimeTorrents and The
Pirate Bay are installed but disabled as direct fallbacks because Jackett now
queries them. Enable those fallbacks manually only when needed; the managed
defaults are restored on activation or the next wrapped launch. Avoid adding
TorrentsCSV to Jackett while its direct plugin is enabled. EZTV,
SolidTorrents, TorLock, and TorrentProject are removed and recorded as disabled
because their current plugins failed the audited live checks.

## Updating and testing plugins

Search plugins are executable Python. Do not install arbitrary URLs or use the
qBittorrent **Check for updates** button, which would bypass the Nix pin. The
four installed files come from one fixed revision of the upstream
`qbittorrent/search-plugins` repository and are recopied on Home Manager
activation.

To update them:

1. Review the upstream commits and diff each selected file, especially imports,
   subprocess use, filesystem access, and network destinations.
2. Change `rev` in `hosts/framework/home-qbittorrent.nix`.
3. Prefetch the revision archive and replace `hash` with the resulting SRI hash:

   ```sh
   rev=<reviewed-commit>
   hash=$(nix-prefetch-url --unpack \
     "https://github.com/qbittorrent/search-plugins/archive/$rev.tar.gz")
   nix hash convert --hash-algo sha256 --to sri "$hash"
   ```

4. Run the repository formatter and the checks described below, activate only
   after review, then restart qBittorrent.
5. Test a clearly legal query such as a current Linux distribution image in
   each enabled plugin separately, then through **Enabled plugins**. Inspect
   `journalctl -u jackett.service` and qBittorrent's execution log for errors.

Useful checks before activation:

```sh
nix fmt hosts/framework/jackett.nix hosts/framework/home-qbittorrent.nix \
  pkgs/configure-qbittorrent-tailscale.nix
nix eval --impure --raw --expr \
  '(builtins.getFlake "path:'"$PWD"'").nixosConfigurations.framework.config.system.build.toplevel.drvPath'
nix build --no-link 'path:.#nixosConfigurations.framework.config.system.build.toplevel'
```

The `path:` form includes intentional untracked working-tree files. It does not
stage or commit them and does not activate the system.
