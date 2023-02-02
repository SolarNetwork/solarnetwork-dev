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

if ! dpkg -s language-pack-en >/dev/null 2>/dev/null; then
	echo -e '\nInstalling language-pack...'
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy language-pack-en
fi

if ! dpkg -s git-flow >/dev/null 2>/dev/null; then
	echo -e '\nInstalling git...'
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy git git-lfs git-flow
	if ! grep -q lfs ~/.gitconfig >/dev/null 2>/dev/null; then
		echo -e '\nInitializing git LFS...'
		git lfs install --skip-repo
	fi
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
	sudo apt-get update
fi

# Install desktop stuff
if [ -n "$DESKTOP_PACKAGES" ]; then
	echo -e "\nInstalling Desktop Packages: $DESKTOP_PACKAGES"
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy $DESKTOP_PACKAGES

	if ! dpkg -s pgadmin4-desktop >/dev/null 2>/dev/null; then
		echo -e "\nInstalling pgAdmin..."
		sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy pgadmin4-desktop
	fi
fi

for v in $JAVAVER; do
	javaPkg=openjdk-$v-jdk
	if [ -z "$DESKTOP_PACKAGES" ]; then
		javaPkg="${javaPkg}-headless"
	fi
	if ! dpkg -s $javaPkg >/dev/null 2>/dev/null; then
		echo -e "\nInstalling Java $v..."
		sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy $javaPkg
	fi
done
  
if ! dpkg -s git-flow >/dev/null 2>/dev/null; then
	echo -e "\nInstalling supporting utilities..."
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy gnupg apt-transport-https lsb-release wget
fi
  
if ! dpkg -s postgresql-$PGVER >/dev/null 2>/dev/null; then
	echo -e "\nInstalling Postgres $PGVER..."
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -qy postgresql-$PGVER postgresql-contrib-$PGVER \
	  postgresql-common
fi

if ! dpkg -s timescaledb-2-postgresql-$PGVER >/dev/null 2>/dev/null; then
	echo -e '\nInstalling Postgres extensions...'
	sudo apt-get install -qy timescaledb-2-postgresql-$PGVER postgresql-$PGVER-aggs-for-vecs
fi

if ! dpkg -s ruby >/dev/null 2>/dev/null; then
	echo -e '\nInstalling Ruby and cbor-diag gem...'
	sudo apt-get install -qy ruby
	sudo gem install cbor-diag
fi

echo -e '\nCleaning up unused packages...'
sudo apt-get autoremove -qy --purge

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

restartPostgres=""

if ! grep -q 'jit = on' /etc/postgresql/$PGVER/main/postgresql.conf >/dev/null 2>/dev/null; then
	echo -e '\nDisabling JIT in Postgres...'
	sudo sed -i -e 's/^#*jit = .*/jit = off/' /etc/postgresql/$PGVER/main/postgresql.conf
	restartPostgres=1
fi

if grep -q "listen_addresses = '\*'" /etc/postgresql/$PGVER/main/postgresql.conf >/dev/null; then
	echo "listen_address already configured in postgresql.conf."
else
	echo "Configuring listen_address in postgresql.conf"
	sudo sed -Ei -e 's/#?listen_addresses = '"'.*'"'/listen_addresses = '"'*'"'/' \
		/etc/postgresql/$PGVER/main/postgresql.conf
	restartPostgres=1
fi

if grep -q "shared_preload_libraries.*$PG_PRELOAD_LIB" /etc/postgresql/$PGVER/main/postgresql.conf >/dev/null; then
	echo "shared_preload_libraries already configured in postgresql.conf."
else
	echo "Configuring shared_preload_libraries in postgresql.conf"
	sudo sed -Ei -e 's/#?shared_preload_libraries = '"'.*'"'/shared_preload_libraries = '"'$PG_PRELOAD_LIB'/" \
		/etc/postgresql/$PGVER/main/postgresql.conf
	restartPostgres=1
fi

if ! sudo grep -q solarnet /etc/postgresql/$PGVER/main/pg_ident.conf 2>/dev/null; then
	echo -e '\nConfiguring Postgres solardev user mapping...'
	sudo sh -c "echo \"solarnet solardev solarnet\" >> /etc/postgresql/$PGVER/main/pg_ident.conf"
	sudo sh -c "echo \"solartest solardev solartest\" >> /etc/postgresql/$PGVER/main/pg_ident.conf"
	restartPostgres=1
fi

if [ -e /vagrant/pg_hba.sed ]; then
	if ! sudo grep -q map=solarnet /etc/postgresql/$PGVER/main/pg_hba.conf 2>/dev/null; then
		echo -e '\nConfiguring Postgres SolarNetwork peer mapping...'
		sudo sh -c "sed -f /vagrant/pg_hba.sed /etc/postgresql/$PGVER/main/pg_hba.conf > /etc/postgresql/$PGVER/main/pg_hba.conf.new"
		sudo chown postgres:postgres /etc/postgresql/$PGVER/main/pg_hba.conf.new
		sudo chmod 640 /etc/postgresql/$PGVER/main/pg_hba.conf.new
		sudo mv /etc/postgresql/$PGVER/main/pg_hba.conf /etc/postgresql/$PGVER/main/pg_hba.conf.bak
		sudo mv /etc/postgresql/$PGVER/main/pg_hba.conf.new /etc/postgresql/$PGVER/main/pg_hba.conf
		restartPostgres=1
	fi
