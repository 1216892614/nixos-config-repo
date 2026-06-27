{ pkgs }:

# Generates a local CA + wildcard certificate for *.local
# Used by the service-plane Traefik to serve HTTPS on local hostnames.
#
# NOTE: This regenerates on each Nix build (new random keys). This is fine
# because security.pki.certificateFiles atomically updates the system CA bundle
# at the same time Traefik gets the new cert. Browsers pick up changes on next
# request (Chrome via system bundle, Firefox via p11-kit on NixOS).

pkgs.runCommand "service-plane-local-ca" {
  nativeBuildInputs = [ pkgs.openssl ];
} ''
  mkdir -p $out

  # ── Generate CA ─────────────────────────────────────────────────────────
  openssl ecparam -genkey -name prime256v1 -out $out/ca.key

  openssl req -new -x509 -sha256 -days 3650 \
    -key $out/ca.key \
    -out $out/ca.crt \
    -subj "/CN=Service Plane Local CA/O=service-plane/OU=local"

  # ── Generate wildcard server cert signed by CA ──────────────────────────
  openssl ecparam -genkey -name prime256v1 -out $out/server.key

  openssl req -new -sha256 \
    -key $out/server.key \
    -out $out/server.csr \
    -subj "/CN=*.local/O=service-plane"

  cat > $out/ext.cnf << EOF
  authorityKeyIdentifier=keyid,issuer
  basicConstraints=CA:FALSE
  keyUsage=digitalSignature,keyEncipherment
  extendedKeyUsage=serverAuth
  subjectAltName=@alt_names

  [alt_names]
  DNS.1 = *.local
  DNS.2 = localhost
  IP.1 = 127.0.0.1
  EOF

  openssl x509 -req -sha256 -days 3650 \
    -in $out/server.csr \
    -CA $out/ca.crt \
    -CAkey $out/ca.key \
    -CAcreateserial \
    -extfile $out/ext.cnf \
    -out $out/server.crt

  # Cleanup intermediate files
  rm -f $out/server.csr $out/ext.cnf $out/ca.srl
''
