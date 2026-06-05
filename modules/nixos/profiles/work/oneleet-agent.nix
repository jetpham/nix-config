{ pkgs, ... }:

let
  oneleetAgent = pkgs.oneleet-agent;
  runtimeDeps = oneleetAgent.runtimeDeps;
in

{
  environment.systemPackages = [ oneleetAgent ];

  systemd.tmpfiles.rules = [
    "d /opt 0755 root root -"
    "L+ /opt/Oneleet - - - - ${oneleetAgent}/opt/Oneleet"
    "d /etc/oneleet 0755 root root -"
    "d /var/log/oneleet 0755 root root -"
    "d /var/opt/Oneleet 0755 root root -"

    # Oneleet hardcodes these FHS paths for user/remediation tasks.
    "d /usr/sbin 0755 root root -"
    "d /sbin 0755 root root -"
    "L+ /usr/bin/chage - - - - ${pkgs.shadow}/bin/chage"
    "L+ /usr/bin/getent - - - - ${pkgs.getent}/bin/getent"
    "L+ /usr/sbin/chpasswd - - - - ${pkgs.shadow}/bin/chpasswd"
    "L+ /usr/sbin/useradd - - - - ${pkgs.shadow}/bin/useradd"
    "L+ /usr/sbin/usermod - - - - ${pkgs.shadow}/bin/usermod"
    "L+ /usr/sbin/userdel - - - - ${pkgs.shadow}/bin/userdel"
    "L+ /sbin/shutdown - - - - ${pkgs.systemd}/bin/shutdown"
  ];

  systemd.services.oneleet-daemon = {
    description = "Oneleet Agent Daemon";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "dbus.service"
      "network-online.target"
    ];
    after = [
      "dbus.service"
      "network-online.target"
    ];
    path = runtimeDeps;

    serviceConfig = {
      Type = "simple";
      ExecStart = "${oneleetAgent}/bin/oneleet-cli";
      Restart = "always";
      RestartSec = 5;
      WorkingDirectory = "/opt/Oneleet";
      LogsDirectory = "oneleet";
    };
  };
}
