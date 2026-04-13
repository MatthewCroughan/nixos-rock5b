{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.hardware.rock-5b-plus;
in
{
  options.hardware.rock-5b-plus = {
    image = {
      disko = {
        enable = lib.mkEnableOption "Generate a ZFS disk image using Disko. Enabling this will also enable systemd-boot and boot using UEFI therefore. The image can be built via config.system.build.diskoImages";
        compress = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Compress the result of the Disko image builder by using zstd";
        };
        imageSize = lib.mkOption {
          type = lib.types.str;
          default = "4G";
          description = "The image size passed to Disko. This will vary depending on the closure size of your config";
        };
      };
    };
  };
  config = lib.mkIf (cfg.image.disko.enable && cfg.enable) {
    assertions = [
      {
        assertion = !(cfg.image.disko.enable && cfg.image.repart.enable);
        message = ''
          The options hardware.rock-5b-plus.disko.enable and hardware.rock-5b-plus.repart.enable
          are mutually exclusive.
        '';
      }
    ];
    networking.hostId = lib.mkDefault "00000000";
    services.zfs.autoScrub.enable = lib.mkDefault true;
    boot = {
      loader.systemd-boot.enable = true;
      supportedFilesystems.zfs = true;
    };
    disko.imageBuilder.extraPostVM = lib.optionalString cfg.image.embedUboot ''
      ${lib.getExe' pkgs.coreutils "dd"} conv=notrunc,fsync if=${cfg.platformFirmware}/u-boot-rockchip.bin of=$out/${config.disko.devices.disk.disk1.imageName} bs=512 seek=64
    '' + lib.optionalString cfg.image.disko.compress ''
      ${pkgs.zstd}/bin/zstd --compress $out/*raw
      rm $out/*raw
    '';
    disko.memSize = 4096;
    disko.devices = {
      disk = {
        disk1 = {
         imageSize = cfg.image.disko.imageSize;
#          device = "/dev/sdX";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                type = "EF00";
                size = "2G";
                start = lib.mkIf cfg.image.embedUboot "16M";
                content = {
                  type = "filesystem";
                  format = "vfat";
                  mountpoint = "/boot";
                };
              };
              zfs = {
                size = "100%";
                content = {
                  type = "zfs";
                  pool = "rpool";
                };
              };
            };
          };
        };
      };
      zpool = {
        rpool = {
          type = "zpool";
          rootFsOptions = {
            acltype = "posixacl";
            compression = "zstd";
            dnodesize = "auto";
            normalization = "formD";
            relatime = "off";
            atime = "off";
            xattr = "sa";
          };
          options = {
            ashift = "12";
            autotrim = "on";
            autoexpand = "on";
          };
          datasets = {
            "root" = {
              type = "zfs_fs";
              options = {
                mountpoint = "legacy";
              };
              mountpoint = "/";
            };
            "nix" = {
              type = "zfs_fs";
              options.mountpoint = "legacy";
              mountpoint = "/nix";
            };
            "var" = {
              type = "zfs_fs";
              options.mountpoint = "legacy";
              mountpoint = "/var";
            };
            "home" = {
              type = "zfs_fs";
              mountpoint = "/home";
              options.mountpoint = "legacy";
            };
          };
        };
      };
    };
  };
}
