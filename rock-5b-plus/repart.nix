{ config }:
{
 name = "image";
 partitions = {
   #"10-uboot-padding" = {
   #  repartConfig = {
   #    Type = "linux-generic";
   #    Label = "uboot-padding";
   #    SizeMinBytes = "10M";
   #  };
   #};
   "20-esp" = {
     contents = {
       "/EFI/EDK2-UEFI-SHELL/SHELL.EFI".source = "${config.pkgs.edk2-uefi-shell.overrideAttrs { env.NIX_CFLAGS_COMPILE = "-Wno-error=maybe-uninitialized"; }}/shell.efi";
       "/EFI/BOOT/BOOT${lib.toUpper efiArch}.EFI".source = "${config.pkgs.systemd}/lib/systemd/boot/efi/systemd-boot${efiArch}.efi";
       "/EFI/Linux/${config.system.boot.loader.ukiFile}".source = "${config.system.build.uki}/${config.system.boot.loader.ukiFile}";
       "/loader/loader.conf".source = config.pkgs.writeText "loader.conf" ''
         timeout 5
         console-mode keep
       '';
       "/loader/entries/shell.conf".source = config.pkgs.writeText "shell.conf" ''
         title  EDK2 UEFI Shell
         efi    /EFI/EDK2-UEFI-SHELL/SHELL.EFI
       '';
     };
     repartConfig = {
       Type = "esp";
       Format = "vfat";
       Label = "ESP";
       SizeMinBytes = "500M";
       GrowFileSystem = true;
     };
   };
   "30-root" = {
     storePaths = [ config.system.build.toplevel ];
     contents."/boot".source = config.pkgs.runCommand "boot" { } "mkdir $out";
     repartConfig = {
       Type = "root";
       Format = "ext4";
       Label = "nixos";
       Minimize = "guess";
       GrowFileSystem = true;
     };
   };
 };
}
