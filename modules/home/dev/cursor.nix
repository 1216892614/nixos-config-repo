{ config, lib, pkgs, inputs, ... }:

{
  home.sessionVariables = {
    EDITOR = "cursor --wait";
    VISUAL = "cursor --wait";
  };

  home.packages = with pkgs; [
    nil
    pyright
  ];
}
