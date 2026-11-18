{ lib, pkgs, ... }:

let
  vpnToggle = pkgs.writeShellApplication {
    name = "tailscale-vpn-toggle";
    runtimeInputs = with pkgs; [ tailscale jq libnotify util-linux gnused ];
    text = builtins.readFile ./tailscale-vpn-toggle.sh;
  };
in
{
  home.packages = [ vpnToggle ];
  dconf.settings = {
    "org/gnome/settings-daemon/plugins/media-keys" = {
      # Free XF86Tools from GNOME's default Settings shortcut for the VPN key.
      control-center = "";
      control-center-static = lib.hm.gvariant.mkEmptyArray lib.hm.gvariant.type.string;
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/tailscale-vpn/"
      ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/tailscale-vpn" = {
      name = "Toggle Mullvad VPN";
      command = "${vpnToggle}/bin/tailscale-vpn-toggle";
      # keyd emits KEY_F13, which the default evdev XKB map names XF86Tools.
      binding = "XF86Tools";
    };
  };
}
