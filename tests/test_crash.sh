#!/bin/bash
# Prueba de inyeccion de fallos: crash de servidor (kill -9) en ldap1.
# Ejecutar desde una VM de control con acceso SSH sin password interactivo
# (llaves configuradas) hacia ldap1, y openldap-clients instalado.
# Ajustar SSH_USER y ADMIN_PW antes de correr.

SSH_USER="usuario"
ADMIN_PW="CAMBIAR"

echo "=== PRUEBA: Crash de servidor (kill -9 en ldap1) ==="
echo "Timestamp inicio: $(date +%s.%N)"

ssh -t ${SSH_USER}@ldap1.fis.epn.ec "sudo pkill -9 slapd"
echo "slapd de ldap1 terminado: $(date +%s.%N)"

for i in $(seq 1 40); do
  START=$(date +%s.%N)
  RESULT=$(LDAPTLS_REQCERT=allow ldapsearch -x -H ldaps://ldap.fis.epn.ec \
    -D "cn=admin,dc=fis,dc=epn,dc=ec" -w "$ADMIN_PW" \
    -b "dc=fis,dc=epn,dc=ec" "(uid=jperez)" uid 2>&1)
  if echo "$RESULT" | grep -q "uid: jperez"; then
    echo "$i,$START,OK"
  else
    echo "$i,$START,FAIL"
  fi
  sleep 0.5
done | tee resultado_crash.csv

echo "=== Prueba terminada. Ver resultado_crash.csv ==="
echo "Restaurar: ssh -t ${SSH_USER}@ldap1.fis.epn.ec 'sudo systemctl start slapd'"
