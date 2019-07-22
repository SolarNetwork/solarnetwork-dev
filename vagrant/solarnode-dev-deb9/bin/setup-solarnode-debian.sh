#!/bin/sh

if [ $(id -u) -ne 0 ]; then
	echo "This script must be run as root."
	exit 1
fi

APP_USER="solar"
APP_USER_PASS="solar"
DRY_RUN=""
HOSTNAME="solarnode"
PKG_ADD="/vagrant/conf/packages-add.txt"
SNF_PKG_REPO="https://debian.repo.solarnetwork.org.nz"
PKG_DIST="stretch"
UPDATE_PKG_CACHE=""

LOG="/var/tmp/setup-sn.log"
ERR_LOG="/var/tmp/setup-sn.err"

do_help () {
	cat 1>&2 <<EOF
Usage: $0 <arguments>

Setup script for a minimal SolarNode OS based on Debian 9 (Stretch).

Arguments:
 -h <hostname>          - the hostname to use; defaults to solarnode
 -n                     - dry run; do not make any actual changes
 -P                     - update package cache
 -p <apt repo url>      - the SNF package repository to use; defaults to
                          https://debian.repo.solarnetwork.org.nz;
                          or the repository can be accessed directly for development as
                          http://snf-debian-repo.s3-website-us-west-2.amazonaws.com;
                          the staging repo can be used instead, which is
                          https://debian.repo.stage.solarnetwork.org.nz;
                          or the staging repo can be accessed directly for development as
                          http://snf-debian-repo-stage.s3-website-us-west-2.amazonaws.com
 -r <pkg dist>          - the package distribution to use; defaults to 'stretch'
 -s <pkg add file>      - path to a file with names of packages to add, one per line;
                          defaults to /vagrant/conf/packages-add.txt
 -U <user pass>         - the app user password; defaults to solar
 -u <username>          - the app username to use; defaults to solar
EOF
}

while getopts ":h:nPp:U:u:" opt; do
	case $opt in
		h) HOSTNAME="${OPTARG}";;
		n) DRY_RUN='TRUE';;
		P) UPDATE_PKG_CACHE='TRUE';;
		p) SNF_PKG_REPO="${OPTARG}";;
		r) PKG_DIST="${OPTARG}";;
		s) PKG_ADD="${OPTARG}";;
		U) APP_USER_PASS="${OPTARG}";;
		u) APP_USER="${OPTARG}";;
		*)
			echo "Unknown argument ${OPTARG}"
			do_help
			exit 1
	esac
done
shift $(($OPTIND - 1))

# clear error log
cat /dev/null >$ERR_LOG
cat /dev/null >$LOG

check_err () {
	if [ -s "$ERR_LOG" ]; then
		echo ""
		echo "Errors or warnings have been generated in $ERR_LOG."
	fi
}

# install package if not already installed
pkg_install () {	
	if dpkg -s $1 >/dev/null 2>/dev/null; then
		echo "Package $1 already installed."
	else
		echo "Installing package $1..."
		if [ -z "$DRY_RUN" ]; then
			if ! apt-get -qy install --no-install-recommends $1; then
				echo "Error installing package $1"
				exit 1
			fi
		fi
	fi
}

# remove package if installed
pkg_remove () {	
	if dpkg -s $1 >/dev/null 2>/dev/null; then
		echo "Removing package $1..."
		if [ -z "$DRY_RUN" ]; then
			apt-get -qy remove --purge $1
		fi
	else
		echo "Package $1 already removed."
	fi
}

# remove package if installed
pkg_autoremove () {	
		if [ -z "$DRY_RUN" ]; then
			apt-get -qy autoremove --purge $1
		fi
}

service_up () {
	name="$1"
	start="$2"
	if ! systemctl is-enabled "$name" >/dev/null; then
		echo -n "Enabling $name... "
		if [ -n "$DRY_RUN" ]; then
			echo "DRY RUN"
		else
			systemctl enable "$name" && echo "OK"
		fi
	fi
	if [ -n "$start" ]; then
		if ! systemctl is-active "$name" >/dev/null; then
			echo -n "Starting $name... "
			if [ -n "$DRY_RUN" ];then
				echo "DRY RUN"
			else
				systemctl start "$name" && echo "OK"
			fi
		else
			echo -n "Restarting $name... "
			if [ -n "$DRY_RUN" ];then
				echo "DRY RUN"
			else
				systemctl restart "$name" && echo "OK"
			fi
		fi
	fi
}

