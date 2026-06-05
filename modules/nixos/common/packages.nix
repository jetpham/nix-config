{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    bubblewrap
    docker
    docker-compose
    exfatprogs
    flatpak
    nh
    sane-airscan
    sane-backends
    simple-scan
    wget
  ];

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "jet" ];
  };
}
