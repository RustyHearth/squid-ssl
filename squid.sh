#!/bin/bash

if [ "$#" -ne 1 ]; then
  echo "Accepts Only Source Download URL."
  exit 1
fi

if [[ $1 != "http"* ]]; then
  echo "Please provide url"
  exit 1
fi

apt update -y && apt upgrade -y
apt install -y curl tar

apt install -y build-essential \
  autoconf \
  automake \
  make \
  libtool \
  pkg-config \
  libssl-dev \
  libcppunit-dev \
  libkrb5-dev \
  libsasl2-dev \
  libxml2-dev \
  libcap-dev \
  g++ \
  perl

apt install -y init-system-helpers \
  adduser \
  libc6 \
  libcap2 \
  libcom-err2 \
  libcrypt1 \
  libecap3 \
  libecap3-dev \
  libexpat1 \
  libgcc-s1 \
  libgnutls30t64 \
  libgssapi-krb5-2 \
  libkrb5-3 \
  libldap2 \
  libltdl7 \
  libnetfilter-conntrack3 \
  libnettle8t64 \
  libpam0g \
  libsasl2-2 \
  libstdc++6 \
  libsystemd0 \
  libsystemd-dev \
  libtdb1 \
  libxml2 \
  netbase \
  logrotate \
  squid-common \
  lsb-base \
  sysvinit-utils \
  libdbi-perl \
  ssl-cert \
  libcap2-bin \
  ca-certificates \
  squidclient \
  squid-cgi \
  squid-purge \
  smbclient \
  ufw \
  winbind \
  apparmor

curl -o squid.tar.gz $1
curl -o c-icap.tar.gz https://codeload.github.com/c-icap/c-icap-server/tar.gz/refs/tags/C_ICAP_0.6.4
rm -rf ./squid
rm -rf ./c-icap
mkdir ./squid && tar xvf squid.tar.gz -C ./squid --strip-components 1
mkdir ./c-icap && tar xvf c-icap.tar.gz -C ./c-icap --strip-components 1
cd ./c-icap
autoreconf -ifv .
./configure
make
make install
cd ..

cd ./squid
./bootstrap.sh
./configure --prefix=/usr \
  --localstatedir=/var \
  --libexecdir=/usr/lib/squid \
  --datadir=/usr/share/squid \
  --sysconfdir=/etc/squid \
  --with-default-user=proxy \
  --with-logdir=/var/log/squid \
  --with-pidfile=/run/squid.pid \
  --enable-ssl \
  --enable-ssl-crtd \
  --enable-security-file-certgen \
  --enable-icap-client \
  --enable-ecap \
  --enable-http-violations \
  --with-openssl \
  --enable-linux-netfilter \
  --enable-icmp \
  --enable-storeio=ufs,aufs,diskd,rock \
  --build=x86_64-linux-gnu \
  --includedir=${prefix}/include \
  --mandir=${prefix}/share/man \
  --infodir=${prefix}/share/info \
  --disable-arch-native \
  --enable-eui \
  --enable-esi \
  --runstatedir=/run \
  --with-systemd \
  --enable-follow-x-forwarded-for \
  BUILDCXX=g++

make
make install

chmod 4755 /usr/lib/squid/pinger
chown -R proxy:proxy /var/log/squid

sed -i 's/\/var\/cache\/squid/\/var\/spool\/squid/g' /etc/squid/squid.conf
sed -i '/cache_dir/s/^#//g' /etc/squid/squid.conf
mkdir -p /var/spool/squid
chown proxy:proxy /var/spool/squid
chown -R proxy:proxy /var/log/squid

mkdir -p /etc/squid/conf.d
touch /etc/squid/conf.d/debian.conf
echo "" >>/etc/squid/squid.conf
echo "include /etc/squid/conf.d/*.conf" >>/etc/squid/squid.conf

cp ../usr.sbin.squid /etc/apparmor.d/
touch /etc/apparmor.d/local/usr.sbin.squid
apparmor_parser -r /etc/apparmor.d/usr.sbin.squid

cp ../squid-init /etc/init.d/squid
update-rc.d squid defaults

cp ../squid.service /etc/systemd/system/
cp ../ssl-cert.service /etc/systemd/system/
systemctl daemon-reload

sed -i 's/3128$/3128 ssl-bump cert=\/etc\/squid\/cert\/squidCA.pem generate-host-certificates=on options=NO_SSLv3,NO_TLSv1,NO_TLSv1_1/g' /etc/squid/squid.conf
sed -i '/http_port 3128/a ssl_bump bump all' /etc/squid/squid.conf

mkdir -p /etc/squid/cert/
chown proxy:proxy /etc/squid/cert
openssl req -new -newkey rsa:4096 -sha256 -days 365 -nodes -x509 \
  -keyout /etc/squid/cert/squidCA.pem \
  -out /etc/squid/cert/squidCA.pem \
  -subj "/C=IL/ST=IL/L=Home/O=Home/OU=Home"
chmod 0400 /etc/squid/cert/squidCA.pem
mkdir -p /usr/local/share/ca-certificates
openssl x509 -inform PEM -in /etc/squid/cert/squidCA.pem -out /usr/local/share/ca-certificates/squidCA.crt
update-ca-certificates

/usr/lib/squid/security_file_certgen -c -s /var/spool/squid/ssl_db -M 4MB
chown -R proxy:proxy /var/spool/squid

sed -i '/ssl_bump bump all/asslcrtd_program \/usr\/lib\/squid\/security_file_certgen -s \/var\/lib\/ssl_db -M 4MB' /etc/squid/squid.conf
sed -i '/ssl_bump bump all/asslcrtd_children 3 startup=1 idle=1' /etc/squid/squid.conf

sed -i '/ssl_bump bump all/aicap_preview_size 1024' /etc/squid/squid.conf
sed -i '/ssl_bump bump all/aicap_preview_enable on' /etc/squid/squid.conf
sed -i '/ssl_bump bump all/aicap_service_failure_limit -1' /etc/squid/squid.conf
sed -i '/ssl_bump bump all/aadaptation_access srv_req allow all' /etc/squid/squid.conf
sed -i '/ssl_bump bump all/aadaptation_access srv_resp allow all' /etc/squid/squid.conf
sed -i '/ssl_bump bump all/aicap_service srv_req reqmod_precache 0 icap:\/\/127.0.0.1:1344\/echo' /etc/squid/squid.conf
sed -i '/ssl_bump bump all/aicap_service srv_resp respmod_precache 0 icap:\/\/127.0.0.1:1344\/echo' /etc/squid/squid.conf
sed -i '/ssl_bump bump all/aadaptation_send_client_ip on' /etc/squid/squid.conf
sed -i '/ssl_bump bump all/aadaptation_send_username on' /etc/squid/squid.conf
sed -i '/ssl_bump bump all/aicap_enable on' /etc/squid/squid.conf

#

#

systemctl enable squid
systemctl start squid
