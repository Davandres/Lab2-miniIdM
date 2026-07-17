#!/bin/bash
# Inicializa la CA raiz de la FIS en la VM 'ca'
# Ejecutar como usuario con sudo en la VM ca.

set -e

sudo mkdir -p /etc/pki/fisCA/{certs,crl,newcerts,private,csr}
sudo chmod 700 /etc/pki/fisCA/private
cd /etc/pki/fisCA
sudo touch index.txt
echo 1000 | sudo tee serial > /dev/null

sudo tee /etc/pki/fisCA/openssl.cnf > /dev/null <<'EOF'
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = /etc/pki/fisCA
certs             = $dir/certs
new_certs_dir     = $dir/newcerts
database          = $dir/index.txt
serial            = $dir/serial
private_key       = $dir/private/ca.key.pem
certificate       = $dir/certs/ca.cert.pem
default_md        = sha256
policy            = policy_loose
default_days      = 730
copy_extensions   = copy

[ policy_loose ]
countryName             = optional
stateOrProvinceName     = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ v3_intermediate_ca ]
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[ server_cert ]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
EOF

sudo openssl ecparam -name prime256v1 -genkey -noout -out private/ca.key.pem
sudo chmod 400 private/ca.key.pem

sudo openssl req -config openssl.cnf -key private/ca.key.pem \
  -new -x509 -days 3650 -sha256 -extensions v3_intermediate_ca \
  -out certs/ca.cert.pem \
  -subj "/C=EC/ST=Pichincha/L=Quito/O=EPN/OU=FIS/CN=FIS Root CA"

echo "CA raiz creada. Distribuir certs/ca.cert.pem a todas las VMs como trust anchor:"
echo "  sudo cp ca.cert.pem /etc/pki/ca-trust/source/anchors/fis-ca.crt"
echo "  sudo update-ca-trust"
