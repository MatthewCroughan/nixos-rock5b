{
  pkgs,
  lib,
  config,
  modulesPath,
  ...
}:
let
  cfg = config.hardware.rock-5b-plus;
  efiArch = pkgs.stdenv.hostPlatform.efiArch;
in
{
  options.hardware.rock-5b-plus = {
    enable = lib.mkEnableOption "";
    platformFirmware = lib.mkPackageOption pkgs "platform firmware" {
      default = pkgs.ubootRock5ModelB;
    };
    zealous = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable options that get more hardware working such as nvme, wifi, etc. This has side effect of enabling more things than you may really want";
    };
    image = {
      embedUboot = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Embed U-Boot in the image so that it can be used on an SD card. The image will be available at config.system.build.image-with-uboot";
      };
      repart = {
        enable = lib.mkEnableOption "Generate a disk image using systemd-repart that boots using a sensible default UEFI boot flow, and place it in config.system.build.image";
        repart.format = lib.mkOption {
          type = lib.types.str;
          default = "ext4";
          description = "Filesystem format for systemd-repart";
        };
      };
    };
  };
  imports = [
    "${modulesPath}/image/repart.nix"
  ];
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      system.build.image-with-uboot = config.system.build.image.overrideAttrs (old: {
        nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.gptfdisk pkgs.util-linux ];
        preInstall = ''
          dd if=${cfg.platformFirmware}/u-boot-rockchip.bin of=${config.image.repart.imageFileBasename}.raw seek=64 conv=notrunc
        '';
      });
      hardware.deviceTree.name = "rockchip/rk3588-rock-5b-plus.dtb";
      warnings = lib.optional (config.boot.kernelPackages.kernel.kernelOlder "6.18") ''
        the kernel version you are using (${config.boot.kernelPackages.kernel.version}) is < 6.18, mainline support was not great back then, you should use a newer kernel.
      '';
    }
    (lib.mkIf cfg.zealous {
      hardware.enableRedistributableFirmware = lib.mkDefault true;
      boot.initrd.availableKernelModules = lib.mkDefault [
        "ahci_dwc"
        "phy_rockchip_naneng_combphy"
      ];
    })
    (lib.mkIf cfg.image.repart.enable {
      systemd.repart.enable = true;
      systemd.repart.partitions."30-root".Type = "root";
      boot = {
        initrd.supportedFilesystems."${cfg.image.format}" = true;
        loader.systemd-boot.enable = true;
      };
      fileSystems =
        {
          "/" = {
            device = "/dev/disk/by-label/nixos";
            fsType = "ext4";
          };
          "/boot" = {
            device = "/dev/disk/by-label/ESP";
            fsType = "vfat";
          };
        };
      image.repart = {
        name = "image";
        partitions = {
          "10-uboot-padding" = lib.mkIf cfg.image.embedUboot {
            repartConfig = {
              Type = "linux-generic";
              Label = "uboot";
              SizeMinBytes = "16M";
            };
          };
          "20-esp" = {
            contents = {
              "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source =
                "${pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
              "/EFI/Linux/${config.system.boot.loader.ukiFile}".source =
                "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
              "/loader/loader.conf".source = pkgs.writeText "loader.conf" ''
                timeout 5
                console-mode keep
              '';
            };
            repartConfig = {
              Type = "esp";
              Format = "vfat";
              Label = "ESP";
              SizeMinBytes = "2G";
              GrowFileSystem = true;
            };
          };
          "30-root" = {
            storePaths = [ config.system.build.toplevel ];
            contents."/boot".source = pkgs.runCommand "boot" { } "mkdir $out";
            repartConfig = {
              Type = "root";
              Format = "${cfg.image.format}";
              Label = "nixos";
              Minimize = "guess";
              GrowFileSystem = true;
            };
          };
        };
      };
    })
  ]);
}
