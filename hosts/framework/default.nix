{
  config,
  lib,
  pkgs,
  ...
}:

let
  opencodeTailnetPort = 443;
  t3codeServerPort = 3774;
  t3codeTailnetPort = 8443;
  t3codeStateDir = "/var/lib/t3code-framework";
  pixel10TailscaleIpv4 = "100.106.98.89";
  pixel10TailscaleIpv6 = "fd7a:115c:a1e0::1433:6259";
  previewPortRange = "5100:5199";
  t3codePair = pkgs.writeShellApplication {
    name = "t3code-pair";
    runtimeInputs = [ pkgs.t3code ];
    text = ''
      exec t3 auth pairing create \
        --base-dir ${t3codeStateDir} \
        --base-url https://framework.taile9e84e.ts.net:${toString t3codeTailnetPort} \
        "$@"
    '';
  };
in

{
  imports = [
    ../../modules/nixos/common
    ./hardware-configuration.nix
  ];

  networking.hostName = "framework";
  networking.modemmanager.enable = false;

  users.users.jet.extraGroups = [ "dialout" ];
  environment.systemPackages = [ t3codePair ];

  networking.firewall.checkReversePath = "loose";
  networking.firewall.extraCommands = ''
    iptables -w -A nixos-fw -i tailscale0 -s ${pixel10TailscaleIpv4}/32 -p tcp --dport ${toString opencodeTailnetPort} -j nixos-fw-accept
    iptables -w -A nixos-fw -i tailscale0 -s ${pixel10TailscaleIpv4}/32 -p tcp --dport ${toString t3codeTailnetPort} -j nixos-fw-accept
    iptables -w -A nixos-fw -i tailscale0 -s ${pixel10TailscaleIpv4}/32 -p tcp --dport ${previewPortRange} -j nixos-fw-accept
  ''
  + lib.optionalString config.networking.enableIPv6 ''
    ip6tables -w -A nixos-fw -i tailscale0 -s ${pixel10TailscaleIpv6}/128 -p tcp --dport ${toString opencodeTailnetPort} -j nixos-fw-accept
    ip6tables -w -A nixos-fw -i tailscale0 -s ${pixel10TailscaleIpv6}/128 -p tcp --dport ${toString t3codeTailnetPort} -j nixos-fw-accept
    ip6tables -w -A nixos-fw -i tailscale0 -s ${pixel10TailscaleIpv6}/128 -p tcp --dport ${previewPortRange} -j nixos-fw-accept
  '';

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
      ExecStart = "${pkgs.opencode}/bin/opencode serve";
      ExecStopPost = "-${pkgs.tailscale}/bin/tailscale serve --https=${toString opencodeTailnetPort} off";
      WorkingDirectory = config.users.users.jet.home;
    };
  };

  systemd.services.t3code-framework = {
    description = "T3 Code server for jet";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    restartIfChanged = false;
    path = with pkgs; [
      bashInteractive
      coreutils
      git
      nix
      openssh
      t3code
    ];
    serviceConfig = {
      Type = "simple";
      User = "jet";
      WorkingDirectory = "/home/jet/Documents/nix-config";
      StateDirectory = "t3code-framework";
      StateDirectoryMode = "0700";
      Environment = [
        "HOME=/home/jet"
        "T3CODE_HOME=${t3codeStateDir}"
      ];
      ExecStartPre = "-${pkgs.t3code}/bin/t3 project add --base-dir ${t3codeStateDir} --title nix-config /home/jet/Documents/nix-config";
      ExecStart = "${pkgs.t3code}/bin/t3 serve --host 127.0.0.1 --port ${toString t3codeServerPort} --base-dir ${t3codeStateDir} --no-browser /home/jet/Documents/nix-config";
      Restart = "always";
      RestartSec = 5;
    };
  };

  systemd.services.t3code-tailnet = {
    description = "Expose T3 Code on the framework tailnet";
    after = [
      "network-online.target"
      "t3code-framework.service"
      "tailscaled.service"
    ];
    wants = [
      "network-online.target"
      "t3code-framework.service"
      "tailscaled.service"
    ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [
      coreutils
      gnugrep
      tailscale
    ];
    preStart = ''
      for attempt in {1..60}; do
        if tailscale status --json --peers=false | grep -q '"BackendState": *"Running"'; then
          exit 0
        fi

        sleep 1
      done

      echo "Timed out waiting for Tailscale to reach Running state"
      exit 1
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg --https=${toString t3codeTailnetPort} http://127.0.0.1:${toString t3codeServerPort}";
      ExecStopPost = "-${pkgs.tailscale}/bin/tailscale serve --https=${toString t3codeTailnetPort} off";
    };
  };

  programs.steam.enable = true;

  boot.extraModulePackages = with config.boot.kernelPackages; [ v4l2loopback ];
  boot.kernelModules = [ "v4l2loopback" ];
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=1 card_label="OBS Virtual Camera" exclusive_caps=1
  '';

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="0337", MODE="0666"
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
