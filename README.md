
# Infraestructura de Identidad Segura para la FIS

PKI + LDAP + Kerberos + Alta Disponibilidad, implementado
sobre 7 VMs con Fedora Server (Qemu).

Cada VM: 1 nucleo, 2GB RAM y 10GB disco duro.

## Arquitectura

```
                    +----------------+
                    |  Balanceador   |
                    |  ldap.fis.epn.ec  (HAProxy, TCP passthrough TLS)
                    +--------+-------+
                             |
              +--------------+--------------+
              |                             |
        +-----v-----+                 +-----v-----+
        |   ldap1   |<--syncrepl------|   ldap2   |
        | (master)  |   (refreshAndPersist)| (replica) |
        +-----------+                 +-----------+
              ^                             ^
              |         Kerberos auth       |
        +-----+-----------------------------+-----+
        |                                         |
   +----v----+                              +-----v----+
   |  kdc1   |<-------- kprop/kpropd ------>|   kdc2   |
   | (primario) |     (propagacion manual)  | (secundario) |
   +---------+                              +----------+

        +-----------+          +-----------+
        |    ca     |          |    web    |
        | (CA raiz  |--------->| Apache+TLS|
        |  ECDSA)   |  firma   | +SPNEGO   |
        +-----------+  certs   | +Flask    |
                                +-----------+
```

| VM     | Rol                          | Hostname             |
|--------|-------------------------------|-----------------------|
| ca     | Autoridad Certificadora raiz  | ca.fis.epn.ec         |
| ldap1  | LDAP Master                   | ldap1.fis.epn.ec      |
| ldap2  | LDAP Replica                  | ldap2.fis.epn.ec      |
| kdc1   | KDC primario                  | kdc1.fis.epn.ec       |
| kdc2   | KDC secundario                | kdc2.fis.epn.ec       |
| lb     | HAProxy (VIP LDAP)            | ldap.fis.epn.ec       |
| web    | Servicio web protegido        | webserver.fis.epn.ec |

Realm Kerberos: `FIS.EPN.EC`. Base DN LDAP: `dc=fis,dc=epn,dc=ec`.

## Diseño de PKI

CA raíz autofirmada (ECDSA `prime256v1`), estructura estándar de OpenSSL
(`index.txt`, `serial`, `newcerts/`). Certificados de servidor emitidos con
`extendedKeyUsage = serverAuth, clientAuth` y validez de 365 días; la CA raíz
tiene validez de 10 años. Todos los nodos confían en `ca.cert.pem` como
trust anchor del sistema (`update-ca-trust`).

los certificados de `ldap1`/`ldap2` se emitieron solo
con `CN=<hostname propio>`. Al introducir el balanceador HAProxy en modo TCP
passthrough (Fase 6), el cliente termina negociando TLS directamente con el
backend, y el nombre `ldap.fis.epn.ec` (VIP) no coincide con el `CN` del
certificado — error `hostname does not match name in peer certificate`. La
solución correcta es re-emitir los certificados con SAN múltiple
(`DNS:ldap1.fis.epn.ec, DNS:ldap.fis.epn.ec`); para efectos de esta entrega
se optó por relajar la verificación de hostname en el cliente
(`LDAPTLS_REQCERT=allow`), dejando la solución robusta documentada como
mejora pendiente.

## Diseño de LDAP

Árbol organizacional reflejando la estructura real de la FIS:

```
dc=fis,dc=epn,dc=ec
├── ou=people
│   ├── ou=profesores
│   ├── ou=empleados
│   └── ou=estudiantes
│       ├── ou=software
│       ├── ou=computacion
│       └── ou=datos
└── ou=groups            (misma estructura, un posixGroup por categoria)
```

Esquemas: `core`, `cosine`, `nis` (para `posixAccount`/`posixGroup`),
`inetorgperson`. TLS obligatorio (LDAPS, puerto 636) en ambos nodos.
Replicación master→réplica vía `syncrepl` (overlay `syncprov` en ldap1,
`refreshAndPersist` en ldap2).

## Diseño de Kerberos

Realm `FIS.EPN.EC` con KDC primario (`kdc1`) y secundario (`kdc2`).
Propagación de base de datos vía `kdb5_util dump` + `kprop`/`kpropd`
(en Fedora empaquetado como `kprop.service`). Principals de usuario
(`jperez`, `malvan`, `dnoboa`) y de servicio (`ldap/ldap1`, `ldap/ldap2`,
`HTTP/webserver`, `host/kdc1`, `host/kdc2`) con llaves aleatorias exportadas
a keytabs.

