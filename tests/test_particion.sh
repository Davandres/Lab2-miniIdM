#!/bin/bash
# Prueba de inyeccion de fallos: particion de red hacia ldap1 (iptables DROP).
# Ejecutar EN la VM lb. Ajustar IP_LDAP1 y ADMIN_PW antes de correr.

IP_LDAP1="192.168.122.113"   # AJUSTAR a la IP real de ldap1
ADMIN_PW="CAMBIAR"

echo "=== PRUEBA: Particion de red (iptables DROP hacia ldap1) ==="
echo "Bloqueando trafico hacia ldap1 ($IP_LDAP1): $(date +%s.%N)"
sudo iptables -A OUTPUT -d $IP_LDAP1 -j DROP

for i in $(seq 1 40); do
  START=$(date +%s.%N)
  RESULT=$(timeout 2 env LDAPTLS_REQCERT=allow ldapsearch -x -H ldaps://ldap.fis.epn.ec \
    -D "cn=admin,dc=fis,dc=epn,dc=ec" -w "$ADMIN_PW" \
    -b "dc=fis,dc=epn,dc=ec" "(uid=jperez)" uid 2>&1)
  if echo "$RESULT" | grep -q "uid: jperez"; then
    echo "$i,$START,OK"
  else
    echo "$i,$START,FAIL"
  fi
  sleep 0.5
done | tee resultado_particion.csv

echo "Restaurando trafico: $(date +%s.%N)"
sudo iptables -D OUTPUT -d $IP_LDAP1 -j DROP
echo "=== Prueba terminada. Ver resultado_particion.csv ==="
