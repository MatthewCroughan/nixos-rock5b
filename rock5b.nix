{ pkgs, lib, ... }:
{
  hardware.deviceTree.name = lib.mkDefault "rockchip/rk3588-rock-5b-plus.dtb";
  hardware.deviceTree.enable = lib.mkDefault true;
  hardware.enableRedistributableFirmware = lib.mkDefault true;
  nixpkgs.hostPlatform = lib.mkDefault (lib.recursiveUpdate (lib.systems.elaborate "aarch64-linux") {
    linux-kernel.target = "vmlinuz.efi";
    linux-kernel.installTarget = "zinstall";
  });
  boot.loader = lib.mkDefault {
    systemd-boot.enable = true;
  };
  boot.kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;
}
