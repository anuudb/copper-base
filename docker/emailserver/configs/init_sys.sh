#!/usr/bin/env bash

export EMAIL
export KEY_PATH

export FQDN=${FQDN:-$(hostname --fqdn)}
export DOMAIN=${DOMAIN:-$(hostname --domain)}
export REDIS_HOST=${REDIS_HOST:-"redis"}
export REDIS_PORT=${REDIS_PORT:-6379}
# hardcoded variable setting
#export DBUSER=${DBUSER:-"postfixuser"}
#export DBPASS=${DBPASS:-"postfixpassword"}
#export DBHOST=${DBHOST:-"mariadb"}
#export DEBUG=${DEBUG:-"true"}
#export RSPAMD_PASSWORD=${RSPAMD_PASSWORD:-"password"}

#Getting variables from the .env file
export DBUSER=${DBUSER}
export DBPASS=${DBPASS}
export DBHOST=${DBHOST}
export DEBUG=${DEBUG}
export RSPAMD_PASSWORD=${RSPAMD_PASSWORD}

#Variables need for OpenLdap-dovecot
export CN=${CN}
export DC1=${DC1}
export DC2=${DC2}
export DC3=${DC3}
export DNPASS=${DNPASS}
export OU=${OU}

if [ -z "$EMAIL" ]; then
  echo "[ERROR] Email Must be set !"
  exit 1
fi

if [ -z "$DBPASS" ]; then
  echo "[ERROR] MariaDB database password must be set !"
  exit 1
fi

if [ -z "$RSPAMD_PASSWORD" ]; then
  echo "[ERROR] Rspamd password must be set !"
  exit 1
fi

if [ -z "$FQDN" ]; then
  echo "[ERROR] The fully qualified domain name must be set !"
  exit 1
fi

if [ -z "$DOMAIN" ]; then
  echo "[ERROR] The domain name must be set !"
  exit 1
fi

# https://github.com/docker-library/redis/issues/53
if [[ "$REDIS_PORT" =~ [^[:digit:]] ]]
then
  REDIS_PORT=6379
fi

echo $HOSTNAME $DOMAIN $EMAIL

mkdir -p /var/mail/vhosts/$DOMAIN

chown -R vmail /var/mail
#SSL CONFIGURATION
chmod -R 755 /etc/letsencrypt/
export KEY_PATH=/etc/letsencrypt/live/"$HOSTNAME"/
files=$(shopt -s nullglob dotglob; echo $KEY_PATH)
echo $KEY_PATH
echo "Checking for existing certificates"



if [ "$DEBUG" = true ]; then
   mkdir -p $KEY_PATH
   openssl req -nodes -x509 -newkey rsa:4096 -keyout ${KEY_PATH}.privkey.pem -out ${KEY_PATH}.fullchain.pem -days 365 -subj "/C=US/ST=Oregon/L=Portland/O=Company Name/OU=Org/CN=nextgenmed.dyndns.org"
   echo "IN DEBUG MODE!!!! - GENERATED SELF SIGNED SSL KEY"
  else
