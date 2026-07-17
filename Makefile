# Makefile - Infraestructura de Identidad Segura para la FIS
# La mayoria de targets son documentacion ejecutable: orquestan via ssh
# los scripts de cada carpeta contra las VMs correspondientes.
# Ajustar SSH_USER y hostnames segun tu inventario real.

SSH_USER ?= usuario

.PHONY: help setup-ca setup-ldap setup-kerberos setup-integration \
        setup-web setup-haproxy test-failover test-all clean

help:
	@echo "Targets disponibles:"
	@echo "  setup-ca            - inicializa la CA raiz en la VM ca"
	@echo "  setup-ldap          - configura ldap1 (master) y muestra pasos de ldap2"
	@echo "  setup-kerberos      - configura kdc1 (primario)"
	@echo "  setup-integration   - copia sssd.conf de referencia"
	@echo "  setup-web           - despliega app.py + vhost Apache"
	@echo "  setup-haproxy       - despliega haproxy.cfg"
	@echo "  test-failover       - corre los 4 scripts de tests/"
	@echo "  test-all            - setup + test-failover"
	@echo "  clean                - limpia artefactos temporales de pruebas"

setup-ca:
	ssh -t $(SSH_USER)@ca.fis.epn.ec 'bash -s' < pki/00-init-ca.sh

setup-ldap:
	scp -r ldap/ldifs $(SSH_USER)@ldap1.fis.epn.ec:~/
	scp ldap/setup-ldap1-master.sh $(SSH_USER)@ldap1.fis.epn.ec:~/
	ssh -t $(SSH_USER)@ldap1.fis.epn.ec 'chmod +x setup-ldap1-master.sh && ./setup-ldap1-master.sh'
	@echo "Para ldap2: instalar openldap-servers, cargar esquemas,"
	@echo "copiar TLS y aplicar ldifs/syncrepl-consumer.ldif.example"

setup-kerberos:
	scp kerberos/krb5.conf kerberos/kdc.conf kerberos/setup-kdc1-primario.sh \
		$(SSH_USER)@kdc1.fis.epn.ec:~/
	ssh -t $(SSH_USER)@kdc1.fis.epn.ec 'chmod +x setup-kdc1-primario.sh && ./setup-kdc1-primario.sh'

setup-integration:
	scp integration/sssd.conf $(SSH_USER)@web.fis.epn.ec:/tmp/
	ssh -t $(SSH_USER)@web.fis.epn.ec 'sudo cp /tmp/sssd.conf /etc/sssd/sssd.conf && \
		sudo chmod 600 /etc/sssd/sssd.conf && \
		sudo authselect select sssd --force && \
		sudo systemctl enable --now sssd'

setup-web:
	scp web/app.py web/webapp-fis.service web/webserver-fis.conf \
		$(SSH_USER)@web.fis.epn.ec:~/

setup-haproxy:
	scp haproxy/haproxy.cfg $(SSH_USER)@lb.fis.epn.ec:/tmp/
	ssh -t $(SSH_USER)@lb.fis.epn.ec 'sudo cp /tmp/haproxy.cfg /etc/haproxy/haproxy.cfg && \
		sudo setsebool -P haproxy_connect_any on && \
		sudo systemctl restart haproxy'

test-failover:
	cd tests && bash test_crash.sh
	cd tests && bash test_particion.sh
	cd tests && bash test_kdc.sh
	@echo "Prueba de certificado expirado es semi-manual, ver tests/test_certificado_expirado.sh"

test-all: setup-ca setup-ldap setup-kerberos setup-integration setup-web setup-haproxy test-failover

clean:
	rm -f tests/*.csv
