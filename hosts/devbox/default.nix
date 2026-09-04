{
  config,
  lib,
  pkgs,
  ...
}:

let
  azureCli = pkgs.azure-cli.withExtensions [ pkgs.azure-cli-extensions.azure-devops ];
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
      exec /run/wrappers/bin/sudo -u jet env T3CODE_HOME=${t3codeStateDir} \
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

  age = {
    identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      devbox-aws-env = {
        file = ../../secrets/devbox-aws.env.age;
        owner = "root";
        group = "dev";
        mode = "0440";
      };
      devbox-linear-env = {
        file = ../../secrets/devbox-linear.env.age;
        owner = "root";
        group = "dev";
        mode = "0440";
      };
    };
  };

  environment.etc = {
    "codex/managed_config.toml".text = ''
      cli_auth_credentials_store = "file"
      forced_login_method = "chatgpt"

      [mcp_servers.linear]
      url = "https://mcp.linear.app/mcp"
      bearer_token_env_var = "LINEAR_API_KEY"
      default_tools_approval_mode = "writes"
    '';
  };

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
    extraSetFlags = [
      "--operator=jet"
      "--ssh=true"
    ];
    openFirewall = true;
  };

  services.openssh.enable = false;

  users.groups.dev.gid = 999;
  users.users = {
    jet = {
      isNormalUser = true;
      uid = 1001;
      description = "Jet";
      extraGroups = [
        "dev"
        "wheel"
      ];
      openssh.authorizedKeys.keys = sshPublicKeys;
    };

  };

  security.sudo.extraRules = [
    {
      users = [ "jet" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  nix.settings.trusted-users = [ "jet" ];

  environment.systemPackages = [
    pkgs.awscli2
    pkgs.codex
    pkgs.gh
    pkgs.git
    pkgs.glab
    pkgs.helix
    pkgs.lsof
    pkgs.nh
    pkgs.nodejs_24
    pkgs.openssh
    pkgs.procps
    pkgs.tailscale
    azureCli
    t3code
    t3codePair
  ];

  environment.shellInit = ''
    umask 0002

    if [ -r ${config.age.secrets.devbox-aws-env.path} ]; then
      set -a
      . ${config.age.secrets.devbox-aws-env.path}
      set +a
    fi

    if [ -r ${config.age.secrets.devbox-linear-env.path} ]; then
      set -a
      . ${config.age.secrets.devbox-linear-env.path}
      set +a
    fi
  '';

  systemd.tmpfiles.rules = [
    "d /home/jet/dev 2775 jet dev - -"
    "d /nix/var/nix/profiles/per-user/jet 0755 jet root - -"
    "L+ /home/agent - - - - /home/jet"
    "L+ /srv/dev - - - - /home/jet/dev"
  ];

  system.activationScripts.jetHomeDirs.text = ''
    ${pkgs.coreutils}/bin/install -d -o jet -g dev -m 0700 \
      /home/jet/.codex \
      /home/jet/.codex/shell_snapshots
  '';

  systemd.services.t3code-agent = {
    description = "T3 Code server for devbox";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [
      config.age.secrets.devbox-aws-env.file
      config.age.secrets.devbox-linear-env.file
    ];
    path = [
      pkgs.awscli2
      pkgs.bashInteractive
      pkgs.coreutils
      pkgs.gh
      pkgs.git
      pkgs.glab
      pkgs.lsof
      pkgs.nix
      pkgs.nodejs_24
      pkgs.openssh
      pkgs.procps
      pkgs.sudo
      pkgs.tailscale
      azureCli
      t3code
    ];
    serviceConfig = {
      Type = "simple";
      User = "jet";
      Group = "dev";
      UMask = "0002";
      WorkingDirectory = "/home/jet/dev";
      StateDirectory = "t3code-agent";
      StateDirectoryMode = "2770";
      Environment = [
        "HOME=/home/jet"
        "CODEX_HOME=/home/jet/.codex"
        "T3CODE_HOME=${t3codeStateDir}"
        "XDG_CONFIG_HOME=/home/jet/.config"
      ];
      EnvironmentFile = [
        config.age.secrets.devbox-aws-env.path
        config.age.secrets.devbox-linear-env.path
      ];
      ExecStartPre = "-${t3code}/bin/t3 project add --base-dir ${t3codeStateDir} --title dev /home/jet/dev";
      ExecStart = "${t3code}/bin/t3 serve --host 127.0.0.1 --port ${toString t3codeServerPort} --base-dir ${t3codeStateDir} --no-browser /home/jet/dev";
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
      "tailscaled-set.service"
    ];
    wants = [
      "network-online.target"
      "t3code-agent.service"
      "tailscaled.service"
      "tailscaled-set.service"
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
