# Serialize presses while Tailscale is selecting or changing an exit node.
exec 9>"${XDG_RUNTIME_DIR:?}/tailscale-vpn-toggle.lock"
flock -n 9 || exit 0

notify() {
  notify-send --app-name="Mullvad VPN" "$@" || true
}
fail() {
  notify --urgency=critical "VPN toggle failed" "$1"
  exit 1
}

prefs=$(tailscale debug prefs) || fail "Could not read Tailscale settings."
if jq -e '(.ExitNodeID // "") != "" or (.ExitNodeIP // "") != ""' <<< "$prefs" >/dev/null; then
  tailscale set --exit-node= || fail "Could not disable the exit node."
  notify "VPN off" "Tailscale remains connected; internet traffic uses your normal connection."
else
  status=$(tailscale status --json) || fail "Could not read Tailscale status."
  jq -e '.BackendState == "Running"' <<< "$status" >/dev/null || fail "Connect Tailscale first."
  suggestion=$(tailscale exit-node suggest) || fail "Tailscale could not suggest an exit node."
  node=$(sed -n 's/^Suggested exit node: //p' <<< "$suggestion")
  # Suggestions may also be private tailnet nodes. Only enable a known Mullvad peer.
  jq -e --arg node "$node" '
    [.Peer[]? | select(.DNSName == $node and .ExitNodeOption == true
      and (.DNSName | endswith(".mullvad.ts.net.")))] | length == 1
  ' <<< "$status" >/dev/null || fail "The suggested exit node is not an available Mullvad node."
  tailscale set --exit-node="$node" || fail "Could not enable the suggested Mullvad node."
  notify "VPN on" "Connected through $node"
fi
