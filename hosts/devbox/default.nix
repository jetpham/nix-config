{
  config,
  lib,
  pkgs,
  ...
}:

let
  sshPublicKeys = (import ../../ssh-public-keys.nix).jet;
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
      allowedTCPPorts = [
        443
        6006
        8080
      ];
      allowedTCPPortRanges = [
        {
          from = 3000;
          to = 3999;
        }
        {
          from = 5000;
          to = 5999;
        }
        {
          from = 8000;
          to = 8999;
        }
      ];
    };
    checkReversePath = "loose";
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
      description = "OpenCode agent";
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

  environment.systemPackages = with pkgs; [
    btop
    curl
    fd
    git
    helix
    jq
    mdadm
    nh
    opencode
    ripgrep
    tailscale
    wget
    zellij
  ];

  environment.shellInit = ''
    umask 0002
  '';

  systemd.tmpfiles.rules = [
    "d /srv/dev 2775 root dev - -"
    "d /nix/var/nix/profiles/per-user/agent 0755 agent root - -"
  ];

  system.activationScripts.agentHomeDirs.text = ''
    ${pkgs.coreutils}/bin/install -d -o agent -g dev -m 0755 \
      /home/agent/.local \
      /home/agent/.local/share \
      /home/agent/.local/state \
      /home/agent/.local/state/nix \
      /home/agent/.local/state/nix/profiles
  '';

  systemd.services.opencode-agent = {
    description = "OpenCode daemon for devbox agents";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [
      bashInteractive
      coreutils
      git
      nix
      openssh
      sudo
    ];
    serviceConfig = {
      Type = "simple";
      User = "agent";
      Group = "dev";
      UMask = "0002";
      WorkingDirectory = "/srv/dev";
      StateDirectory = "opencode-agent";
      StateDirectoryMode = "2775";
      Environment = [
        "HOME=/home/agent"
        "OPENCODE_DB=opencode.db"
        "XDG_CONFIG_HOME=/home/agent/.config"
        "XDG_CACHE_HOME=/var/lib/opencode-agent/cache"
        "XDG_DATA_HOME=/var/lib/opencode-agent"
        "XDG_STATE_HOME=/var/lib/opencode-agent/state"
      ];
      ExecStart = "${pkgs.opencode}/bin/opencode serve";
      Restart = "always";
      RestartSec = 5;
    };
  };

  systemd.services.opencode-tailnet = {
    description = "Expose OpenCode on the devbox tailnet";
    after = [
      "network-online.target"
      "opencode-agent.service"
      "tailscaled.service"
    ];
    wants = [
      "network-online.target"
      "opencode-agent.service"
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
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --bg 4096";
      ExecStopPost = "-${pkgs.tailscale}/bin/tailscale serve reset";
    };
  };

  system.stateVersion = "25.05";
}
