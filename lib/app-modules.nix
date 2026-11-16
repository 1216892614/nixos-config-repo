dir:
  if builtins.pathExists dir then
    let
      entries = builtins.readDir dir;
      names = builtins.filter
        (name: entries.${name} == "directory" && builtins.pathExists (dir + "/${name}/default.nix"))
        (builtins.attrNames entries);
    in map (name: dir + "/${name}/default.nix") names
  else []
