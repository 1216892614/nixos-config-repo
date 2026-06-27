{ pkgs, ... }:

# ── Local DNS + TLS: service plane hostnames ───────────────────────────────
# Maps service-plane HTTP endpoints to 127.0.0.1 via /etc/hosts.
# This bypasses all DNS chain complications (Clash TUN fake-ip, resolved mDNS)
# because glibc resolves /etc/hosts before querying DNS (nsswitch: files dns).
#
# Also provisions a trusted local CA for HTTPS on *.local domains.
# Traefik listens on 127.0.0.1:443 (HTTPS) + :80 (redirect to HTTPS).

let
  localCA = pkgs.callPackage ../../pkgs/local-ca.nix {};
in
{
  networking.hosts = {
    "127.0.0.1" = [
      "files.local"       # FileBrowser (scale-to-zero)
      "agent.local"       # Pi Agent (opencode serve)
      "traefik.local"     # Traefik dashboard
      "plane.local"       # Service Plane portal (future)
    ];
  };

  # ── Trust the self-signed CA system-wide ─────────────────────────────────
  # This makes Chrome, curl, wget, and all glibc/openssl clients trust *.local
  # certificates without manual import. Firefox on NixOS uses p11-kit which
  # also reads from this bundle.
  security.pki.certificateFiles = [ "${localCA}/ca.crt" ];

  # ── Expose CA + cert paths for home-manager to mount into Traefik ────────
  # The derivation output path is stable per-build; service-plane.nix reads it.
  environment.etc."service-plane/ca.crt".source = "${localCA}/ca.crt";
  environment.etc."service-plane/server.crt".source = "${localCA}/server.crt";
  environment.etc."service-plane/server.key".source = "${localCA}/server.key";
}
