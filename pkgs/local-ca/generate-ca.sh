mkdir -p $out

openssl ecparam -genkey -name prime256v1 -out $out/ca.key

openssl req -new -x509 -sha256 -days 3650 \
  -key $out/ca.key \
  -out $out/ca.crt \
  -subj "/CN=Service Plane Local CA/O=service-plane/OU=local"

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

rm -f $out/server.csr $out/ext.cnf $out/ca.srl
