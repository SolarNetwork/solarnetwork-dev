#!/bin/bash

JAVAVER=$1
PGVER=$2
HOST=$3
DESKTOP_PACKAGES=${@:4}

grep -q $HOST /etc/hosts
if [ $? -ne 0 ]; then
	echo "Setting up $HOST host"
	echo $HOST >>/tmp/hostname.new
	chmod 644 /tmp/hostname.new
	sudo chown root:root /tmp/hostname.new
	sudo cp -a /etc/hostname /etc/hostname.bak
	sudo mv -f /tmp/hostname.new /etc/hostname

	sudo hostname $HOST

	sed "s/^127.0.0.1[[:space:]]*localhost/127.0.0.1 $HOST localhost/" /etc/hosts >/tmp/hosts.new
	chmod 644 /tmp/hosts.new
	sudo chown root:root /tmp/hosts.new
	sudo cp -a /etc/hosts /etc/hosts.bak
	sudo mv -f /tmp/hosts.new /etc/hosts
fi

grep -q '/swapfile' /etc/fstab
if [ $? -ne 0 ]; then
	echo -e '\nCreating swapfile...'
	sudo fallocate -l 1G /swapfile
	sudo chmod 600 /swapfile
	sudo mkswap /swapfile
	sudo swapon /swapfile
	echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

echo -e '\nUpdating package cache...'
sudo apt-get update

echo -e '\nUpgrading outdated packages...'
sudo apt-get upgrade -y

echo -e '\nInstalling language-pack...'
sudo apt-get install -y language-pack-en

if [ -n "$DESKTOP_PACKAGES" ]; then
	echo -e "\nInstalling Desktop Packages: $DESKTOP_PACKAGES"
	sudo apt-get install -y $DESKTOP_PACKAGES
fi

echo -e "\nInstalling Postgres $PGVER and Java $JAVAVER..."
javaPkg=openjdk-$JAVAVER-jdk
if [ -z "$DESKTOP_PACKAGES" ]; then
	javaPkg="${javaPkg}-headless"
fi
sudo apt-get install -y postgresql-$PGVER postgresql-$PGVER-plv8 postgresql-contrib-$PGVER git git-flow $javaPkg librxtx-java

if [ -n "$DESKTOP_PACKAGES" ]; then
	echo -e '\nInstalling web browsers...'
	# Note libwebkitgtk is required for Eclipse to support an internal browser
	sudo apt-get install -y firefox libwebkitgtk-3.0-0
fi

if [ -e /usr/share/java/RXTXcomm.jar -a -d /usr/lib/jvm/java-$JAVAVER-openjdk-i386/jre/lib/ext \
		-a ! -e /usr/lib/jvm/java-$JAVAVER-openjdk-i386/jre/lib/ext/RXTXcomm.jar ]; then
	echo -e '\nLinking RXTX JAR to JRE...'
	sudo ln -s /usr/share/java/RXTXcomm.jar \
		/usr/lib/jvm/java-$JAVAVER-openjdk-i386/jre/lib/ext/RXTXcomm.jar
fi

# Add the solardev user if it doesn't already exist, password solardev
getent passwd solardev >/dev/null
if [ $? -ne 0 ]; then
	echo -e '\nAdding solardev user.'
	sudo useradd -c 'SolarNet Developer' -m -U solardev
	sudo sh -c 'echo "solardev:solardev" |chpasswd'
fi

grep -q plv8.start_proc /etc/postgresql/$PGVER/main/postgresql.conf
if [ $? -ne 0 -a -e /etc/postgresql/$PGVER/main/postgresql.conf ]; then
	echo -e '\nConfiguring plv8 global procedure...'
	sudo sh -c "echo \"plv8.start_proc = 'plv8_startup'\" >> /etc/postgresql/$PGVER/main/postgresql.conf"
	sudo service postgresql restart
fi

sudo grep -q solarnet /etc/postgresql/$PGVER/main/pg_ident.conf
if [ $? -ne 0 ]; then
	echo -e '\nConfiguring Postgres solardev user mapping...'
	sudo sh -c "echo \"solarnet solardev solarnet\" >> /etc/postgresql/$PGVER/main/pg_ident.conf"
	sudo sh -c "echo \"solartest solardev solarnet_test\" >> /etc/postgresql/$PGVER/main/pg_ident.conf"
	sudo service postgresql restart
fi

sudo grep -q map=solarnet /etc/postgresql/$PGVER/main/pg_hba.conf
if [ $? -ne 0 -a -e /vagrant/pg_hba.sed ]; then
	echo -e '\nConfiguring Postgres SolarNetwork peer mapping...'
	sudo sh -c "sed -f /vagrant/pg_hba.sed /etc/postgresql/$PGVER/main/pg_hba.conf > /etc/postgresql/$PGVER/main/pg_hba.conf.new"
	sudo chown postgres:postgres /etc/postgresql/$PGVER/main/pg_hba.conf.new
	sudo chmod 640 /etc/postgresql/$PGVER/main/pg_hba.conf.new
	sudo mv /etc/postgresql/$PGVER/main/pg_hba.conf /etc/postgresql/$PGVER/main/pg_hba.conf.bak
	sudo mv /etc/postgresql/$PGVER/main/pg_hba.conf.new /etc/postgresql/$PGVER/main/pg_hba.conf
	sudo service postgresql restart
fi

sudo -u postgres sh -c "psql -d solarnetwork -c 'SELECT now()'" >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo -e '\nCreating SolarNetwork Postgres database...'
	sudo -u postgres createuser -AD solarnet
	sudo -u postgres psql -U postgres -d postgres -c "alter user solarnet with password 'solarnet';"
	sudo -u postgres createdb -E UNICODE -l C -T template0 -O solarnet solarnetwork
	sudo -u postgres createlang plv8 solarnetwork
	sudo -u postgres psql -U postgres -d solarnetwork -c "CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;"
fi

sudo -u postgres sh -c "psql -d solarnet_unittest -c 'SELECT now()'" >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo -e '\nCreating SolarNetwork unit test Postgres database...'
	sudo -u postgres createuser -AD solarnet_test
	sudo -u postgres psql -U postgres -d postgres -c "alter user solarnet_test with password 'solarnet_test';"
	sudo -u postgres createdb -E UNICODE -l C -T template0 -O solarnet_test solarnet_unittest
	sudo -u postgres createlang plv8 solarnet_unittest
	sudo -u postgres psql -U postgres -d solarnet_unittest -c "CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;"
fi

if [ ! -e /etc/sudoers.d/solardev -a -e /vagrant/solardev.sudoers ]; then
	echo -e '\nCreating sudoers file for solardev user...'
	sudo cp /vagrant/solardev.sudoers /etc/sudoers.d/solardev
	sudo chmod 644 /etc/sudoers.d/solardev
fi

if [ -x /vagrant/solardev.sh ]; then
	sudo -i -u solardev /vagrant/solardev.sh
fi