fi

if [ -n "restartPostgres" ]; then
	sudo service postgresql restart
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

# Install VerneMQ
if dpkg -s vernemq >/dev/null 2>/dev/null; then
	echo -e "\nVerneMQ package already installed."
else
	vernemqVersion="1.12.6.2"
	vernemqFilename="vernemq-${vernemqVersion}.jammy.x86_64.deb"
	vernemqDownload="/var/tmp/${vernemqFilename}"
	vernemqDownloadUrl="https://github.com/vernemq/vernemq/releases/download/${vernemqVersion}/${vernemqFilename}"
	vernemqDownloadSha256="6ea7d50177d27fb9f69d8fc3e9c0e08d4a95308f1ead932721d187bea979bad5"
	vernemqDownloadHash=""

	vernemqHashFile () {
		echo -e '\nVerifying VerneMQ download...'
		vernemqDownloadHash=`sha256sum $vernemqDownload |cut -d' ' -f1`
	}

	if [ -e "$vernemqDownload" ]; then
		vernemqHashFile
	fi

	if [ "$vernemqDownloadHash" != "$vernemqDownloadSha256" ]; then
		echo -e "\nDownloading VernemMQ ($vernemqVersion)..."
		curl -C - -L -s -S -o "$vernemqDownload" "$vernemqDownloadUrl"
		if [ -e "$vernemqDownload" ]; then
			vernemqHashFile
		fi
	fi
	if [ -e "$vernemqDownload" ]; then
		if [ "$vernemqDownloadHash" = "$vernemqDownloadSha256" ]; then
			echo -e "\nInstalling VerneMQ ($vernemqVersion)..."
			sudo apt-get -qy install "$vernemqDownload"
			if [ $? -eq 0 ]; then
				rm "$vernemqDownload"
			fi
		else
			>&2 echo "Eclipse $vernemqVersion not completely downloaded, cannot install."
		fi
	fi
fi

# Make tweaks to VerneMQ default configuration
if ! grep -q node /etc/vernemq/vmq.acl 2>/dev/null; then
	echo -e '\nConfiguring Vernemq ACL...'
	sudo cp /vagrant/conf/solarqueue/vmq.acl /etc/vernemq/vmq.acl
fi
if ! grep -q solarnet /etc/vernemq/vmq.passwd 2>/dev/null; then
	echo -e '\nConfiguring Vernemq credentials...'
	sudo cp /vagrant/conf/solarqueue/vmq.passwd /etc/vernemq/vmq.passwd
	sudo vmq-passwd -U /etc/vernemq/vmq.passwd
fi
if [ ! -e /etc/vernemq/vernemq.conf.orig ]; then
	echo -e '\nCreating backup of VerneMQ configuration...'
	sudo cp -a /etc/vernemq/vernemq.conf /etc/vernemq/vernemq.conf.orig
fi
if grep -q 'accept_eula = no' /etc/vernemq/vernemq.conf; then
	sudo sed -i 's/accept_eula = no/accept_eula = yes/' /etc/vernemq/vernemq.conf
fi
if grep -q '^allow_anonymous = off' /etc/vernemq/vernemq.conf; then
	sudo sed -i 's/^allow_anonymous = off/allow_anonymous = on/' /etc/vernemq/vernemq.conf
fi
if grep -q '^listener.tcp.name' /etc/vernemq/vernemq.conf; then
	sudo sed -i 's/^listener.tcp.name/#listener.tcp.name/' /etc/vernemq/vernemq.conf
fi
if grep -q '^listener.ssl.name' /etc/vernemq/vernemq.conf; then
	sudo sed -i 's/^listener.ssl.name/#listener.ssl.name/' /etc/vernemq/vernemq.conf
fi
if [ ! -e /etc/vernemq/conf.d/solarnet.conf ]; then
	echo -e '\nCreating SolarNet VerneMQ configuration...'
	if [ ! -d /etc/vernemq/conf.d ]; then
		sudo mkdir -p /etc/vernemq/conf.d
	fi
	sudo cp /vagrant/conf/solarqueue/solarnet.conf /etc/vernemq/conf.d/
fi

# Enable VerneMQ service
sudo systemctl enable vernemq

# Install Mosquitto client
if dpkg -s mosquitto-clients >/dev/null 2>/dev/null; then
	echo -e '\nMosquitto MQTT client already installed.'
else
	echo -e '\nInstalling Mosquitto MQTT client...'
	sudo apt-get -qy install mosquitto-clients
fi

if [ ! -x /usr/local/bin/solarqueue-tail ]; then
	echo -e '\nInstalling solarqueue-tail tool...'
	sudo cp /vagrant/conf/solarqueue/solarqueue-tail /usr/local/bin/solarqueue-tail
	sudo chmod 755 /usr/local/bin/solarqueue-tail
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

# copy SolarNet conf files; skipping any that already exist
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
