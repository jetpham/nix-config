"""One-time, localhost-only setup; credentials are supplied outside the Nix store."""
import argparse
import json
import os
from pathlib import Path
import time
import urllib.error
import urllib.parse
import urllib.request

parser = argparse.ArgumentParser()
parser.add_argument("--url", default="http://127.0.0.1:8096")
parser.add_argument("--media", default="/media")
parser.add_argument("--marker", default="/var/lib/jellyfin/.framework-bootstrap-complete")
parser.add_argument("--password-file")
args = parser.parse_args()
marker = Path(args.marker)
if marker.exists():
    print("Jellyfin initial setup already completed; preserving user settings.")
    raise SystemExit(0)
password_file = args.password_file or str(Path(os.environ["CREDENTIALS_DIRECTORY"]) / "admin-password")
password = Path(password_file).read_text().strip()
assert len(password) >= 16, "Initial password is missing or too short"
token = None


def api(path, data=None, method=None, query=None):
    url = args.url + path
    if query:
        url += "?" + urllib.parse.urlencode(query, doseq=True)
    auth = 'MediaBrowser Client="Framework setup", Device="Framework", DeviceId="framework-setup", Version="1"'
    if token:
        auth += f', Token="{token}"'
    headers = {"Authorization": auth, "Content-Type": "application/json"}
    request = urllib.request.Request(
        url, data=None if data is None else json.dumps(data).encode(),
        headers=headers, method=method or ("POST" if data is not None else "GET"),
    )
    for retry in range(30):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                body = response.read()
                return json.loads(body) if body else None
        except urllib.error.HTTPError as error:
            # Public status becomes available before the full API during boot.
            if error.code != 503 or retry == 29:
                raise
            time.sleep(1)


for attempt in range(120):
    try:
        info = api("/System/Info/Public")
        break
    except (OSError, urllib.error.URLError):
        time.sleep(1)
else:
    raise SystemExit("Jellyfin did not become ready on localhost within two minutes")

fresh = not info.get("StartupWizardCompleted", False)
if fresh:
    api("/Startup/User")  # Initialize the first user before assigning a password.
    try:
        api("/Startup/User", {"Name": "jet", "Password": password})
    except urllib.error.HTTPError as error:
        if error.code != 403:
            raise
        # A previous attempt may have set the password before being interrupted.
    api("/Startup/Configuration", {
        "ServerName": "Framework", "UICulture": "en-US",
        "MetadataCountryCode": "US", "PreferredMetadataLanguage": "en",
    })
    api("/Startup/RemoteAccess", {"EnableRemoteAccess": True, "EnableAutomaticPortMapping": False})

session = api("/Users/AuthenticateByName", {"Username": "jet", "Pw": password})
token = session["AccessToken"]
user = session["User"]
existing = {folder["Name"] for folder in api("/Library/VirtualFolders")}
for name, folder, kind in [
    ("TV Shows", "TV", "tvshows"),
    ("Movies", "Movies", "movies"),
    ("Personal Videos", "Personal videos", "homevideos"),
]:
    if name in existing:
        continue
    options = {
        "EnableRealtimeMonitor": True,
        "PreferredMetadataLanguage": "en", "MetadataCountryCode": "US",
        "SaveLocalMetadata": False, "EnableAutomaticSeriesGrouping": True,
        "EnableChapterImageExtraction": False, "EnableTrickplayImageExtraction": False,
    }
    if kind == "homevideos":
        options["TypeOptions"] = [{
            "Type": "Video", "MetadataFetchers": [], "ImageFetchers": [],
        }]
    api("/Library/VirtualFolders", {"LibraryOptions": options}, query={
        "name": name, "collectionType": kind,
        "paths": args.media + "/" + folder, "refreshLibrary": "false",
    })

configuration = user.get("Configuration", {})
configuration.update({
    "AudioLanguagePreference": "eng", "PlayDefaultAudioTrack": False,
    "SubtitleLanguagePreference": "eng", "SubtitleMode": "Always",
    "DisplayMissingEpisodes": False,
})
api(f'/Users/{user["Id"]}/Configuration', configuration)
policy = user["Policy"]
policy.update({"EnableContentDeletion": False, "EnableContentDownloading": True})
api(f'/Users/{user["Id"]}/Policy', policy)
if fresh:
    api("/Startup/Complete", method="POST")
api("/Library/Refresh", method="POST")
marker.write_text("Initial account, libraries, and English playback preferences configured.\n")
print("Jellyfin ready: local user jet, three libraries, English audio and subtitles, downloads enabled.")
