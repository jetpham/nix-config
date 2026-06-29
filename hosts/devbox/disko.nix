{ ... }:

{
  disko.devices = {
    disk = {
      nvme0 = {
        type = "disk";
        device = "/dev/nvme0n1";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                extraArgs = [
                  "-F"
                  "32"
                  "-n"
                  "BOOT"
                ];
                mountpoint = "/boot";
                mountOptions = [
                  "fmask=0077"
                  "dmask=0077"
                ];
              };
            };
            root = {
              size = "100%";
              content = {
                type = "mdraid";
                name = "devbox-root";
              };
            };
          };
        };
      };

      nvme1 = {
        type = "disk";
        device = "/dev/nvme1n1";
        content = {
          type = "gpt";
          partitions.root = {
            size = "100%";
            content = {
              type = "mdraid";
              name = "devbox-root";
            };
          };
        };
      };
    };

    mdadm.devbox-root = {
      type = "mdadm";
      level = 0;
      content = {
        type = "filesystem";
        format = "ext4";
        extraArgs = [
          "-L"
          "devbox-root"
        ];
        mountpoint = "/";
        mountOptions = [ "noatime" ];
      };
    };
  };
}
