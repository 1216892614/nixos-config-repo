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


    elephant.url = "github:abenz1267/elephant";

    walker = {
      url = "github:abenz1267/walker";
      inputs.elephant.follows = "elephant";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    maccel.url = "github:Gnarus-G/maccel";

  };

  outputs = { self, nixpkgs, home-manager, niri, walker, elephant, nix-flatpak, maccel, ... }@inputs:
  {
    nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/desktop

        niri.nixosModules.niri
        nix-flatpak.nixosModules.nix-flatpak
        maccel.nixosModules.default

        {
          nixpkgs.overlays = [
            (import ./overlays/default.nix)
            niri.overlays.niri
          ];
          programs.niri.package = nixpkgs.lib.mkForce niri.packages.x86_64-linux.niri-unstable;
        }

        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "hm-bak2";
            sharedModules = [
              walker.homeManagerModules.default
            ];
            extraSpecialArgs = { inherit inputs; };
          };
        }

        {
          nix.settings = {
            substituters = [
              "https://walker.cachix.org"
              "https://cache.garnix.io"
            ];
            trusted-public-keys = [
              "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
              "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
            ];
            extra-substituters = [
              "https://walker.cachix.org"
              "https://cache.garnix.io"
            ];
          };
        }
      ];
    };

    nixosConfigurations.ep-laptop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/ep-laptop

        niri.nixosModules.niri
        nix-flatpak.nixosModules.nix-flatpak
        maccel.nixosModules.default

        {
          nixpkgs.overlays = [
            (import ./overlays/default.nix)
            niri.overlays.niri
          ];
          programs.niri.package = nixpkgs.lib.mkForce niri.packages.x86_64-linux.niri-unstable;
        }

        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "hm-bak2";
            sharedModules = [
              walker.homeManagerModules.default
            ];
            extraSpecialArgs = { inherit inputs; };
          };
        }

        {
          nix.settings = {
            substituters = [
              "https://walker.cachix.org"
              "https://cache.garnix.io"
            ];
            trusted-public-keys = [
              "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
              "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
            ];
            extra-substituters = [
              "https://walker.cachix.org"
              "https://cache.garnix.io"
            ];
          };
        }
      ];
    };
  };
}
