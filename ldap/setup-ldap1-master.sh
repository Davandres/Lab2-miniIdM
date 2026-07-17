#!/bin/bash
# Configuracion de ldap1 (master) - OpenLDAP en Fedora Server.
# Ejecutar EN la VM ldap1. Requiere haber corrido pki/02-gen-server-csr.sh
# y tener el certificado firmado de vuelta en ~/pki/ldap1.crt

set -e
BASE_DN="dc=fis,dc=epn,dc=ec"
DB_DN="olcDatabase={2}mdb,cn=config"   # verificar con:
                                       # sudo ldapsearch -Y EXTERNAL -H ldapi:/// \
                                       #   -b cn=config "(olcDatabase=*)" dn olcDatabase

echo "1) Instalando OpenLDAP..."
sudo dnf install -y openldap-servers openldap-clients
sudo systemctl enable --now slapd

echo "2) Cargando esquemas cosine, nis, inetorgperson..."
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/cosine.ldif || true
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/nis.ldif || true
sudo ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/inetorgperson.ldif || true

echo "3) Configurando suffix/rootDN (edita rootpw.ldif con tu hash de slappasswd antes)"
echo "   Ver ldifs/base-config.ldif.example"

echo "4) Cargando arbol de datos..."
ldapadd -x -D "cn=admin,${BASE_DN}" -W -f ldifs/01-tree.ldif
ldapadd -x -D "cn=admin,${BASE_DN}" -W -f ldifs/02-dit-organizacional.ldif
ldapadd -x -D "cn=admin,${BASE_DN}" -W -f ldifs/03-groups.ldif
ldapadd -x -D "cn=admin,${BASE_DN}" -W -f ldifs/04-usuarios-ejemplo.ldif

echo "5) TLS: copiar certs a /etc/openldap/certs/ y aplicar ldifs/tls-config.ldif.example"
echo "6) syncprov: aplicar ldifs/module-syncprov.ldif.example y ldifs/syncprov-overlay.ldif.example"

echo "Listo. Ver README.md para los pasos detallados de TLS y replicacion."
