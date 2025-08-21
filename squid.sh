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
  --with-swapdir=/var/spool/squid \
  --with-pidfile=/run/squid.pid \
  --enable-ssl \
  --enable-security-file-certgen \
  --enable-icap-client \
  --enable-http-violations \
  --with-openssl \
  --enable-linux-netfilter \
  --enable-icmp
make
make install

chmo 4755 /usr/lib/squid/pinger
chown -R proxy:proxy /var/log/squid

sed -i '/cache_dir/s/^#//g' /etc/squid/squid.conf
chown proxy:proxy /var/spool/squid
chown -R proxy:proxy /var/log/squid

cp ./usr.sbin.squid /etc/apparmor.d/
touch /etc/apparmor.d/local/usr.sbin.squid
