{ pkgs }:

pkgs.runCommand "service-plane-local-ca" {
  nativeBuildInputs = [ pkgs.openssl ];
} (builtins.readFile ./generate-ca.sh)
