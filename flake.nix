{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    flake-parts.url = "github:hercules-ci/flake-parts";
    unf.url = "git+https://git.atagen.co/atagen/unf";
  };
  outputs = inputs@{ flake-parts, self, disko, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "aarch64-linux" ];
      flake = let
        system = "x86_64-linux";
      in {
        packages.${system}.docs = inputs.unf.lib.html {
          # a reference to your flake's self, for path replacement
          inherit self;
          # an instance of nixpkgs, required for evaluating the raw options
          pkgs = inputs.nixpkgs.legacyPackages.${system};
          # the name of your project, for page title etc
          projectName = "unf";
          # the intended base path for files referred to by your docs, ie. your public repo
          newPath = "https://git.atagen.co/atagen/unf";
          # the modules you wish to document
          modules = [ ./rock-5b-plus/disko.nix ];
          # any options the user wishes to pass to nixosOptionsDoc
          userOpts = { warningsAreErrors = false; };
        };
        nixosModules.rock5b-plus = ./rock-5b-plus;
        nixosConfigurations.rock5b = inputs.nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            ./rock-5b-plus
            ./rock-5b-plus/disko.nix
            disko.nixosModules.default
            {
              hardware.rock-5b-plus.enable = true;
              hardware.rock-5b-plus.image.repart.enable = true;
              hardware.rock-5b-plus.image.embedUboot = true;
            }
          ];
        };
      };
    };
}
