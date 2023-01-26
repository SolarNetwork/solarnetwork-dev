#!/bin/bash -e

JAVAVER="8 11 17"
PGVER="12"
HOST="solarnetworkdev.net"
GIT_BRANCH="develop"
GIT_REPOS="build external common central node"
DESKTOP_PACKAGES=""

GIT_HOME="/home/solardev/git"
WORKSPACE="/home/solardev/workspace"
DEB_RELEASE="${DEB_RELEASE:-bullseye}"
PG_PRELOAD_LIB="${PG_PRELOAD_LIB:-auto_explain,pg_stat_statements,timescaledb}"

while getopts ":b:h:j:J:p:r:U:" opt; do
	case $opt in
		b) GIT_BRANCH="${OPTARG}";;
		h) HOST="${OPTARG}";;
		j) JAVAVER="${OPTARG}";;
		p) PGVER="${OPTARG}";;
		r) GIT_REPOS="${OPTARG}";;
		U) DESKTOP_PACKAGES="${OPTARG}";;
		*)
			echo "Unknown argument ${OPTARG}"
			exit 1
	esac
done
shift $(($OPTIND - 1))

# Expand root
sudo resize2fs /dev/sda1

# Apply local settings
if [ -d /vagrant/local-root ]; then
	echo "Copying local VM settings from local-root directory..."
	sudo cp -Rv /vagrant/local-root/* /
fi

# Setup hostname
if ! grep -q $HOST /etc/hostname 2>/dev/null; then
	echo "Setting up $HOST hostname"
	echo $HOST >>/tmp/hostname.new
	chmod 644 /tmp/hostname.new
	sudo chown root:root /tmp/hostname.new
	sudo cp -a /etc/hostname /etc/hostname.bak
	sudo mv -f /tmp/hostname.new /etc/hostname

	sudo hostname $HOST
fi

# Setup DNS to resolve hostname
if ! grep -q $HOST /etc/hosts 2>/dev/null; then
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

if ! grep -q '/swapfile' /etc/fstab 2>/dev/null; then
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

if [ -x /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh ]; then
	sudo /usr/share/postgresql-common/pgdg/apt.postgresql.org.sh -y
fi

doAptUpdate=""

# Configure Timescale repo
if [ ! -e /etc/apt/sources.list.d/timescaledb.list ]; then
	echo "Adding TimescaleDB apt repo..."
	sudo sh -c "echo 'deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -cs) main' > /etc/apt/sources.list.d/timescaledb.list"
	wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | sudo apt-key add -
	doAptUpdate=1
fi

# Configure SNF repo
if [ ! -e /etc/apt/sources.list.d/solarnetwork.list ]; then
	echo "Adding SolarNetwork Foundation apt repo..."
	sudo sh -c "echo 'deb https://debian.repo.solarnetwork.org.nz ${DEB_RELEASE} main' > /etc/apt/sources.list.d/solarnetwork.list"
	wget --quiet -O - https://debian.repo.solarnetwork.org.nz/KEY.gpg | sudo apt-key add -
	doAptUpdate=1
fi

# Configure pgAdmin repo
if [ ! -e /etc/apt/sources.list.d/pgadmin4.list ]; then
	echo "Adding pgAdmin 4 apt repo..."
	sudo sh -c "echo 'deb https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main' > /etc/apt/sources.list.d/pgadmin4.list"
	wget --quiet -O - https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo apt-key add -
	doAptUpdate=1
fi

# Configure Postgres repo
if [ ! -e /etc/apt/sources.list.d/pgdg.list ]; then
	echo "Adding Postgres apt repo..."
	sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
	wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
	doAptUpdate=1
fi

if [ -n $doAptUpdate ]; then
	sudo apt update
fi

# Install desktop stuff
if [ -n "$DESKTOP_PACKAGES" ]; then
	echo -e "\nInstalling Desktop Packages: $DESKTOP_PACKAGES"
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy $DESKTOP_PACKAGES
fi

for v in $JAVAVER; do
	echo -e "\nInstalling Java $v..."
	javaPkg=openjdk-$v-jdk
	if [ -z "$DESKTOP_PACKAGES" ]; then
		javaPkg="${javaPkg}-headless"
	fi
	sudo DEBIAN_FRONTEND=noninteractive apt install -qy $javaPkg
done
  
echo -e "\nInstalling supporting utilities..."
sudo DEBIAN_FRONTEND=noninteractive apt install -qy gnupg apt-transport-https lsb-release wget \
  git git-flow
  
echo -e "\nInstalling Postgres $PGVER..."
sudo DEBIAN_FRONTEND=noninteractive apt install -qy postgresql-$PGVER postgresql-contrib-$PGVER \
  postgresql-common

echo -e '\nInstalling Postgres extensions...'
sudo apt install -qy timescaledb-2-postgresql-$PGVER postgresql-$PGVER-aggs-for-vecs

echo -e '\nCleaning up unused packages...'
sudo apt autoremove -qy

if ! grep -q 'jit = on' /etc/postgresql/$PGVER/main/postgresql.conf 2>/dev/null; then
	echo -e '\nDisabling JIT in Postgres...'
	sudo sed -i -e 's/^#*jit = .*/jit = off/' /etc/postgresql/$PGVER/main/postgresql.conf
	sudo service postgresql restart
