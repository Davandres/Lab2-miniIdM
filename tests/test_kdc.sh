#!/bin/bash
# Prueba de inyeccion de fallos: caida del KDC primario.
# Ejecutar desde la VM 'web' (o cualquier cliente con krb5-workstation
# y el keytab HTTP/webserver.fis.epn.ec accesible).
#
# CORRECCIONES respecto al primer intento:
#   1. ssh necesita -t para que sudo pueda pedir password interactivamente
#      en modo no-tty (o usar sudoers NOPASSWD para el comando puntual).
#   2. kinit -k -t requiere leer el keytab; como http.keytab quedo en
#      chmod 400 propiedad de apache (Fase 5), hay que leerlo con sudo.

SSH_USER="usuario"

echo "=== PRUEBA: Fallo del KDC primario ==="

ssh -t ${SSH_USER}@kdc1.fis.epn.ec "sudo systemctl stop krb5kdc"
echo "kdc1 detenido: $(date +%s.%N)"

sudo kdestroy 2>/dev/null
START=$(date +%s.%N)
sudo kinit -k -t /etc/httpd/http.keytab HTTP/webserver.fis.epn.ec
END=$(date +%s.%N)
echo "Latencia failover kinit: $(echo "$END - $START" | bc)"
sudo klist

ssh -t ${SSH_USER}@kdc1.fis.epn.ec "sudo systemctl start krb5kdc"
echo "kdc1 restaurado: $(date +%s.%N)"
