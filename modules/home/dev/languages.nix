{ config, lib, pkgs, inputs, ... }:

let
  pkgConfigSearchPathForCargoBuildScripts = "${pkgs.openssl.dev}/lib/pkgconfig:${pkgs.wayland.dev}/lib/pkgconfig";
  jdkForStableLauncherPathAcrossRebuilds = pkgs.jdk21;
  cargoBuildJobsToPreventLinkerMemoryExhaustion = 4;
in
{
  home.packages = with pkgs; [
    rustup
    sccache
    cargo-edit
    cargo-watch
    cargo-expand

    clang
    lld
    (lib.hiPrio gcc)
    cmake
    gnumake
    pkg-config
    openssl
    openssl.dev  # headers + .pc for openssl-sys (e.g. cargo install rust-docs-mcp)
    wayland  # lib + wayland-client.pc for wayland-sys (Rust Wayland crates)

    python3
    pipx
    poetry

    nodejs_24
    pnpm
    deno
    bun

    jdk21
  ];

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.cargo/bin"
    "$HOME/.deno/bin"
    "$HOME/.bun/bin"
  ];

  home.sessionVariables = {
    RUSTUP_HOME = "$HOME/.rustup";
    CARGO_HOME = "$HOME/.cargo";
    JAVA_HOME = "$HOME/.local/lib/jdk21";
    PKG_CONFIG_PATH = pkgConfigSearchPathForCargoBuildScripts;
  };

  home.file.".local/lib/jdk21".source = jdkForStableLauncherPathAcrossRebuilds;

  home.file.".cargo/config.toml".text = ''
    [build]
    jobs = ${toString cargoBuildJobsToPreventLinkerMemoryExhaustion}
  '';
}
