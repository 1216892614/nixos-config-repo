# 模板替换：将 @key@ 替换为对应值。
# path 类型使用 "${v}" 保留 string context（确保 sandbox 能访问 store 路径），
# 其他类型（int、derivation、string）使用 builtins.toString。
templateFile: vars:
  let
    coerce = v:
      if builtins.isPath v then "${v}"
      else builtins.toString v;
  in
  builtins.replaceStrings
    (map (k: "@${k}@") (builtins.attrNames vars))
    (map coerce (builtins.attrValues vars))
    (builtins.readFile templateFile)
