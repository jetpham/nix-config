{ config, pkgs, ... }:

{
  imports = [
    ../../configuration.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "framework";

  # Tailscale and tailnet exposure are personal-laptop only.
  networking.firewall.checkReversePath = "loose";
  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 4096 ];

  services.tailscale.enable = true;

  systemd.services.tailscale-set-operator = {
    description = "Set Tailscale local preferences";
    after = [ "tailscaled.service" ];
    requires = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    serviceConfig.RemainAfterExit = true;
    path = [ pkgs.tailscale ];
    script = ''
      tailscale set --operator=jet
      tailscale set --exit-node-allow-lan-access=true
    '';
  };

  systemd.services.opencode-tailnet = {
    description = "Expose OpenCode on the tailnet";
    after = [
      "network-online.target"
      "tailscaled.service"
      "tailscale-set-operator.service"
    ];
    wants = [ "network-online.target" ];
    requires = [
      "tailscaled.service"
      "tailscale-set-operator.service"
    ];
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.tailscale
      pkgs.coreutils
      pkgs.gnugrep
    ];
    preStart = ''
      for attempt in {1..60}; do
        if tailscale status --json --peers=false | grep -q '"BackendState": *"Running"'; then
          tailscale serve --bg 4096
          exit 0
        fi

        sleep 1
      done

      echo "Timed out waiting for Tailscale to reach Running state"
      exit 1
    '';
    serviceConfig = {
      Type = "simple";
      User = "jet";
      Environment = [ "OPENCODE_DB=opencode.db" ];
      Restart = "always";
      RestartSec = 5;
      TimeoutStartSec = 75;
      ExecStart = "/etc/profiles/per-user/jet/bin/o serve --hostname 127.0.0.1 --port 4096";
      WorkingDirectory = config.users.users.jet.home;
    };
  };

  programs.steam.enable = true;

  # Personal media/gaming hardware support.
  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=1 card_label="OBS Virtual Camera" exclusive_caps=1
  '';

  services.udev.extraRules = ''
    # GameCube adapter USB device (vendor ID 057e, product ID 0337)
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="0337", MODE="0666"
    # GameCube adapter HID device (needed for Dolphin to access controllers)
    KERNEL=="hidraw*", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="0337", MODE="0666", GROUP="input"
  '';

  fileSystems."/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "size=32G"
      "mode=1777"
      "nosuid"
      "nodev"
    ];
  };
}
