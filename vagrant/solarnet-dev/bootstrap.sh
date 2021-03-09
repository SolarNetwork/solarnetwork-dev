#!/bin/bash

JAVAVER=$1
PGVER=$2
HOST=$3
GIT_BRANCH=$4
GIT_REPOS=$5
DESKTOP_PACKAGES=$6

GIT_HOME="/home/solardev/git"
WORKSPACE="/home/solardev/workspace"

# Expand root
sudo resize2fs /dev/sda1

# Apply local settings
if [ -d /vagrant/local-root ]; then
	echo "Copying local VM settings from local-root directory..."
	sudo cp -Rv /vagrant/local-root/* /
fi

# Setup hostname
grep -q $HOST /etc/hostname
if [ $? -ne 0 ]; then
	echo "Setting up $HOST hostname"
	echo $HOST >>/tmp/hostname.new
	chmod 644 /tmp/hostname.new
	sudo chown root:root /tmp/hostname.new
	sudo cp -a /etc/hostname /etc/hostname.bak
	sudo mv -f /tmp/hostname.new /etc/hostname

	sudo hostname $HOST
fi

# Setup DNS to resolve hostname
grep -q $HOST /etc/hosts
if [ $? -ne 0 ]; then
	echo "Setting up $HOST host entry"
	sed "s/^127.0.0.1[[:space:]]*localhost/127.0.0.1 $HOST localhost/" /etc/hosts >/tmp/hosts.new
	if [ -z "$(diff /etc/hosts /tmp/hosts.new)" ]; then
		# didn't change anything, try 127.0.1.0
		sed "s/^127.0.1.1.*/127.0.1.1 $HOST/" /etc/hosts >/tmp/hosts.new
	fi
	if [ "$(diff /etc/hosts /tmp/hosts.new)" ]; then
		chmod 644 /tmp/hosts.new
		sudo chown root:root /tmp/hosts.new
		sudo cp -a /etc/hosts /etc/hosts.bak
		sudo mv -f /tmp/hosts.new /etc/hosts
	fi
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
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -qy

echo -e '\nInstalling language-pack...'
sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy language-pack-en

echo -e '\nInstalling git...'
sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy git git-lfs
if ! grep -q lfs ~/.gitconfig >/dev/null 2>/dev/null; then
	echo -e '\nInitializing git LFS...'
	git lfs install --skip-repo
fi

if [ -n "$DESKTOP_PACKAGES" ]; then
	echo -e "\nInstalling Desktop Packages: $DESKTOP_PACKAGES"
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -qq --no-install-recommends $DESKTOP_PACKAGES
fi

echo -e "\nInstalling Postgres $PGVER and Java $JAVAVER..."
javaPkg=openjdk-$JAVAVER-jdk
if [ -z "$DESKTOP_PACKAGES" ]; then
	javaPkg="${javaPkg}-headless"
fi
sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy postgresql-$PGVER postgresql-contrib-$PGVER git git-flow $javaPkg librxtx-java

sudo grep -q 'jit = on' /etc/postgresql/$PGVER/main/postgresql.conf 2>/dev/null
if [ $? -eq 0 ]; then
	echo -e '\nDisabling JIT in Postgres...'
	sudo sed -i -e 's/^#*jit = .*/jit = off/' /etc/postgresql/$PGVER/main/postgresql.conf
	sudo service postgresql restart
fi

if [ -n "$DESKTOP_PACKAGES" ]; then
	echo -e '\nInstalling web browsers...'
	# Note libwebkitgtk is required for Eclipse to support an internal browser
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy firefox libwebkit2gtk-4.0-37
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
	sudo useradd -c 'SolarNet Developer' -s /bin/bash -m -U solardev
	sudo sh -c 'echo "solardev:solardev" |chpasswd'
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
	sudo -u postgres psql -U postgres -d solarnetwork -c 'CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public'
	sudo -u postgres psql -U postgres -d solarnetwork -c 'CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public'
	sudo -u postgres psql -U postgres -d solarnetwork -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public'
fi

sudo -u postgres sh -c "psql -d solarnet_unittest -c 'SELECT now()'" >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo -e '\nCreating SolarNetwork unit test Postgres database...'
	sudo -u postgres createuser -AD solarnet_test
	sudo -u postgres psql -U postgres -d postgres -c "alter user solarnet_test with password 'solarnet_test';"
	sudo -u postgres createdb -E UNICODE -l C -T template0 -O solarnet_test solarnet_unittest
	sudo -u postgres psql -U postgres -d solarnet_unittest -c 'CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public'
	sudo -u postgres psql -U postgres -d solarnet_unittest -c 'CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public'
	sudo -u postgres psql -U postgres -d solarnet_unittest -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public'
fi

if [ ! -e /etc/sudoers.d/solardev -a -e /vagrant/solardev.sudoers ]; then
	echo -e '\nCreating sudoers file for solardev user...'
	sudo cp /vagrant/solardev.sudoers /etc/sudoers.d/solardev
	sudo chmod 644 /etc/sudoers.d/solardev
fi

# Check out the source code
if [ -x /vagrant/bin/solardev-git.sh ]; then
	sudo -i -u solardev /vagrant/bin/solardev-git.sh $GIT_HOME $GIT_BRANCH "$GIT_REPOS"
fi

# Configure the linux installation
if [ -x /vagrant/solardev.sh ]; then
	sudo -i -u solardev /vagrant/solardev.sh $WORKSPACE $GIT_HOME
fi

# Set up the eclipse workspace
if [ -x /vagrant/bin/solardev-workspace.sh -a -x /usr/bin/X ]; then
	sudo -i -u solardev /vagrant/bin/solardev-workspace.sh $WORKSPACE $GIT_HOME
fi

# Success messages
if [ -x /usr/bin/fluxbox ]; then
	cat <<"EOF"

--------------------------------------------------------------------------------
SolarNetwork development environment setup complete. Please reboot the
virtual machine like:

vagrant reload

Then log into the VM as solardev:solardev and Eclipse will launch
automatically. Right-click on the desktop to access a menu of other options.

NOTE: If X fails to start via tty1, login on tty2 and run `startx` to
start X and have Eclipse launch automatically.
EOF
elif [[ "$DESKTOP_PACKAGES" == *"virtualbox-guest-dkms"*  ]]; then
  # if virtualbox-guest-dkms is included reconfigure so that the desktop will scale when resized
  echo -e "\nReconfiguring virtualbox-guest-dkms\n"
  sudo dpkg-reconfigure virtualbox-guest-dkms

  cat <<EOF

--------------------------------------------------------------------------------
SolarNetwork development environment setup complete, rebooting VM.

Once restarted log into the VM as solardev:solardev.

NOTE: If the desktop fails to auto scale first try rebooting the VM,
if that doesn't work manually run : "sudo dpkg-reconfigure virtualbox-guest-dkms"
then restart the VM.
EOF

  # Restart the VM to show the desktop
  sudo reboot

else
  cat <<EOF

--------------------------------------------------------------------------------
SolarNetwork development environment setup complete.

Log into the VM as solardev:solardev.
EOF
fi
