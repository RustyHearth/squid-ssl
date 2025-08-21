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
rm -rf ./squid
mkdir ./squid && tar xvf squid.tar.gz -C ./squid --strip-components 1
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
chown proxy:proxy /var/spool/squid
chown -R proxy:proxy /var/log/squid

mkdir /etc/squid/conf.d
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
