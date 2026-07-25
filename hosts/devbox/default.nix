{
  config,
  lib,
  pkgs,
  ...
}:

let
  sshPublicKeys = (import ../../ssh-public-keys.nix).jet;
  frameworkTailscaleIpv4 = "100.126.116.57";
  frameworkTailscaleIpv6 = "fd7a:115c:a1e0::8d01:7439";
  pixel10TailscaleIpv4 = "100.106.98.89";
  pixel10TailscaleIpv6 = "fd7a:115c:a1e0::1433:6259";
  previewPortRange = "5100:5199";
  t3codeServerPort = 3773;
  t3codeTailnetPort = 8443;
  t3codeStateDir = "/var/lib/t3code-agent";
  t3code = pkgs.t3code.override {
    enableGitHub = false;
    enableJujutsu = false;
    enableOpencode = false;
  };
  t3codePair = pkgs.writeShellApplication {
    name = "t3code-pair";
    runtimeInputs = [
      pkgs.coreutils
      t3code
    ];
    text = ''
      exec /run/wrappers/bin/sudo -u agent env T3CODE_HOME=${t3codeStateDir} \
        t3 auth pairing create \
        --base-dir ${t3codeStateDir} \
        --base-url https://devbox.taile9e84e.ts.net:${toString t3codeTailnetPort} \
      "$@"
    '';
  };
in

{
  imports = [
    ../../modules/nixos/common/boot.nix
    ../../modules/nixos/common/locale.nix
    ../../modules/nixos/common/nix.nix
    ./disko.nix
    ./hardware-configuration.nix
  ];

  networking.hostName = "devbox";
  networking.firewall = {
    enable = true;
    allowedUDPPorts = [ config.services.tailscale.port ];
    interfaces.tailscale0 = {
      allowedTCPPorts = [ t3codeTailnetPort ];
    };
    checkReversePath = "loose";
    extraCommands = ''
      iptables -w -A nixos-fw -i tailscale0 -s ${frameworkTailscaleIpv4}/32 -p tcp --dport ${previewPortRange} -j nixos-fw-accept
      iptables -w -A nixos-fw -i tailscale0 -s ${pixel10TailscaleIpv4}/32 -p tcp --dport ${previewPortRange} -j nixos-fw-accept
    ''
    + lib.optionalString config.networking.enableIPv6 ''
      ip6tables -w -A nixos-fw -i tailscale0 -s ${frameworkTailscaleIpv6}/128 -p tcp --dport ${previewPortRange} -j nixos-fw-accept
      ip6tables -w -A nixos-fw -i tailscale0 -s ${pixel10TailscaleIpv6}/128 -p tcp --dport ${previewPortRange} -j nixos-fw-accept
    '';
  };
  networking.useDHCP = lib.mkDefault true;

  hardware.enableRedistributableFirmware = true;
  services.fstrim.enable = true;
  services.irqbalance.enable = true;
  services.earlyoom.enable = true;

  services.tailscale = {
    enable = true;
    openFirewall = true;
  };

  services.openssh.enable = false;

  users.groups.dev = { };
  users.users = {
    jet = {
      isNormalUser = true;
      description = "Jet";
      extraGroups = [
        "dev"
        "wheel"
      ];
      openssh.authorizedKeys.keys = sshPublicKeys;
    };

    agent = {
      isNormalUser = true;
      description = "T3 Code agent";
      group = "dev";
      extraGroups = [ "wheel" ];
      openssh.authorizedKeys.keys = [ ];
    };
  };

  security.sudo.extraRules = [
    {
      users = [
        "agent"
        "jet"
      ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  nix.settings.trusted-users = [
    "agent"
    "jet"
  ];

  environment.systemPackages = [
    pkgs.claude-code
    pkgs.codex
    pkgs.git
    pkgs.helix
    pkgs.nh
    pkgs.tailscale
    t3code
    t3codePair
  ];

  environment.shellInit = ''
    umask 0002
  '';

  systemd.tmpfiles.rules = [
    "d /srv/dev 2775 root dev - -"
    "d /nix/var/nix/profiles/per-user/agent 0755 agent root - -"
  ];

  system.activationScripts.agentHomeDirs.text = ''
    ${pkgs.coreutils}/bin/install -d -o agent -g dev -m 0700 \
      /home/agent/.claude \
      /home/agent/.codex \
      /home/agent/.codex/shell_snapshots
  '';

  systemd.services.t3code-agent = {
    description = "T3 Code server for devbox agents";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = [
      pkgs.bashInteractive
      pkgs.coreutils
      pkgs.git
      pkgs.lsof
      pkgs.nix
      pkgs.openssh
      pkgs.sudo
      t3code
    ];
    serviceConfig = {
      Type = "simple";
      User = "agent";
      Group = "dev";
      UMask = "0002";
      WorkingDirectory = "/srv/dev";
      StateDirectory = "t3code-agent";
      StateDirectoryMode = "2770";
      Environment = [
        "HOME=/home/agent"
        "CLAUDE_CONFIG_DIR=/home/agent/.claude"
        "CODEX_HOME=/home/agent/.codex"
        "T3CODE_HOME=${t3codeStateDir}"
        "XDG_CONFIG_HOME=/home/agent/.config"
      ];
      ExecStartPre = "-${t3code}/bin/t3 project add --base-dir ${t3codeStateDir} --title dev /srv/dev";
      ExecStart = "${t3code}/bin/t3 serve --host 127.0.0.1 --port ${toString t3codeServerPort} --base-dir ${t3codeStateDir} --no-browser /srv/dev";
      Restart = "always";
      RestartSec = 5;
    };
  };

  systemd.services.t3code-tailnet = {
    description = "Expose T3 Code on the devbox tailnet";
    after = [
      "network-online.target"
      "t3code-agent.service"
      "tailscaled.service"
    ];
    wants = [
      "network-online.target"
      "t3code-agent.service"
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

  system.stateVersion = "25.05";
}
