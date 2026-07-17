#!/bin/bash
# Prueba de inyeccion de fallos: certificado TLS expirado en ldap1.
# Parte 1 se ejecuta EN la ca, parte 2 EN ldap1. Semi-manual por diseno.

echo "=== PARTE 1 (ejecutar en la VM ca) ==="
cat <<'EOF'
cd /etc/pki/fisCA
sudo openssl ca -config openssl.cnf -extensions server_cert \
  -startdate 20250101000000Z -enddate 20250102000000Z \
  -notext -md sha256 \
  -in csr/ldap1.csr -out certs/ldap1_expirado.crt
scp certs/ldap1_expirado.crt usuario@ldap1.fis.epn.ec:~/pki/
EOF

echo ""
echo "=== PARTE 2 (ejecutar en ldap1) ==="
cat <<'EOF'
sudo cp /etc/openldap/certs/ldap1.crt /etc/openldap/certs/ldap1_backup.crt
sudo cp ~/pki/ldap1_expirado.crt /etc/openldap/certs/ldap1.crt
sudo systemctl restart slapd

# Prueba: debe fallar con "Verify return code: 10 (certificate has expired)"
openssl s_client -connect ldap1.fis.epn.ec:636 \
  -CAfile /etc/pki/ca-trust/source/anchors/fis-ca.crt

# Restaurar:
sudo cp /etc/openldap/certs/ldap1_backup.crt /etc/openldap/certs/ldap1.crt
sudo systemctl restart slapd
EOF
