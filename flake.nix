{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };
  outputs = inputs@{ flake-parts, self, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-linux" ];
      flake = {
        nixosModules.rock5b-plus = ./rock-5b-plus;
        nixosConfigurations.rock5b = inputs.nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          specialArgs = {
            inherit inputs;
          };
          modules = [
            ./rock-5b-plus
            {
              hardware.rock-5b-plus.enable = true;
              hardware.rock-5b-plus.image.generateImage = true;
              hardware.rock-5b-plus.image.useRepart = true;
            }
          ];
        };
      };
    };
}
