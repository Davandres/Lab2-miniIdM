#!/bin/bash
# Configuracion del KDC secundario. Ejecutar EN kdc2.
# IMPORTANTE: NO correr kdb5_util create aqui - la base llega por kprop.

set -e

sudo dnf install -y krb5-server krb5-workstation
sudo cp krb5.conf /etc/krb5.conf
sudo mkdir -p /var/kerberos/krb5kdc
sudo cp kdc.conf /var/kerberos/krb5kdc/kdc.conf

echo "host/kdc1.fis.epn.ec@FIS.EPN.EC" | sudo tee /var/kerberos/krb5kdc/kpropd.acl

sudo systemctl enable --now kprop.service   # en Fedora el daemon kpropd se
                                             # empaqueta como kprop.service
sudo firewall-cmd --add-port=88/tcp --add-port=88/udp --permanent
sudo firewall-cmd --add-port=464/tcp --add-port=464/udp --permanent
sudo firewall-cmd --add-port=754/tcp --permanent
sudo firewall-cmd --reload

echo ""
echo "Pendiente manual (ver instrucciones al final de setup-kdc1-primario.sh):"
echo "  1. Copiar /root/kdc2.keytab desde kdc1 y fusionarlo con /etc/krb5.keytab:"
echo "       sudo ktutil"
echo "       rkt /tmp/kdc2.keytab"
echo "       wkt /etc/krb5.keytab"
echo "       q"
echo "  2. Copiar el stash file desde kdc1:"
echo "       sudo cp /tmp/stash /var/kerberos/krb5kdc/stash"
echo "       sudo restorecon -v /var/kerberos/krb5kdc/stash   # SELinux!"
echo "  3. sudo systemctl enable --now krb5kdc"