fi

if [ -n "$DESKTOP_PACKAGES" ]; then
	echo -e '\nInstalling web browsers...'
	# Note libwebkitgtk is required for Eclipse to support an internal browser
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy firefox libwebkit2gtk-4.0-37
fi

# Add the solardev user if it doesn't already exist, password solardev

if ! getent passwd solardev >/dev/null; then
	echo -e '\nAdding solardev user.'
	sudo useradd -c 'SolarNet Developer' -s /bin/bash -m -U solardev
	sudo sh -c 'echo "solardev:solardev" |chpasswd'
fi

if grep -q "shared_preload_libraries.*$PG_PRELOAD_LIB" /etc/postgresql/$PGVER/main/postgresql.conf >/dev/null; then
	echo "shared_preload_libraries already configured in postgresql.conf."
else
	echo "Configuring shared_preload_libraries in postgresql.conf"
	sudo sed -Ei -e 's/#?shared_preload_libraries = '"'.*'"'/shared_preload_libraries = '"'$PG_PRELOAD_LIB'/" \
		/etc/postgresql/$PGVER/main/postgresql.conf
	sudo service postgresql restart
fi

if ! sudo grep -q solarnet /etc/postgresql/$PGVER/main/pg_ident.conf 2>/dev/null; then
	echo -e '\nConfiguring Postgres solardev user mapping...'
	sudo sh -c "echo \"solarnet solardev solarnet\" >> /etc/postgresql/$PGVER/main/pg_ident.conf"
	sudo sh -c "echo \"solartest solardev solartest\" >> /etc/postgresql/$PGVER/main/pg_ident.conf"
	sudo service postgresql restart
fi

if [ -e /vagrant/pg_hba.sed ]; then
	if ! sudo grep -q map=solarnet /etc/postgresql/$PGVER/main/pg_hba.conf 2>/dev/null; then
		echo -e '\nConfiguring Postgres SolarNetwork peer mapping...'
		sudo sh -c "sed -f /vagrant/pg_hba.sed /etc/postgresql/$PGVER/main/pg_hba.conf > /etc/postgresql/$PGVER/main/pg_hba.conf.new"
		sudo chown postgres:postgres /etc/postgresql/$PGVER/main/pg_hba.conf.new
		sudo chmod 640 /etc/postgresql/$PGVER/main/pg_hba.conf.new
		sudo mv /etc/postgresql/$PGVER/main/pg_hba.conf /etc/postgresql/$PGVER/main/pg_hba.conf.bak
		sudo mv /etc/postgresql/$PGVER/main/pg_hba.conf.new /etc/postgresql/$PGVER/main/pg_hba.conf
		sudo service postgresql restart
	fi
fi

