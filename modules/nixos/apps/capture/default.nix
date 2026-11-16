{ pkgs, lib, config, ... }:

let
  tpl = import ../../../../lib/template.nix;
  captureGroup = "nocapture";
  captureUser = "mitmuser";
  caDir = "/var/lib/mitmproxy-ca";
  caCert = "${caDir}/mitmproxy-ca-cert.pem";

  prebuiltMitmproxyAvoidingRustBuildFailure = pkgs.stdenv.mkDerivation rec {
    pname = "mitmproxy-bin";
    version = "11.1.3";

    src = pkgs.fetchurl {
      url = "https://downloads.mitmproxy.org/${version}/mitmproxy-${version}-linux-x86_64.tar.gz";
      sha256 = "0m68pf41qzkww7lmw4d6lyd8dfvm6ipip2a3r7dakzcwf47smygk";
    };

    sourceRoot = ".";

    nativeBuildInputs = [ pkgs.autoPatchelfHook ];
    buildInputs = with pkgs; [ zlib openssl stdenv.cc.cc.lib ];

    installPhase = ''
      mkdir -p $out/bin
      cp mitmproxy mitmdump mitmweb $out/bin/
    '';

    meta = {
      description = "mitmproxy (prebuilt binary)";
      homepage = "https://mitmproxy.org";
    };
  };

  captureScript = pkgs.writeShellScriptBin "capture" (tpl ./capture.sh {
    inherit caDir caCert captureGroup captureUser;
    inherit (pkgs) nftables sudo tcpdump;
    mitmproxy = prebuiltMitmproxyAvoidingRustBuildFailure;
  });
in
{
  environment.systemPackages = with pkgs; [
    prebuiltMitmproxyAvoidingRustBuildFailure
    wireshark
    tcpdump
    nftables
    termshark
    captureScript
  ];

  users.groups.${captureGroup} = {};

  users.users.${captureUser} = {
    isSystemUser = true;
    group = captureGroup;
    home = "/var/lib/mitmproxy-ca";
  };

  users.users.ep-o1.extraGroups = [ "wireshark" captureGroup ];

  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark;
  };

  security.pki.certificateFiles = [ ../../../../secrets/mitmproxy-ca-cert.pem ];

  systemd.tmpfiles.rules = [
    "d ${caDir} 0755 ${captureUser} ${captureGroup} -"
    "d /var/lib/mitmproxy-captures 0775 ${captureUser} ${captureGroup} -"
    "L+ /home/ep-o1/captures - - - - /var/lib/mitmproxy-captures"
  ];

  environment.sessionVariables = {
    SSLKEYLOGFILE = "/tmp/sslkeys.log";
  };
}
