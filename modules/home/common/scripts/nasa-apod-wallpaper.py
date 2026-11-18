"""Fetch APOD from NASA's current JSON API, with a website fallback."""

import datetime as dt
from html.parser import HTMLParser
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

from PIL import Image


class NonImageApod(Exception):
    """The current APOD should leave the existing wallpaper untouched."""


class ApodPage(HTMLParser):
    def __init__(self):
        super().__init__()
        self.media_depth = 0
        self.images = []
        self.text = []
        self.non_image = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        classes = attrs.get("class", "").split()
        if tag == "div":
            if self.media_depth or "media-detail-hero__media" in classes:
                self.media_depth += 1
        if self.media_depth and tag in ("iframe", "video", "audio", "embed", "object"):
            self.non_image = True
        if tag == "img" and self.media_depth:
            # Never choose navigation, footer logos, or the annotated rollover.
            if "smd-image-rollover__image--secondary" not in classes:
                url = attrs.get("src", "")
                if url.startswith("https://assets.science.nasa.gov/"):
                    self.images.append(url)

    def handle_endtag(self, tag):
        if tag == "div" and self.media_depth:
            self.media_depth -= 1

    def handle_data(self, data):
        self.text.append(data)

    def metadata(self):
        text = " ".join(" ".join(self.text).split())
        match = re.search(r"Date:\s*([A-Z][a-z]+ \d{1,2}, \d{4})", text)
        if not match:
            raise ValueError("NASA page has no APOD date")
        if self.non_image or not self.images:
            raise NonImageApod("NASA page has no APOD image")
        date = dt.datetime.strptime(match[1], "%B %d, %Y").date().isoformat()
        return date, self.images[0]


def curl(url):
    args = ["curl", "--fail", "--silent", "--show-error", "--location",
            "--connect-timeout", "5", "--max-time", "40"]
    args.append(url)
    return subprocess.run(args, stdout=subprocess.PIPE, check=True).stdout


def website_metadata():
    page = ApodPage()
    page.feed(curl("https://science.nasa.gov/apod/").decode("utf-8"))
    return page.metadata()


def api_metadata():
    # The new public endpoint needs no API key and lists newest entries first.
    data = json.loads(curl("https://science.nasa.gov/wp-json/wp/v2/apod-basic?per_page=1"))
    if isinstance(data, list):
        if not data:
            raise ValueError("NASA API returned no APOD entries")
        data = data[0]
    if not isinstance(data, dict) or not isinstance(data.get("date"), str):
        raise ValueError("NASA API returned invalid APOD metadata")
    if data.get("media_type") != "image":
        raise NonImageApod("NASA API media type is not image")
    # In the new API, `url` points to an HTML article, not the image.
    url = data.get("hdurl")
    if not isinstance(url, str) or not url.startswith("https://"):
        raise ValueError("NASA API has no image URL")
    return dt.date.fromisoformat(data["date"]).isoformat(), url


def valid_image(path):
    try:
        with Image.open(path) as image:
            # Reject tiny placeholders such as the 116 x 116 NASA logo.
            if min(image.size) < 200 or max(image.size) < 320:
                return False
            image.verify()
        return True
    except (OSError, ValueError, SyntaxError):
        return False


def set_wallpaper(path):
    if os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
        # A dated URI makes GNOME reload; changing a symlink with the same URI
        # does not reliably invalidate GNOME's cached background.
        uri = path.resolve().as_uri()
        for setting in ("picture-uri", "picture-uri-dark"):
            subprocess.run(["gsettings", "set", "org.gnome.desktop.background", setting, uri], check=True)
        subprocess.run(["gsettings", "set", "org.gnome.desktop.background", "picture-options", "zoom"], check=True)


def refresh(state):
    state.mkdir(parents=True, exist_ok=True)
    current = state / "current"
    for source_name, source in (("API", api_metadata), ("website", website_metadata)):
        temporary = None
        try:
            date, url = source()
            # Use a stable extension independent of query strings/renditions.
            target = state / f"apod-{date}.jpg"
            if not valid_image(target):
                data = curl(url)
                with tempfile.NamedTemporaryFile(dir=state, suffix=".tmp", delete=False) as output:
                    temporary = Path(output.name)
                    output.write(data)
                if not valid_image(temporary):
                    raise ValueError("Downloaded image is invalid or a small placeholder")
                # Normalize formats for GNOME (including first frame of GIFs).
                with Image.open(temporary) as image:
                    image.convert("RGB").save(temporary, format="JPEG", quality=95)
                temporary.replace(target)
            select(current, target)
            print(f"APOD wallpaper updated: {date} ({source_name})", flush=True)
            return
        except NonImageApod:
            print(f"APOD is not an image ({source_name}); keeping the previous wallpaper", flush=True)
            return
        except (ValueError, OSError, subprocess.SubprocessError) as error:
            # Do not print HTTP request configs or credentials.
            print(f"APOD {source_name} failed: {type(error).__name__}", file=sys.stderr)
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)
    raise RuntimeError("No usable APOD image available; keeping the previous wallpaper")


def select(current, target):
    pending = current.with_name("current.new")
    pending.unlink(missing_ok=True)
    pending.symlink_to(target.resolve())
    pending.replace(current)
    set_wallpaper(target)


if __name__ == "__main__":
    try:
        refresh(Path(sys.argv[1]).expanduser().resolve())
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