if (( ${#files} )); then
       echo "Found existing keys!!"
   else
       echo "No Certicates Found!!"
       echo "Generating SSL Certificates with LetsEncrypt"
       letsencrypt certonly --standalone -d $HOSTNAME --noninteractive --agree-tos --email $EMAIL
       if (( ${#files} )); then
         echo "Certicate generation Successfull"
       else
         echo "Certicate generation failed."
         exit 1
       fi
   fi
  fi

chmod -R 755 /etc/letsencrypt/

 cp -R /etc/letsencrypt/ /cert
 sed -i.bak -e "s;%DFQN%;"${HOSTNAME}";g" "/etc/postfix/main.cf"
 sed -i.bak -e "s;%DOMAIN%;"${DOMAIN}";g" "/etc/postfix/main.cf"
 sed -i.bak -e "s;%DOMAIN%;"${DOMAIN}";g" "/etc/dovecot/conf.d/15-lda.conf"
 sed -i.bak -e "s;%DOMAIN%;"${DOMAIN}";g" "/etc/dovecot/conf.d/20-lmtp.conf"
 sed -i.bak -e "s;%DFQN%;"${HOSTNAME}";g" "/etc/dovecot/conf.d/10-ssl.conf"

# postfixadmin mail database architecture
 find /etc/postfix/sql/ -name "mysql_virtual*" -exec sed -i -e "s;postfixuser;"${DBUSER}";g" {} \;
 find /etc/postfix/sql/ -name "mysql_virtual*" -exec sed -i -e "s;postfixpassword;"${DBPASS}";g" {} \;
 find /etc/postfix/sql/ -name "mysql_virtual*" -exec sed -i -e "s;127.0.0.1;"${DBHOST}";g" {} \;
 
 # bellow configurations used with my database configuration
 #find /etc/postfix/mariadb-sql/ -name "mysql-virtual*" -exec sed -i -e "s;postfixuser;"${DBUSER}";g" {} \;
 #find /etc/postfix/mariadb-sql/ -name "mysql-virtual*" -exec sed -i -e "s;postfixpassword;"${DBPASS}";g" {} \;
 #find /etc/postfix/mariadb-sql/ -name "mysql-virtual*" -exec sed -i -e "s;127.0.0.1;"${DBHOST}";g" {} \;

 sed -i -e "s;redis;"${REDIS_HOST}";g" "/etc/rspamd/local.d/redis.conf"
 sed -i -e "s;redis;"${REDIS_HOST}";g" "/etc/rspamd/local.d/redis.conf"

 sed -i -e "s;postfixuser;"${DBUSER}";g" "/etc/dovecot/dovecot-sql.conf"
 sed -i -e "s;postfixpassword;"${DBPASS}";g" "/etc/dovecot/dovecot-sql.conf"
 sed -i -e "s;127.0.0.1;"${DBHOST}";g" "/etc/dovecot/dovecot-sql.conf"

 PASSWORD=$(rspamadm pw --quiet --encrypt --type pbkdf2 --password "${RSPAMD_PASSWORD}")
 sed -i "s;pwrd;"${RSPAMD_PASSWORD}";g" "/etc/rspamd/local.d/worker-controller.inc"

 #OpenLDAP with Dovecot conf
 sed -i.bak -e "s;%CN%;"${CN}";g" "/etc/dovecot/dovecot-ldap.conf.ext"
 sed -i.bak -e "s;%DC1%;"${DC1}";g" "/etc/dovecot/dovecot-ldap.conf.ext"
 sed -i.bak -e "s;%DC2%;"${DC2}";g" "/etc/dovecot/dovecot-ldap.conf.ext"
 sed -i.bak -e "s;%DC3%;"${DC3}";g" "/etc/dovecot/dovecot-ldap.conf.ext"
 sed -i.bak -e "s;%DNPASS%;"${DNPASS}";g" "/etc/dovecot/dovecot-ldap.conf.ext"
 sed -i.bak -e "s;%OU%;"${OU}";g" "/etc/dovecot/dovecot-ldap.conf.ext"

 #OpenLDAP with Postfix conf
 sed -i.bak -e "s;%CN%;"${CN}";g" "/etc/postfix/ldap/ldap-virtual-mailbox-alias-maps.cf"
 sed -i.bak -e "s;%DC1%;"${DC1}";g" "/etc/postfix/ldap/ldap-virtual-mailbox-alias-maps.cf"
 sed -i.bak -e "s;%DC2%;"${DC2}";g" "/etc/postfix/ldap/ldap-virtual-mailbox-alias-maps.cf"
 sed -i.bak -e "s;%DC3%;"${DC3}";g" "/etc/postfix/ldap/ldap-virtual-mailbox-alias-maps.cf"
 sed -i.bak -e "s;%DNPASS%;"${DNPASS}";g" "/etc/postfix/ldap/ldap-virtual-mailbox-alias-maps.cf"
 sed -i.bak -e "s;%OU%;"${OU}";g" "/etc/postfix/ldap/ldap-virtual-mailbox-alias-maps.cf"

 sed -i.bak -e "s;%CN%;"${CN}";g" "/etc/postfix/ldap/ldap-virtual-mailbox-maps.cf"
 sed -i.bak -e "s;%DC1%;"${DC1}";g" "/etc/postfix/ldap/ldap-virtual-mailbox-maps.cf"
 sed -i.bak -e "s;%DC2%;"${DC2}";g" "/etc/postfix/ldap/ldap-virtual-mailbox-maps.cf"
 sed -i.bak -e "s;%DC3%;"${DC3}";g" "/etc/postfix/ldap/ldap-virtual-mailbox-maps.cf"
 sed -i.bak -e "s;%DNPASS%;"${DNPASS}";g" "/etc/postfix/ldap/ldap-virtual-mailbox-maps.cf"
 sed -i.bak -e "s;%OU%;"${OU}";g" "/etc/postfix/ldap/ldap-virtual-mailbox-maps.cf"

 sed -i.bak -e "s;%CN%;"${CN}";g" "/etc/postfix/ldap/ldap-virtual-mailbox-domains.cf"
 sed -i.bak -e "s;%DC1%;"${DC1}";g" "/etc/postfix/ldap/ldap-virtual-mailbox-domains.cf"
 sed -i.bak -e "s;%DC2%;"${DC2}";g" "/etc/postfix/ldap/ldap-virtual-mailbox-domains.cf"
 sed -i.bak -e "s;%DC3%;"${DC3}";g" "/etc/postfix/ldap/ldap-virtual-mailbox-domains.cf"
 sed -i.bak -e "s;%DNPASS%;"${DNPASS}";g" "/etc/postfix/ldap/ldap-virtual-mailbox-domains.cf"
 sed -i.bak -e "s;%OU%;"${OU}";g" "/etc/postfix/ldap/ldap-virtual-mailbox-domains.cf"

 # Amavis
 sed -i.bak -e "s;%DOMAIN%;"${DOMAIN}";g" "/etc/amavis/conf.d/50-user"

 groupadd -g 5000 vmail && useradd -g vmail -u 5000 vmail -d /var/mail
 chown -R vmail:vmail /var/mail
 mkdir -p /var/mail/sieve/global
 cp -R /sieve/* /var/mail/sieve/global/
 sievec /var/mail/sieve/global/spam-global.sieve
 sievec /var/mail/sieve/global/report-ham.sieve
 rspamadm dkim_keygen -b 1024 -s 2018 -d ${DOMAIN} -k /var/lib/rspamd/dkim/2018.key > /var/lib/rspamd/dkim/2018.txt
 chown -R _rspamd:_rspamd /var/lib/rspamd/dkim
 chmod 440 /var/lib/rspamd/dkim/*
 chown -R vmail: /var/mail/sieve/
 cat /var/lib/rspamd/dkim/2018.txt
 touch /var/log/mail.log
 touch /var/log/mail.err
 chown root:root /etc/postfix/dynamicmaps.cf
 chown root:root /etc/postfix/main.cf
 chmod 0644 /etc/postfix/main.cf
 
 chgrp postfix /etc/postfix/sql/mysql_virtual_*.cf
 chmod u=rw,g=r,o= /etc/postfix/sql/mysql_virtual_*.cf

 # mydb configurations
 #chgrp postfix /etc/postfix/mariadb-sql/mysql-virtual_*.cf
 #chmod u=rw,g=r,o= /etc/postfix/mariadb-sql/mysql-virtual_*.cf



#For Postfix integration, enter the following from a terminal prompt:
 postconf -e 'content_filter = smtp-amavis:[127.0.0.1]:10024'

# security related functions #######################################################
sed -i "s;ENABLED=0;ENABLED=1;g" /etc/default/spamassassin

chmod -R 755 /amavis/

cp -R /amavis/* /etc/amavis/conf.d/
cp -R /rspamd/* /etc/rspamd/local.d/

sed -i "s;final_spam_destiny       = D_BOUNCE;final_spam_destiny       = D_DISCARD;g" /etc/amavis/conf.d/20-debian_defaults
# add spam info headers if at, or above that level
sed -i "s;sa_tag_level_deflt  = 2.0;sa_tag_level_deflt = -999;g" /etc/amavis/conf.d/20-debian_defaults
# add 'spam detected' headers at that level
sed -i "s;sa_tag2_level_deflt = 6.31;sa_tag2_level_deflt = 6.0;g" /etc/amavis/conf.d/20-debian_defaults
# triggers spam evasive actions
sed -i "s;sa_kill_level_deflt = 6.31;sa_kill_level_deflt = 21.0;g" /etc/amavis/conf.d/20-debian_defaults
# spam level beyond which a DSN is not sent
sed -i "s;sa_dsn_cutoff_level = 10;sa_dsn_cutoff_level = 4;g" /etc/amavis/conf.d/20-debian_defaults

# DKIM domain white listing
sed -i "s;ebay.at;${DOMAIN};g" /etc/amavis/conf.d/40-policy_banks



# change the host name and domain names in examples
sed -i "s;%HOSTNAME%;${HOSTNAME};g" /etc/amavis/conf.d/50-user
sed -i "s;%DOMAIN%;${DOMAIN};g" /etc/amavis/conf.d/50-user

# change the hostname and domain names in 50-user file




#systemctl start spamassassin.service
service spamassassin start
service amavis restart
service clamav-daemon restart

#####  End of Security related functions ################################

 # give the necessary permission for /var/mail folder to create 
 chmod a+rwxt -R /var/mail
 
 chmod a+w /var/log/mail*
 chown zeyple /etc/zeyple.conf
 touch /etc/postfix/virtual
 touch /etc/postfix/access
 postmap hash:/etc/postfix/virtual
 postmap hash:/etc/postfix/access

 service rsyslog start
 service postfix start
 service dovecot restart
 service rspamd start
 freshclam
 service spamassassin start
 service amavis start


 tail -f /dev/null
