{ ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 2;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.timeout = 1;
  boot.loader.systemd-boot.consoleMode = "max";
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  services.bootvine.enable = true;
  boot.consoleLogLevel = 3;
  console.earlySetup = true;

  # GitHub Dark High Contrast, matching Ghostty. Use its background and
  # foreground for the console's default black and white slots.
  console.colors = [
    "0a0c10"
    "ff9492"
    "26cd4d"
    "f0b72f"
    "71b7ff"
    "cb9eff"
    "39c5cf"
    "f0f3f6"
    "9ea7b3"
    "ffb1af"
    "4ae168"
    "f7c843"
    "91cbff"
    "dbb7ff"
    "56d4dd"
    "ffffff"
  ];
}
