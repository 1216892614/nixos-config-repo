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
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    elephant.url = "github:abenz1267/elephant";

    walker = {
      url = "github:abenz1267/walker";
      inputs.elephant.follows = "elephant";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    maccel.url = "github:Gnarus-G/maccel";

    zed.url = "github:zed-industries/zed";
  };

  outputs = { self, nixpkgs, home-manager, niri, noctalia, walker, elephant, nix-flatpak, maccel, zed, ... }@inputs:
  {
    nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        ./hosts/desktop

        niri.nixosModules.niri
        noctalia.nixosModules.default
        nix-flatpak.nixosModules.nix-flatpak
        maccel.nixosModules.default

        {
          nixpkgs.overlays = [
            (import ./overlays/default.nix)
            niri.overlays.niri
            (final: prev: {
              zed-editor = zed.packages.x86_64-linux.default;
            })
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
              noctalia.homeModules.default
              walker.homeManagerModules.default
            ];
            extraSpecialArgs = { inherit inputs; };
          };
        }

        {
          nix.settings = {
            substituters = [
              "https://noctalia.cachix.org"
              "https://walker.cachix.org"
              "https://cache.garnix.io"
            ];
            trusted-public-keys = [
              "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
              "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
              "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
            ];
            extra-substituters = [
              "https://noctalia.cachix.org"
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
        noctalia.nixosModules.default
        nix-flatpak.nixosModules.nix-flatpak
        maccel.nixosModules.default

        {
          nixpkgs.overlays = [
            (import ./overlays/default.nix)
            niri.overlays.niri
            (final: prev: {
              zed-editor = zed.packages.x86_64-linux.default;
            })
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
              noctalia.homeModules.default
              walker.homeManagerModules.default
            ];
            extraSpecialArgs = { inherit inputs; };
          };
        }

        {
          nix.settings = {
            substituters = [
              "https://noctalia.cachix.org"
              "https://walker.cachix.org"
              "https://cache.garnix.io"
            ];
            trusted-public-keys = [
              "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
              "walker.cachix.org-1:fG8q+uAaMqhsMxWjwvk0IMb4mFPFLqHjuvfwQxE4oJM="
              "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
            ];
            extra-substituters = [
              "https://noctalia.cachix.org"
              "https://walker.cachix.org"
              "https://cache.garnix.io"
            ];
          };
        }
      ];
    };
  };
}
