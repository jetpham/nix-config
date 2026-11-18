# Framework media library

`hosts/framework/jellyfin.nix` enables Jellyfin Server and Jellyfin Desktop.
Run `nhs` from the repository's dev shell to activate them. The first start runs
`jellyfin-bootstrap.service` once to create user `jet`, the three libraries,
English audio/subtitle preferences, and download permission. Subsequent boots
preserve account settings and watch history.

## Library

The user-visible library is `/home/jet/Documents/Media`:

- `TV/Dexter (2006)/Season 04`: the four existing episodes, E09–E12.
- `TV/Dexter (2006)/Season 05`: twelve episodes.
- `TV/My Dress-Up Darling (2022)/Season 01` and `Season 02`: twelve episodes each.
- `TV/Rent-a-Girlfriend (2020)/Season 02` through `Season 05`: 48 finished captioned episodes.
- `Movies/Blade Runner 2049 (2017)` and `Movies/Disclosure Day (2026)`.
- Show `extras` folders, plus a separate `Personal videos` library for clips and recordings.

Files are hard links to existing local files, with standardized library names.
Original torrent and project paths are unchanged. Hard links add no duplicate
video storage; deleting one pathname leaves the other intact. Editing a linked
file's contents affects both names. Jellyfin receives a **read-only** bind mount
at `/media` inside its service, and cannot delete or modify these files.

The audit manifest and organizer are under
`/home/jet/Documents/jellyfin-setup`. This is an initial import, not an automatic
qBittorrent rename/import hook. New completed downloads should be imported with
the same hard-link approach and then scanned; downloading partial files should
not be added. Project demonstration videos outside the normal media folders and
intermediate caption builds are not indexed.

## Login and playback

Run `jellyfin-login` to see the username, initial password, and server addresses.
Credentials live outside the Nix store in
`/home/jet/Documents/jellyfin-setup/credentials` (directory 0700; files 0600).
Keep these files for first activation. Changing the password in Jellyfin afterward
does not reset it on reboot; the helper continues to label the saved value as the
initial password.

Open Jellyfin Desktop and connect to `http://localhost:8096`. On the Pixel install
Findroid, connect to the same server, and use its mpv player for ASS captions and
translated signs. Choose the combined English Dub Captions + Signs track for
Rent-a-Girlfriend; it is already the file's default track. Downloads preserve the
original MKV and its embedded tracks. Test one offline episode before downloading
the entire library.

## Connections

- **Tailscale:** `http://framework:8096` from the Pixel. The firewall permits this
  service only from the Pixel's configured Tailscale addresses.
- **Laptop hotspot:** run `media-hotspot`, join Wi-Fi `framework` on the Pixel
  using its existing password, then use `http://10.42.0.1:8096`. This new profile
  uses 5 GHz channel 149 / 80 MHz and keeps the current internet default route.
  DHCP and local DNS are allowed through the hotspot firewall.
- **USB:** after the switch, reconnect the cable, enable USB tethering on the
  Pixel, and run `jellyfin-addresses`. Use the printed USB address in Findroid.
  The Pixel receives the stable interface name `pixel-usb`; its DHCP connection
  cannot replace the laptop's internet route or DNS. The USB IP may change after
  reconnecting, so the helper reports the current address.

The laptop must be awake to stream or download. Downloaded episodes play on the
Pixel with the laptop off. These services do not change global sleep/lid behavior.

## Checks after activation

```sh
systemctl status jellyfin jellyfin-bootstrap --no-pager
jellyfin-addresses
```

First library scan and artwork retrieval may take several minutes. To investigate
initialization errors use `journalctl -u jellyfin-bootstrap -b`; do not delete the
server database or reset existing credentials to retry setup.

The configuration was built without activating the system. An isolated localhost
Jellyfin 12.4 test instance indexed all 88 episodes, both movies, and 14 personal
videos; login, preferences, download permission, and original-file range streaming
were verified. AMD VA-API H.264 encoding also passed a short hardware test.

## Manga and phone apps

The Pixel has Findroid 1.2.0 (official libre arm64 APK), signed into Framework,
and tracked in Obtainium from the official GitHub repository.

The existing YACReader desktop library stays in `~/Documents/Comics`, including
its database and progress. `home-media.nix` runs the headless YACReader Library
server as the user service `yacreader-library` on port 8080. Do not run the
YACReaderLibrary GUI concurrently with this headless library server; the ordinary
YACReader reader can continue using its local library and reporting progress.

The phone has a locally built GPL Android client, YACR, from
https://github.com/CST-Cat/YACR-OPENAPP, with English resources added locally.
Source, Nix Android build shell, build logs, APK and the pre-setup progress backup
are under `~/Documents/manga-setup`. Build with:

```sh
nix develop ~/Documents/manga-setup -c bash -c 'cd ~/Documents/manga-setup/yacr-openapp && ./gradlew assembleDebug lintDebug'
```

It streams pages and syncs progress; it does not support offline downloads.
The laptop must be awake. The server has no configured password; firewall access
is restricted to the Pixel on Tailscale and the existing direct media connections.
Normal address after `nhs`: `http://framework:8080`; hotspot:
`http://10.42.0.1:8080`; USB networking: the laptop USB IP with port 8080.
After activation the phone was switched to `http://framework:8080`. The temporary
ADB reverse test connection was removed; a fresh app launch fetched the manga
library through the normal network connection.

Sync was verified using a separate synthetic six-page comic: setting page 2 in
the laptop library database opened page 2 on the phone; swiping to page 3 updated
the laptop database to page 3. The test library was unregistered afterward, and
all real manga page/read/opened values still matched the pre-setup SQLite backup.
YACReader merges page progress with the maximum value, so restarting a book on
the phone does not automatically reset its progress on the laptop.
