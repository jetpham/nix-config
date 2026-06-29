{ ... }:

{
  users.users.jet = {
    isNormalUser = true;
    description = "Jet";
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "render"
      "camera"
      "scanner"
      "lp"
    ];
  };
}
