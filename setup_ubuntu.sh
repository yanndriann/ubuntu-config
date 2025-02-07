#!/bin/bash

# Aktifkan mode superuser
sudo -i

echo "Mengonfigurasi jaringan dengan Netplan..."
cat <<EOF > /etc/netplan/00-installer-config.yaml
network:
  ethernets:
    enp0s3:
      addresses:
        - 192.202.30.2/30
      nameservers:
        addresses:
          - 192.202.30.2
          - 192.202.30.1
      routes:
        - to: default
          via: 192.202.30.1
  version: 2
EOF

netplan apply
sleep 2

echo "Update dan install paket yang diperlukan..."
apt update -y
apt install -y bind9 apache2 php php-mysql php-cli php-cgi php-gd mariadb-server unzip -y

echo "Mengonfigurasi BIND9..."
cd /etc/bind

cat <<EOF > named.conf.default-zones
zone "adrian.kasir" {
    type master;
    file "/etc/bind/db.domain";
};

zone "30.202.192.in-addr.arpa" {
    type master;
    file "/etc/bind/db.ip";
};
EOF

cp db.local db.domain
cat <<EOF > db.domain
\$TTL 604800
@   IN  SOA adrian.kasir. root.adrian.kasir. (
        2
        604800
        86400
        2419200
        604800 )
@   IN  NS adrian.kasir.
@   IN  A 192.202.30.2
EOF

cp db.127 db.ip
cat <<EOF > db.ip
\$TTL 604800
@   IN  SOA adrian.kasir. root.adrian.kasir. (
        1
        604800
        86400
        2419200
        604800 )
@   IN  NS adrian.kasir.
2   IN  PTR adrian.kasir.
EOF

systemctl restart bind9

echo "Menambahkan nameserver ke resolv.conf..."
cat <<EOF > /etc/resolv.conf
nameserver 192.202.30.2
nameserver 192.202.30.1
EOF

echo "Mengonfigurasi database..."
mysql -u root <<EOF
CREATE DATABASE db_kasir;
EOF

echo "Mengunduh aplikasi web..."
cd /var/www/html
wget https://fnoor.my.id/app/pos.zip
unzip pos.zip
mysql db_kasir < db_toko.sql

cat <<EOF > config.php
<?php
date_default_timezone_set("Asia/Jakarta");
error_reporting(0);

\$host = "localhost";
\$user = "root";
\$pass = "123";
\$dbname = "db_kasir";

try {
    \$config = new PDO("mysql:host=\$host;dbname=\$dbname", \$user, \$pass);
} catch(PDOException \$e) {
    echo "KONEKSI GAGAL: " . \$e->getMessage();
}
\$view = "fungsi/view/view.php";
?>
EOF

chown -R www-data:www-data /var/www/html/

echo "Konfigurasi selesai!"
