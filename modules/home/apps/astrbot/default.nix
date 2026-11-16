{ config, lib, pkgs, inputs, env, colors, mcpServers, ... }:
{
  home.file.".local/bin/astrbot".text = ''
    #!/usr/bin/env bash
    exec "${pkgs.uv}/bin/uvx" astrbot "''$@"
  '';
  home.file.".local/bin/astrbot".executable = true;
}
