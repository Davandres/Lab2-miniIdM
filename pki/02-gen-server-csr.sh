#!/bin/bash
# Genera llave privada ECDSA + CSR para un servidor.
# Ejecutar EN la VM del servicio (ldap1, ldap2, kdc1, kdc2, web).
# Uso: ./02-gen-server-csr.sh ldap1 ldap1.fis.epn.ec

set -e
SHORT=$1
FQDN=$2
if [ -z "$SHORT" ] || [ -z "$FQDN" ]; then
  echo "Uso: $0 <nombre-corto> <fqdn>"
  echo "ej:  $0 ldap1 ldap1.fis.epn.ec"
  exit 1
fi

mkdir -p ~/pki && cd ~/pki
openssl ecparam -name prime256v1 -genkey -noout -out ${SHORT}.key

openssl req -new -key ${SHORT}.key -out ${SHORT}.csr -sha256 \
  -subj "/C=EC/ST=Pichincha/L=Quito/O=EPN/OU=FIS/CN=${FQDN}"

echo "Generado ~/pki/${SHORT}.key y ~/pki/${SHORT}.csr"
echo "Enviar el CSR a la CA:  scp ~/pki/${SHORT}.csr usuario@ca.fis.epn.ec:/tmp/"
