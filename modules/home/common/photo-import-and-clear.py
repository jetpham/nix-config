#!@python@

import configparser
import fcntl
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import stat
import subprocess
import sys
import tempfile


RAPID_PHOTO_DOWNLOADER = "@rapidPhotoDownloader@"
FINDMNT = "@findmnt@"
NOTIFY_SEND = "@notifySend@"
UDISKSCTL = "@udisksctl@"

MEDIA_EXTENSIONS = {
    "3fr",
    "3gp",
    "arw",
    "avi",
    "braw",
    "cr2",
    "cr3",
    "crm",
    "crw",
    "dcr",
    "dng",
    "fff",
    "heic",
    "heif",
    "hif",
    "iiq",
    "jpe",
    "jpeg",
    "jpg",
    "lrv",
    "m2t",
    "m2ts",
    "mef",
    "mod",
    "mos",
    "mov",
    "mp4",
    "mpeg",
    "mpg",
    "mpo",
    "mrw",
    "mts",
    "nef",
    "nev",
    "nrw",
    "orf",
    "ori",
    "pef",
    "raf",
    "raw",
    "rw2",
    "sr2",
    "srw",
    "tif",
    "tiff",
    "tod",
    "x3f",
}


def notify(summary: str, body: str, *, critical: bool = False) -> None:
    subprocess.run(
        [
            NOTIFY_SEND,
            "--app-name=Rapid Photo Downloader",
            f"--urgency={'critical' if critical else 'normal'}",
            summary,
            body,
        ],
        check=False,
    )


def mounted_card(path: str) -> tuple[Path, str]:
    candidate = Path(path).resolve()
    result = subprocess.run(
        [FINDMNT, "--json", "--output", "TARGET,SOURCE", "--target", candidate],
        check=True,
        capture_output=True,
        text=True,
    )
    filesystem = json.loads(result.stdout)["filesystems"][0]
    target = Path(filesystem["target"]).resolve()
    device = filesystem["source"]

    expected_root = Path("/run/media") / os.environ["USER"]
    if not target.is_relative_to(expected_root):
        raise ValueError(f"Refusing non-removable mount {target}")
    if not device.startswith("/dev/"):
        raise ValueError(f"Refusing non-block-device source {device}")

    return target, device


def discover_mounted_card(expected_root: Path | None = None) -> tuple[Path, str]:
    if expected_root is None:
        expected_root = Path("/run/media") / os.environ["USER"]

    cards: list[tuple[Path, str]] = []
    if expected_root.is_dir():
        for candidate in expected_root.iterdir():
            if not candidate.is_dir() or not (candidate / "DCIM").is_dir():
                continue
            try:
                card = mounted_card(str(candidate))
            except (IndexError, KeyError, OSError, subprocess.SubprocessError, ValueError):
                continue
            if card not in cards:
                cards.append(card)

    if not cards:
        raise ValueError("No mounted camera card with a DCIM folder was found.")
    if len(cards) > 1:
        names = ", ".join(card.name for card, _device in cards)
        raise ValueError(f"More than one camera card is mounted: {names}")
    return cards[0]


def set_ini_value(path: Path, section: str, key: str, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    parser = configparser.RawConfigParser()
    parser.optionxform = str
    if path.exists():
        parser.read(path)
    if not parser.has_section(section):
        parser.add_section(section)
    parser.set(section, key, value)

    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    with tempfile.NamedTemporaryFile(
        mode="w", encoding="utf-8", dir=path.parent, delete=False
    ) as output:
        parser.write(output, space_around_delimiters=False)
        temporary_path = Path(output.name)
    temporary_path.chmod(mode)
    temporary_path.replace(path)


def sha256(path: Path) -> bytes:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.digest()


def media_files(card: Path) -> list[Path]:
    return sorted(
        path
        for path in card.rglob("*")
        if path.is_file() and path.suffix.lower().lstrip(".") in MEDIA_EXTENSIONS
    )


def verified_sources(card: Path, database: Path) -> list[Path] | None:
    sources = media_files(card)
    if not sources:
        return []
    if not database.exists():
        return None

    verified: list[Path] = []
    with sqlite3.connect(database) as connection:
        for source in sources:
            rows = connection.execute(
                "SELECT download_name FROM downloaded WHERE file_name=? AND size=?",
                (source.name, source.stat().st_size),
            )
            source_hash = sha256(source)
            for (destination_name,) in rows:
                destination = Path(destination_name)
                if (
                    destination_name != "."
                    and destination.is_file()
                    and source.stat().st_size == destination.stat().st_size
                    and source_hash == sha256(destination)
                ):
                    verified.append(source)
                    break
            else:
                return None

    return verified


def clear_and_eject(card: Path, device: str, sources: list[Path]) -> None:
    for source in sources:
        source.unlink()
    os.sync()

    unmounted = subprocess.run(
        [UDISKSCTL, "unmount", "--block-device", device],
        check=False,
        capture_output=True,
        text=True,
    )
    if unmounted.returncode != 0:
        raise RuntimeError(unmounted.stderr.strip() or unmounted.stdout.strip())

    subprocess.run(
        [UDISKSCTL, "power-off", "--block-device", device],
        check=False,
        capture_output=True,
        text=True,
    )
    notify(
        "Photo import complete",
        f"Cleared {len(sources)} verified files and safely ejected {card.name}.",
    )


def main() -> int:
    runtime_directory = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp"))
    lock = (runtime_directory / "photo-import-and-clear.lock").open("w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return 0

    if len(sys.argv) > 2:
        notify("Photo import not started", "Too many SD-card paths were provided.", critical=True)
        return 2

    try:
        if len(sys.argv) == 2:
            card, device = mounted_card(sys.argv[1])
        else:
            card, device = discover_mounted_card()
    except (
        IndexError,
        KeyError,
        OSError,
        subprocess.SubprocessError,
        ValueError,
    ) as error:
        notify("Photo import not started", str(error), critical=True)
        return 2

    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    database = data_home / "rapid-photo-downloader/downloaded_files.sqlite"

    try:
        verified = verified_sources(card, database)
        if verified is not None:
            clear_and_eject(card, device, verified)
            return 0

        config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
        config = config_home / "Rapid Photo Downloader/Rapid Photo Downloader.conf"
        set_ini_value(config, "Automation", "auto_unmount", "false")
        set_ini_value(config, "Automation", "auto_exit", "true")
        set_ini_value(config, "Automation", "auto_exit_force", "false")

        subprocess.run(
            [
                RAPID_PHOTO_DOWNLOADER,
                "--auto-download-startup",
                "on",
                str(card),
            ],
            check=False,
        )

        if not card.is_mount():
            return 1

        verified = verified_sources(card, database)
        if verified is None:
            notify(
                "SD card left untouched",
                "Not every photo or video could be verified after import.",
                critical=True,
            )
            return 1

        clear_and_eject(card, device, verified)
        return 0
    except (configparser.Error, OSError, RuntimeError, sqlite3.Error) as error:
        notify("SD card left mounted", str(error), critical=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