if ! sudo -u postgres sh -c "psql -d solarnetwork -c 'SELECT now()'" >/dev/null 2>&1; then
	echo -e '\nCreating SolarNetwork Postgres database...'
	sudo -u postgres createuser -AD solarnet
	sudo -u postgres psql -U postgres -d postgres -c "alter user solarnet with password 'solarnet';"
	sudo -u postgres createdb -E UNICODE -l C -T template0 -O solarnet solarnetwork
	sudo -u postgres psql -U postgres -d solarnetwork -c 'CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public'
	sudo -u postgres psql -U postgres -d solarnetwork -c 'CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public'
	sudo -u postgres psql -U postgres -d solarnetwork -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public'
	sudo -u postgres psql -U postgres -d solarnetwork -c 'CREATE EXTENSION IF NOT EXISTS timescaledb WITH SCHEMA public'
	sudo -u postgres psql -U postgres -d solarnetwork -c 'CREATE EXTENSION IF NOT EXISTS aggs_for_vecs WITH SCHEMA public'
fi

if ! sudo -u postgres sh -c "psql -d solarnetwork_unittest -c 'SELECT now()'" >/dev/null 2>&1; then
	echo -e '\nCreating SolarNetwork unit test Postgres database...'
	sudo -u postgres createuser -AD solartest
	sudo -u postgres psql -U postgres -d postgres -c "alter user solartest with password 'solartest';"
	sudo -u postgres createdb -E UNICODE -l C -T template0 -O solartest solarnetwork_unittest
	sudo -u postgres psql -U postgres -d solarnetwork_unittest -c 'CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public'
	sudo -u postgres psql -U postgres -d solarnetwork_unittest -c 'CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public'
	sudo -u postgres psql -U postgres -d solarnetwork_unittest -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public'
	sudo -u postgres psql -U postgres -d solarnetwork_unittest -c 'CREATE EXTENSION IF NOT EXISTS timescaledb WITH SCHEMA public'
	sudo -u postgres psql -U postgres -d solarnetwork_unittest -c 'CREATE EXTENSION IF NOT EXISTS aggs_for_vecs WITH SCHEMA public'
fi

if [ ! -e /etc/sudoers.d/solardev -a -e /vagrant/solardev.sudoers ]; then
	echo -e '\nCreating sudoers file for solardev user...'
	sudo cp /vagrant/solardev.sudoers /etc/sudoers.d/solardev
	sudo chmod 644 /etc/sudoers.d/solardev
fi

# Check out the source code
if [ -x /vagrant/bin/solardev-git.sh ]; then
	sudo -i -u solardev /vagrant/bin/solardev-git.sh -g "$GIT_HOME" -b "$GIT_BRANCH" -r "$GIT_REPOS"
fi

# Configure the linux installation
if [ -x /vagrant/solardev.sh ]; then
	sudo -i -u solardev /vagrant/solardev.sh -w "$WORKSPACE" -g "$GIT_HOME"
fi

# Set up the eclipse workspace
if [ -x /vagrant/bin/solardev-workspace.sh -a -x /usr/bin/X ]; then
	sudo -i -u solardev /vagrant/bin/solardev-workspace.sh -w "$WORKSPACE" -g "$GIT_HOME"
fi

# copy conf files; skipping any that already exist
if [ -d /vagrant/conf/solarnetwork-central/solarnet -a -d "$GIT_HOME/solarnetwork-central/solarnet" ]; then
	echo -e '\nCreating initial SolarNet configuration...'
	sudo -i -u solardev cp -anv /vagrant/conf/solarnetwork-central/solarnet "$GIT_HOME/solarnetwork-central/"
fi

# Success messages
if [ -x /usr/bin/fluxbox ]; then
	cat <<"EOF"

--------------------------------------------------------------------------------
SolarNetwork development environment setup complete. Please reboot the virtual
machine like:

vagrant reload

Then log into the VM as solardev:solardev and Eclipse will launch automatically.
Right-click on the desktop to access a menu of other options.

!! NOTE: If X fails to start on tty1, login on tty2 (Alt-F2) and run `startx`
!! to start X and have Eclipse launch automatically.
EOF
else
  cat <<EOF

--------------------------------------------------------------------------------
SolarNetwork development environment setup complete.

Log into the VM as solardev:solardev.
EOF
fi
