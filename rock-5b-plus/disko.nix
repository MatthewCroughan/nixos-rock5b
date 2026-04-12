{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.hardware.rock-5b-plus;
  efiArch = pkgs.stdenv.hostPlatform.efiArch;
in
{
  options.hardware.rock-5b-plus = {
    image = {
      useDisko = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Use Disko to generate the disk image, the filesystems mount options will also be set due to usage of Disko";
      };
      format = lib.mkOption {
        type = lib.types.str;
        default = "ext4";
        description = "Filesystem format for systemd-repart";
      };
    };
  };
  imports = [
    inputs.disko.nixosModules.default
  ];
  config = lib.mkIf (cfg.image.generateImage && cfg.image.useDisko && cfg.enable) {
    assertions = [
      {
        assertion = cfg.image.useDisko && cfg.image.useRepart;
        message = ''
          The options hardware.rock-5b-plus.useDisko and hardware.rock-5b-plus.useRepart
          are mutually exclusive.
        '';
      }
    ];
    networking.hostId = lib.mkDefault "00000000";
    services.zfs.autoScrub.enable = lib.mkDefault true;
    boot.supportedFilesystems.zfs = true;
    disko.extraPostVM = ''
      ${lib.getExe' pkgs.coreutils "dd"} conv=notrunc,fsync if=${config.hardware.rockchip.platformFirmware}/u-boot-rockchip.bin of=$out/${config.hardware.rockchip.diskoImageName} bs=512 seek=64
    '';
    disko.devices = {
      disk = {
        disk1 = {
          imageSize = "10G";
          device = "/dev/sdX";
          type = "disk";
          content = {
            type = "gpt";
            partitions = {
              ESP = {
                type = "EF00";
                size = "2G";
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
            relatime = "on";
            xattr = "sa";
          };
          options = {
            ashift = "12";
            autotrim = "on";
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

