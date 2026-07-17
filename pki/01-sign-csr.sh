#!/bin/bash
# Firma un CSR de servidor con la CA de la FIS.
# Uso: ./01-sign-csr.sh <nombre>
#   ej: ./01-sign-csr.sh ldap1   (espera csr/ldap1.csr, genera certs/ldap1.crt)
#
# Ejecutar en la VM 'ca', con el .csr ya copiado a /etc/pki/fisCA/csr/

set -e
NAME=$1
if [ -z "$NAME" ]; then
  echo "Uso: $0 <nombre-sin-extension>"
  exit 1
fi

cd /etc/pki/fisCA
sudo openssl ca -config openssl.cnf -extensions server_cert \
  -days 365 -notext -md sha256 \
  -in csr/${NAME}.csr -out certs/${NAME}.crt

echo "Certificado firmado: certs/${NAME}.crt"
openssl x509 -in certs/${NAME}.crt -noout -subject -issuer -dates

echo ""
echo "NOTA de diseno (para el informe): los certificados de servidor se emiten"
echo "solo con el CN del hostname propio. Si el servicio se consume detras de"
echo "un balanceador (ver haproxy/), se recomienda re-emitir con SAN multiple:"
echo "  -addext \"subjectAltName=DNS:${NAME}.fis.epn.ec,DNS:ldap.fis.epn.ec\""
