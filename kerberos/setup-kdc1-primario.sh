#!/bin/bash
# Configuracion del KDC primario. Ejecutar EN kdc1.

set -e

sudo dnf install -y krb5-server krb5-workstation
sudo cp krb5.conf /etc/krb5.conf
sudo mkdir -p /var/kerberos/krb5kdc
sudo cp kdc.conf /var/kerberos/krb5kdc/kdc.conf

echo "Inicializando base de datos del realm (te pedira master password)..."
sudo kdb5_util create -s -r FIS.EPN.EC

echo "*/admin@FIS.EPN.EC *" | sudo tee /var/kerberos/krb5kdc/kadm5.acl

sudo systemctl enable --now krb5kdc
sudo systemctl enable --now kadmin

sudo firewall-cmd --add-port=88/tcp --add-port=88/udp --permanent
sudo firewall-cmd --add-port=464/tcp --add-port=464/udp --permanent
sudo firewall-cmd --add-port=749/tcp --permanent
sudo firewall-cmd --add-port=754/tcp --permanent
sudo firewall-cmd --reload

echo "Creando principals de usuarios y servicios..."
sudo kadmin.local -q "addprinc jperez"
sudo kadmin.local -q "addprinc malvan"
sudo kadmin.local -q "addprinc dnoboa"
sudo kadmin.local -q "addprinc -randkey ldap/ldap1.fis.epn.ec"
sudo kadmin.local -q "addprinc -randkey ldap/ldap2.fis.epn.ec"
sudo kadmin.local -q "addprinc -randkey HTTP/webserver.fis.epn.ec"
sudo kadmin.local -q "addprinc -randkey host/kdc1.fis.epn.ec"
sudo kadmin.local -q "addprinc -randkey host/kdc2.fis.epn.ec"

echo "Exportando keytabs de servicio..."
sudo kadmin.local -q "ktadd -k /etc/ldap1.keytab ldap/ldap1.fis.epn.ec"
sudo kadmin.local -q "ktadd -k /etc/ldap2.keytab ldap/ldap2.fis.epn.ec"
sudo kadmin.local -q "ktadd -k /etc/http.keytab HTTP/webserver.fis.epn.ec"
sudo kadmin.local -q "ktadd host/kdc1.fis.epn.ec"                 # va a /etc/krb5.keytab
sudo kadmin.local -q "ktadd -k /root/kdc2.keytab host/kdc2.fis.epn.ec"

echo "Preparando propagacion hacia kdc2..."
echo "kdc2.fis.epn.ec" | sudo tee /var/kerberos/krb5kdc/kpropd.acl
sudo kdb5_util dump /var/kerberos/krb5kdc/replica_datatrans

echo ""
echo "Pendiente manual:"
echo "  1. scp /root/kdc2.keytab a kdc2, fusionar con /etc/krb5.keytab via ktutil"
echo "  2. scp /var/kerberos/krb5kdc/stash a kdc2 (master key, canal seguro)"
echo "  3. En kdc2, crear /var/kerberos/krb5kdc/kpropd.acl con: host/kdc1.fis.epn.ec@FIS.EPN.EC"
echo "  4. sudo kprop -f /var/kerberos/krb5kdc/replica_datatrans kdc2.fis.epn.ec"
