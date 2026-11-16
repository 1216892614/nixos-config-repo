{ pkgs, ... }:

let
  localCA = pkgs.callPackage ../../pkgs/local-ca {};
  servicePlaneHostsBypassClashFakeIpAndResolvedMdns = {
    "127.0.0.1" = [
      "plane.local"       # Service Plane portal (主页仪表板)
      "comfyui.local"     # ComfyUI (scale-to-zero, GPU)
      "llm.local"         # LLM llama.cpp (scale-to-zero, GPU)
      "traefik.local"     # Traefik dashboard
    ];
  };
  systemTrustBundleForLocalHttps = [ "${localCA}/ca.crt" ];
in
{
  networking.hosts = servicePlaneHostsBypassClashFakeIpAndResolvedMdns;
  security.pki.certificateFiles = systemTrustBundleForLocalHttps;

  environment.etc."service-plane/ca.crt".source = "${localCA}/ca.crt";
  environment.etc."service-plane/server.crt".source = "${localCA}/server.crt";
  environment.etc."service-plane/server.key".source = "${localCA}/server.key";
}
