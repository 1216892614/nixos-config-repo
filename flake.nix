{
  description = "NixOS desktop configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-qq.url = "git+https://github.com/NixOS/nixpkgs?ref=nixos-unstable&shallow=1"; # independent QQ package source

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri-glass = {
      url = "github:zaroutt/Niri-glass";
      inputs.nixpkgs.follows = "nixpkgs";
      # niri-glass 用上游 niri flake 构建；它自带锁定的 nixpkgs（glibc 不同），
      # 会与系统 mesa（/run/opengl-driver）的 glibc 不匹配 → EGL 初始化失败黑屏。
      inputs.niri.inputs.nixpkgs.follows = "nixpkgs";
    };


    elephant.url = "github:abenz1267/elephant";

    walker = {
      url = "github:abenz1267/walker";
      inputs.elephant.follows = "elephant";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    # 临时指向 PR#129 修复分支，解决 7.3 内核 .ko.cer 缺失问题
    # 上游合并后改回 "github:Gnarus-G/maccel"
    maccel.url = "git+https://github.com/chrisheib/maccel.git?ref=fix/nixos-kernel-module-install";

  };

  outputs = { self, nixpkgs, home-manager, niri, niri-glass, walker, elephant, nix-flatpak, maccel, ... }@inputs:
  let
    # niri-glass 的 niri 跟随系统 nixpkgs 构建（与 /run/opengl-driver 的 mesa 共用同一 glibc）；
    # niri 26.04 的 libdisplay-info-sys 0.3 要求 libdisplay-info < 0.4，nixpkgs 提供 _0_3 版本。
    niriGlassPkg = niri-glass.packages.x86_64-linux.niri-glass.override {
      libdisplay-info = nixpkgs.legacyPackages.x86_64-linux.libdisplay-info_0_3;
    };
  in
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
          programs.niri.package = nixpkgs.lib.mkForce niriGlassPkg;
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
          programs.niri.package = nixpkgs.lib.mkForce niriGlassPkg;
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