setup_hostname () {
	if hostnamectl status --static |grep -q "$HOSTNAME"; then
		echo "Hostname already set to $HOSTNAME."
	else
		echo -n "Setting hostname to $HOSTNAME... "
		if [ -n "$DRY_RUN" ]; then
			echo "DRY RUN"
		else
			sudo hostnamectl set-hostname "$HOSTNAME" && echo "OK"
		fi
	fi
}

setup_dns () {
	if grep -q "$HOSTNAME" /etc/hosts; then
		echo "/etc/hosts contains $HOSTNAME already."
	else
		echo -n "Setting up $HOSTNAME /etc/hosts entry... "
		if [ -n "$DRY_RUN" ]; then
			echo "DRY RUN"
		else
			sed "s/^127.0.0.1[[:space:]]*localhost/127.0.0.1 $HOSTNAME localhost/" /etc/hosts >/tmp/hosts.new
			if diff -q /etc/hosts /tmp/hosts.new >/dev/null; then
				# didn't change anything, try 127.0.1.0
				sed "s/^127.0.1.1.*/127.0.1.1 $HOSTNAME/" /etc/hosts >/tmp/hosts.new
			fi
			if diff -q /etc/hosts /tmp/hosts.new >/dev/null; then
				# no change
				rm -f /tmp/hosts.new
			else
				chmod 644 /tmp/hosts.new
				sudo mv -f /tmp/hosts.new /etc/hosts
			fi
			echo "OK"
		fi
	fi
}

setup_user () {
	if grep -q "^$APP_USER" /etc/passwd; then
		echo "User $APP_USER already exists."
	else
		echo -n "Creating user $APP_USER... "
		if [ -n "$DRY_RUN" ]; then
			echo "DRY RUN"
		else
			useradd -m -U -G dialout,sudo -s /bin/bash "$APP_USER" 2>>$ERR_LOG && echo "OK" || echo "ERROR"
			echo "$APP_USER:$APP_USER_PASS" |chpasswd 2>>$ERR_LOG
		fi
	fi
}

setup_apt () {
	pkg_install apt-transport-https
	if apt-key list 2>/dev/null |grep -q "packaging@solarnetwork.org.nz" >/dev/null; then
		echo 'SNF package repository GPG key already imported.'
	else
		echo -n 'Importing SNF package repository GPG key... '
		if [ -n "$DRY_RUN" ]; then
			echo "DRY RUN"
		else
			curl -s "$SNF_PKG_REPO/KEY.gpg" |apt-key add -
		fi
	fi
	
	local updated=""
	if [ -e /etc/apt/sources.list.d/solarnetwork.list ]; then
		echo 'SNF package repository already configured.'
	else
		echo -n "Configuring SNF package repository $SNF_PKG_REPO... "
		updated=1
		if [ -n "$DRY_RUN" ]; then
			echo "DRY RUN"
		else
			echo "deb $SNF_PKG_REPO $PKG_DIST main" >/etc/apt/sources.list.d/solarnetwork.list
			echo "OK"
		fi
	fi
	if [ -n "$updated" -o -n "$UPDATE_PKG_CACHE" ]; then
		echo -n "Updating package cache... "
		if [ -n "$DRY_RUN" ]; then
			echo "DRY RUN"
		else
			apt-get -q update >>$LOG 2>>$ERR_LOG
			echo "OK"
		fi
	fi
}

setup_software () {
	# add all packages in manifest
	if [ -n "$PKG_ADD" -a -e "$PKG_ADD" ]; then
		dpkg-query --showformat='${Package}\n' --show >/tmp/pkgs.txt
		while IFS= read -r line; do
			if ! grep -q "^$line$" /tmp/pkgs.txt; then
				pkg_install "$line"
			fi
		done < "$PKG_ADD"
	fi
	
	apt-get clean
}

end_msg () {
	cat <<-EOF
	
	*********************************************************************************************
	INSTALLATION REPORT
	*********************************************************************************************
	
	SolarNode setup complete. Please reboot the virtual machine via 'vagrant reload' to continue.
	Then try accessing the SolarNode web GUI via http://solarnode/ or by using one of these IP 
	addresses:
	
	  $(hostname -I)
	
	EOF
}

setup_hostname
setup_dns
setup_user
setup_apt
setup_software
check_err
end_msg
