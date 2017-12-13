#!/bin/bash

WORKSPACE=$1
GIT_HOME=$2

# Make sure that a workspace has been specified
if [ -z "$WORKSPACE" ]; then
  echo "Usage: ./solardev.sh <workspace> (<git location>)"
  exit 1
fi
if [ -z "$GIT_HOME" ]; then
  echo "No Git directory specified, defaulting to using workspace: $WORKSPACE"
  GIT_HOME=$WORKSPACE
fi

# Setup .xinitrc to launch Fluxbox
if [ ! -e ~/.xinitrc -a -x /usr/bin/fluxbox ]; then
	echo -e '\nConfiguring Fluxbox in .xinitrc...'
	echo "exec startfluxbox" > ~/.xinitrc
fi

# Setup X to start on console login
if [ -x /usr/bin/xinit ]; then
	grep -q xinit ~/.bashrc
	if [ $? -ne 0 ]; then
		echo -e '\nConfiguring X to start on login...'
		cat >> ~/.bashrc <<"EOF"

if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
	exec /usr/bin/xinit -- -nolisten tcp
fi
EOF
	fi
fi

# Setup main SolarNet database
psql -d solarnetwork -U solarnet -c 'select count(*) from solarnet.sn_node' >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo -e '\nCreating solarnet database tables...'
	cd $GIT_HOME/solarnetwork-central/solarnet-db-setup/postgres
	# for some reason, plv8 often chokes on the inline comments, so strip them out
	sed -e '/^\/\*/d' -e '/^ \*/d' postgres-init-plv8.sql |sudo -u postgres psql -d solarnetwork -U postgres
	psql -d solarnetwork -U solarnet -f postgres-init.sql
fi

# Setup unit test database
psql -d solarnet_unittest -U solarnet_test -c 'select count(*) from solarnet.sn_node' >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo -e '\nCreating solarnet_unittest database tables...'
	cd $GIT_HOME/solarnetwork-central/solarnet-db-setup/postgres
	# for some reason, plv8 often chokes on the inline comments, so strip them out
	sed -e '/^\/\*/d' -e '/^ \*/d' postgres-init-plv8.sql |sudo -u postgres psql -d solarnet_unittest -U postgres
	psql -d solarnet_unittest -U solarnet_test -f postgres-init.sql
fi

if [ -x /usr/bin/X ]; then
	eclipseDownload=/var/tmp/eclipse.tgz
	eclipseName=Oxygen
	eclipseDownloadURL='http://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/oxygen/1a/eclipse-jee-oxygen-1a-linux-gtk-x86_64.tar.gz&r=1'
	eclipseDownloadSHA512=06e66ea61fcc156f71064c3461038ba92781484747c9c56844d8e6a88e575308fd56b3bdda216ac30de0476c3f4dbf90e0422cbcd3591711387e6743b4c52f18
	eclipseDownloadHash=

	eclipseHashFile () {
		echo -e '\nVerifying Eclipse download...'
		eclipseDownloadHash=`sha512sum $eclipseDownload |cut -d' ' -f1`
	}

	if [ -e "$eclipseDownload" ]; then
		eclipseHashFile
	fi

	if [ "$eclipseDownloadHash" != "$eclipseDownloadSHA512" ]; then
		echo -e "\nDownloading Eclipse JEE ($eclipseName)..."
		curl -C - -L -s -S -o $eclipseDownload $eclipseDownloadURL
		if [ -e "$eclipseDownload" ]; then
			eclipseHashFile
		fi
	fi
	if [ ! -d ~/eclipse -a -e "$eclipseDownload" ]; then
		if [ "$eclipseDownloadHash" = "$eclipseDownloadSHA512" ]; then
			echo -e "\nInstalling Eclipse JEE ($eclipseName)..."
			tar -C ~/ -xzf "$eclipseDownload"
			if [ $? -eq 0 ]; then
				rm $eclipseDownload
			fi
		else
			>&2 echo "Eclipse $eclipseName not completely downloaded, cannot install."
		fi
	fi

fi

if [ -x /usr/bin/fluxbox -a ! -d ~/.fluxbox ]; then
	mkdir ~/.fluxbox
fi

# Setup Fluxbox menu
if [ -x /usr/bin/fluxbox -a ! -e ~/.fluxbox/menu ]; then
	echo -e '\nConfiguring Fluxbox menu...'
	cat > ~/.fluxbox/menu <<EOF
[begin] (SolarNetwork Dev)
        [exec] (Eclipse) { ~/eclipse/eclipse -data $WORKSPACE } <~/eclipse/icon.xpm>
        [exec] (Firefox) { firefox } </usr/share/pixmaps/firefox.png>
        [exec] (pgAdminIII) { pgadmin3 } </usr/share/pixmaps/pgadmin3.xpm>
        [submenu] (Shells) {}
                [exec] (Bash) { x-terminal-emulator -T "Bash" -e /bin/bash --login} <>
                [exec] (Dash) { x-terminal-emulator -T "Dash" -e /bin/dash -i} <>
                [exec] (Sh) { x-terminal-emulator -T "Sh" -e /bin/sh --login} <>
        [end]
        [workspaces] (Workspaces)
        [reconfig] (Reconfigure)
        [restart] (Restart)
        [exit] (Exit)
[end]
EOF
fi

# Set Eclipse to launch on Fluxbox startup
if [ -x ~/eclipse/eclipse -a -x /usr/bin/fluxbox -a ! -e ~/.fluxbox/startup ]; then
	echo -e '\nConfiguring Eclipse to start on login...'
	cat > ~/.fluxbox/startup <<EOF
#!/bin/sh

if [ -e ~/.Xmodmap ]; then
	xmodmap ~/.Xmodmap
fi

if [ -x ~/eclipse/eclipse ]; then
	~/eclipse/eclipse -data $WORKSPACE &
fi

# Debian-local change:
#   - fbautostart has been added with a quick hack to check to see if it
#     exists. If it does, we'll start it up by default.
which fbautostart > /dev/null
if [ $? -eq 0 ]; then
	fbautostart
fi

exec fluxbox
EOF
fi
