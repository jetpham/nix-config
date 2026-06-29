{ ... }:

{
  boot.initrd.availableKernelModules = [
    "ahci"
    "nvme"
    "sd_mod"
    "usbhid"
    "xhci_pci"
  ];

  boot.swraid = {
    enable = true;
    mdadmConf = ''
      MAILADDR root
      ARRAY /dev/md/devbox-root metadata=1.2 name=devbox:root
    '';
  };

  zramSwap.enable = true;
}
