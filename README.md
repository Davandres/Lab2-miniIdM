
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
