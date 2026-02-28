{
  description = "NixOS desktop configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia-qs = {
      url = "github:noctalia-dev/noctalia-qs";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    elephant.url = "github:abenz1267/elephant";

    walker = {
      url = "github:abenz1267/walker";
      inputs.elephant.follows = "elephant";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
  };

  outputs = { self, nixpkgs, home-manager, niri, noctalia, noctalia-qs, walker, elephant, nix-flatpak, ... }@inputs:
  {
    nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/desktop

        niri.nixosModules.niri
        noctalia.nixosModules.default
        nix-flatpak.nixosModules.nix-flatpak

        {
          nixpkgs.overlays = [
            niri.overlays.niri
          ];
        }

        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            sharedModules = [
              niri.homeModules.niri
              noctalia.homeModules.default
              walker.homeManagerModules.default
            ];
            extraSpecialArgs = { inherit inputs; };
          };
        }

        {
          nix.settings = {
            substituters = [
              "https://walker.cachix.org"
            ];
            trusted-public-keys = [
              "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
            ];
            extra-substituters = [
              "https://walker.cachix.org"
            ];
          };
        }
      ];
    };
  };
}