la master key (`stash` file) nunca viaja por `kprop`
por diseño del protocolo — se transfirió manualmente entre `kdc1` y `kdc2`
por un canal separado (scp autenticado), reflejando la práctica real de
gestión de secretos en HA de Kerberos.

## Integración LDAP-Kerberos

SSSD como capa de integración: `id_provider = ldap` (identidad POSIX:
uid/gid/home/shell) + `auth_provider = krb5` (autenticación). Ambos backends
apuntan a los dos nodos redundantes (`ldap1`+`ldap2`, `kdc1`+`kdc2`),
heredando la HA de las fases anteriores. La sincronización `uid` (LDAP) ↔
nombre de `principal` (Kerberos) es manual por diseño de este laboratorio
(a diferencia de FreeIPA, que la automatizaría) — riesgo documentado:
inconsistencia si un admin borra uno de los dos y no el otro.

## Servicio web protegido

Apache (TLS con certificado propio) + `mod_auth_gssapi` (negociación SPNEGO)
como proxy hacia un backend Flask simple, inyectando la identidad
autenticada vía header `X-Remote-User`. Flujo: `Browser → kinit → Kerberos
ticket → SPNEGO Negotiate → Apache valida contra keytab → proxy a Flask`.

**Incidentes resueltos (documentados como parte del análisis de
seguridad):**
- El vhost SSL por defecto de Fedora (`ssl.conf`, certificado autofirmado)
  competía por el puerto 443 vía SNI — se deshabilitó explícitamente.
- SELinux (`httpd_can_network_connect`) bloquea por defecto que Apache haga
  proxy saliente — es una capa de contención intencional, se habilitó
  conscientemente.

## Balanceo de carga y HA

HAProxy en modo TCP (passthrough TLS, no termina la conexión) balanceando
`ldap1`/`ldap2` por `roundrobin` en el puerto 636, con `tcp-check` para
sacar automáticamente del pool a un nodo caído. Panel de estadísticas en
`http://ldap.fis.epn.ec:9000/haproxy?stats`.

## SELinux — hallazgo transversal

Prácticamente cada servicio de este proyecto requirió una intervención
explícita de SELinux en Fedora Server (contextos de archivo para
certificados/keytabs/stash, y booleanos para permitir conexiones salientes
de Apache y HAProxy). Se documenta como parte del análisis de seguridad:
SELinux actuó como una capa de defensa real y no como ruido, obligando a
otorgar permisos de forma explícita y auditable en cada punto de
integración entre servicios.

## Resultados de pruebas (evaluación experimental)

| Experimento                     | Métrica                    | Resultado obtenido |
|----------------------------------|-----------------------------|---------------------|
| Replicación LDAP                 | Retraso de propagación      | ~6 segundos (dominado por autenticación interactiva; ver tests) |
| Failover del KDC                 | Latencia de autenticación   | ~3.2 segundos (kinit interactivo tras detener kdc1) |
| Continuidad de lectura LDAP      | Disponibilidad con master caído | Lecturas exitosas 100% vía ldap2 |
| Balanceo de carga (HAProxy)      | Distribución round-robin    | Verificado alternancia ldap1/ldap2 |
| Autenticación SPNEGO end-to-end  | Éxito de negociación         | 200 OK, identidad correcta propagada |

Los CSV crudos de las pruebas de inyección de fallos formal (crash,
partición de red) se generan en `tests/resultado_*.csv` al correr los
scripts correspondientes.

## Estructura del repositorio

```
pki/            Scripts de inicialización de la CA y firma de certificados
ldap/           LDIFs del DIT, grupos, usuarios, TLS y replicación
kerberos/       krb5.conf, kdc.conf, scripts de setup kdc1/kdc2
integration/    sssd.conf de referencia
web/            Backend Flask, vhost Apache, unidad systemd
haproxy/        Configuración del balanceador
tests/          Scripts de inyección de fallos (crash, red, cert expirado, KDC)
docs/           Notas adicionales
Makefile        Orquestación vía SSH de todos los pasos anteriores
```

## Cómo reproducir

```bash
make setup-ca
make setup-ldap
make setup-kerberos
make setup-integration
make setup-web
make setup-haproxy
make test-failover
```

Cada target asume acceso SSH configurado (llaves, sin password interactivo)
hacia las VMs correspondientes; ajustar `SSH_USER` y los hostnames en el
`Makefile` según el inventario real.

## Declaración uso de la IA
Asistencia de IA (Claude) para depuración de configuración y estructuración de scripts y
documentación; todos los comandos fueron ejecutados y verificados
manualmente sobre la infraestructura real.
