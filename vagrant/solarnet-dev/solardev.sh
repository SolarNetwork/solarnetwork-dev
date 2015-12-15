#!/bin/bash

# Setup .xinitrc to launch Fluxbox
if [ ! -e ~/.xinitrc ]; then
	echo 'Configuring Fluxbox in .xinitrc...'
	echo "exec startfluxbox" > ~/.xinitrc
fi

# Setup X to start on console login
grep -q xinit ~/.bashrc
if [ $? -ne 0 ]; then
	echo 'Configuring X to start on login...'
	cat >> ~/.bashrc <<"EOF"

if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
	exec /usr/bin/xinit -- -nolisten tcp
fi
EOF
fi

# Setup Eclipse
# Checkout SolarNetwork sources
for proj in build external common central node; do
	if [ ! -d ~/git/solarnetwork-$proj ]; then
		echo "Cloning project solarnetwork-$proj..."
		mkdir -p ~/git/solarnetwork-$proj
		git clone "https://github.com/SolarNetwork/solarnetwork-$proj.git" ~/git/solarnetwork-$proj
		cd ~/git/solarnetwork-$proj
		git checkout -b develop origin/develop
	fi
done

# Setup main SolarNet database
psql -d solarnetwork -U solarnet -c 'select count(*) from solarnet.sn_node' >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo 'Creating solarnet database tables...'
	cd ~/git/solarnetwork-central/net.solarnetwork.central.datum/defs/sql/postgres
	# for some reason, plv8 often chokes on the inline comments, so strip them out
	sed -e '/^\/\*/d' -e '/^ \*/d' postgres-init-plv8.sql |psql -d solarnetwork -U solarnet
	psql -d solarnetwork -U solarnet -f postgres-init.sql
fi

# Setup unit test database
psql -d solarnet_unittest -U solarnet_test -c 'select count(*) from solarnet.sn_node' >/dev/null 2>&1
if [ $? -ne 0 ]; then
	echo 'Creating solarnet_unittest database tables...'
	cd ~/git/solarnetwork-central/net.solarnetwork.central.datum/defs/sql/postgres
	# for some reason, plv8 often chokes on the inline comments, so strip them out
	sed -e '/^\/\*/d' -e '/^ \*/d' postgres-init-plv8.sql |psql -d solarnet_unittest -U solarnet_test
	psql -d solarnet_unittest -U solarnet_test -f postgres-init.sql
fi

cd ~

# Setup standard setup files
if [ ! -d ~/git/solarnetwork-build/solarnetwork-osgi-target/config ]; then
	echo 'Creating solarnetwork-build/solarnetwork-osgi-target/config files...'
	cp -a ~/git/solarnetwork-build/solarnetwork-osgi-target/example/config ~/git/solarnetwork-build/solarnetwork-osgi-target/

	# Enable the SolarIn SSL connector in tomcat-server.xml
	sed -e '9s/$/-->/' -e '16d' ~/git/solarnetwork-build/solarnetwork-osgi-target/example/config/tomcat-server.xml \
		> ~/git/solarnetwork-build/solarnetwork-osgi-target/config/tomcat-server.xml
fi

if [ ! -e ~/git/solarnetwork-build/solarnetwork-osgi-target/configurations/services/net.solarnetwork.central.dao.jdbc.cfg ]; then
	echo 'Creating JDBC configuration...'
	cat > ~/git/solarnetwork-build/solarnetwork-osgi-target/configurations/services/net.solarnetwork.central.dao.jdbc.cfg <<-EOF
		jdbc.driver = org.postgresql.Driver
		jdbc.url = jdbc:postgresql://localhost:5432/solarnetwork
		jdbc.user = solarnet
		jdbc.pass = solarnet
EOF
fi

if [ ! -e ~/git/solarnetwork-build/solarnetwork-osgi-target/configurations/services/net.solarnetwork.central.in.cfg ]; then
	echo 'Creating developer SolarIn configuration...'
	cat > ~/git/solarnetwork-build/solarnetwork-osgi-target/configurations/services/net.solarnetwork.central.in.cfg <<-EOF
		SimpleNetworkIdentityBiz.host = solarnetworkdev.net
		SimpleNetworkIdentityBiz.port = 8683
		SimpleNetworkIdentityBiz.forceTLS = true
EOF
fi

if [ ! -e ~/git/solarnetwork-build/solarnetwork-osgi-target/configurations/services/net.solarnetwork.central.user.biz.dao.DaoRegistrationBiz.cfg ]; then
	echo 'Creating developer X.509 subject pattern...'
	cat > ~/git/solarnetwork-build/solarnetwork-osgi-target/configurations/services/net.solarnetwork.central.user.biz.dao.DaoRegistrationBiz.cfg <<-EOF
		networkCertificateSubjectDNFormat = UID=%s,O=SolarDev
EOF
fi

if [ ! -d ~/git/solarnetwork-build/solarnetwork-osgi-target/conf/tls ]; then
	echo 'Creating conf/tls directory...'
	mkdir -p ~/git/solarnetwork-build/solarnetwork-osgi-target/conf/tls
	if cd ~/git/solarnetwork-build/solarnetwork-osgi-target/conf/tls; then
		ln -s ../../var/DeveloperCA/central.jks
		ln -s ../../var/DeveloperCA/central-trust.jks
	fi
fi

if [ ! -e ~/git/solarnetwork-external/net.solarnetwork.org.apache.log4j.config/log4j.properties ]; then
	echo 'Creating platform logging configuration...'
	cp ~/git/solarnetwork-external/net.solarnetwork.org.apache.log4j.config/example/log4j-dev.properties \
		~/git/solarnetwork-external/net.solarnetwork.org.apache.log4j.config/log4j.properties
fi

if [ ! -e ~/git/solarnetwork-external/net.solarnetwork.org.apache.log4j.config/log4j.properties ]; then
	echo 'Creating platform logging configuration...'
	cp ~/git/solarnetwork-external/net.solarnetwork.org.apache.log4j.config/example/log4j.properties \
		~/git/solarnetwork-external/net.solarnetwork.org.apache.log4j.config/log4j.properties
fi

if [ ! -e ~/git/solarnetwork-external/org.eclipse.gemini.blueprint.extender.config/META-INF/spring/extender/solarnetwork-context.xml ]; then
	echo 'Creating Gemini Extender configuration...'
	cp ~/git/solarnetwork-external/org.eclipse.gemini.blueprint.extender.config/example/META-INF/spring/extender/solarnetwork-context.xml \
		~/git/solarnetwork-external/org.eclipse.gemini.blueprint.extender.config/META-INF/spring/extender/
fi

if [ ! -e ~/git/solarnetwork-common/net.solarnetwork.common.test/environment/local/log4j.properties ]; then
	echo 'Creating common unit test configuration...'
	cp ~/git/solarnetwork-common/net.solarnetwork.common.test/environment/example/* \
		~/git/solarnetwork-common/net.solarnetwork.common.test/environment/local/
fi

if [ ! -e ~/git/solarnetwork-central/net.solarnetwork.central.test/environment/local/log4j.properties ]; then
	echo 'Creating SolarNet unit test configuration...'
	cp ~/git/solarnetwork-central/net.solarnetwork.central.test/environment/example/* \
		~/git/solarnetwork-central/net.solarnetwork.central.test/environment/local/
fi

if [ ! -e ~/git/solarnetwork-central/net.solarnetwork.central.user.web/web/WEB-INF/packtag.user.properties ]; then
	echo 'Creating SolarUser pack:tag configuration...'
	cp ~/git/solarnetwork-central/net.solarnetwork.central.user.web/example/web/WEB-INF/packtag.user.properties \
		~/git/solarnetwork-central/net.solarnetwork.central.user.web/web/WEB-INF/packtag.user.properties
fi

if [ ! -e ~/git/solarnetwork-node/net.solarnetwork.node.test/environment/local/log4j.properties ]; then
	echo 'Creating SolarNode unit test configuration...'
	cp ~/git/solarnetwork-node/net.solarnetwork.node.test/environment/example/* \
		~/git/solarnetwork-node/net.solarnetwork.node.test/environment/local/
fi

if [ ! -e ~/git/solarnetwork-node/net.solarnetwork.node.setup.web/web/WEB-INF/packtag.user.properties ]; then
	echo 'Creating SolarNode pack:tag configuration...'
	cp ~/git/solarnetwork-node/net.solarnetwork.node.setup.web/example/web/WEB-INF/packtag.user.properties \
		~/git/solarnetwork-node/net.solarnetwork.node.setup.web/web/WEB-INF/packtag.user.properties
fi

eclipseDownload=/var/tmp/eclipse.tgz
eclipseDownloadMD5=d8e1b995e95dbec95d69d62ddf6f94f6
eclipseDownloadHash=
if [ -e "$eclipseDownload" ]; then
	eclipseDownloadHash=`md5sum $eclipseDownload |cut -d' ' -f1`
fi
if [ "$eclipseDownloadHash" != "$eclipseDownloadMD5" ]; then
	echo 'Downloading Eclipse JEE...'
	curl -C - -L -s -S -o $eclipseDownload 'http://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/luna/SR2/eclipse-jee-luna-SR2-linux-gtk.tar.gz&r=1'
fi
if [ -e "$eclipseDownload" ]; then
	eclipseDownloadHash=`md5sum $eclipseDownload |cut -d' ' -f1`
fi
if [ ! -d ~/eclipse -a -e "$eclipseDownload" ]; then
	if [ "$eclipseDownloadHash" = "$eclipseDownloadMD5" ]; then
		echo "Installing Eclipse JEE..."
		tar -C ~/ -xzf "$eclipseDownload"
	else
		echo 'Eclipse Luna not completely downloaded, cannot install.'
	fi
fi

if [ ! -d  ~/workspace/.metadata/.plugins/org.eclipse.core.runtime/.settings ]; then
	mkdir -p ~/workspace/.metadata/.plugins/org.eclipse.core.runtime/.settings
fi

# Add Git repos to Eclipse configuration
if [ ! -e ~/workspace/.metadata/.plugins/org.eclipse.core.runtime/.settings/org.eclipse.egit.core.prefs ]; then
	echo 'Configuring SolarNetwork git repositories in Eclipse...'
	cat > ~/workspace/.metadata/.plugins/org.eclipse.core.runtime/.settings/org.eclipse.egit.core.prefs <<EOF
GitRepositoriesView.GitDirectories=/home/solardev/git/solarnetwork-central/.git\:/home/solardev/git/solarnetwork-common/.git\:/home/solardev/git/solarnetwork-node/.git\:/home/solardev/git/solarnetwork-build/.git\:/home/solardev/git/solarnetwork-external/.git\:
RepositorySearchDialogSearchPath=/home/solardev/git
eclipse.preferences.version=1
EOF
fi

# Add SolarNetwork target platform configuration
if [ ! -e ~/workspace/.metadata/.plugins/org.eclipse.core.runtime/.settings/org.eclipse.pde.core.prefs ]; then
	echo 'Configuring SolarNetwork Eclipse PDE target platform...'
	cat > ~/workspace/.metadata/.plugins/org.eclipse.core.runtime/.settings/org.eclipse.pde.core.prefs <<EOF
eclipse.preferences.version=1
workspace_target_handle=resource\:/solarnetwork-osgi-target/defs/solarnetwork-gemini.target
EOF
fi

# Add SolarNetwork debug launch configuration to Eclipse
if [ ! -e ~/workspace/.metadata/.plugins/org.eclipse.debug.core/.launches/SolarNetwork.launch -a -e /vagrant/SolarNetwork.launch ]; then
	echo 'Creating SolarNetwork Eclipse launch configuration...'
	if [ ! -d ~/workspace/.metadata/.plugins/org.eclipse.debug.core/.launches ]; then
		mkdir -p ~/workspace/.metadata/.plugins/org.eclipse.debug.core/.launches
	fi
	cp /vagrant/SolarNetwork.launch ~/workspace/.metadata/.plugins/org.eclipse.debug.core/.launches
fi

elementIn () {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 0; done
  return 1
}

addTeamProviderRepo () {
	echo "Adding $project to Eclipse Team Project Set..."
	cat >> $2 <<EOF
<project reference="1.0,https://github.com/SolarNetwork/${1%%/*}.git,develop,${1##*/}"/>
EOF
}

skipProjects=("solarnetwork-build/archiva-obr-plugin" \
	"solarnetwork-build/net.solarnetwork.pki.sun.security" \
	"solarnetwork-central/net.solarnetwork.central.common.mail.javamail" \
	"solarnetwork-central/net.solarnetwork.central.user.pki.dogtag" \
	"solarnetwork-central/net.solarnetwork.central.user.pki.dogtag.test" \
	"solarnetwork-node/net.solarnetwork.node.config" \
	"solarnetwork-node/net.solarnetwork.node.setup.developer" \
	"solarnetwork-node/net.solarnetwork.node.upload.mock" )
# Generate Eclipse Team Project Set of all projects to import
if [ ! -e ~/SolarNetworkTeamProjectSet.psf ]; then
	cat > ~/SolarNetworkTeamProjectSet.psf <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<psf version="2.0">
<provider id="org.eclipse.egit.core.GitProvider">
EOF

	cd ~/git
	projects=`ls -1d */*`
	for project in $projects; do
		if elementIn "$project" "${skipProjects[@]}"; then
			echo "Skipping project $project"
		else
			addTeamProviderRepo "$project" ~/SolarNetworkTeamProjectSet.psf
		fi
	done

	cat >> ~/SolarNetworkTeamProjectSet.psf <<EOF
</provider>
</psf>
EOF
fi

if [ ! -d ~/.fluxbox ]; then
	mkdir ~/.fluxbox
fi

# Setup Fluxbox menu
if [ ! -e ~/.fluxbox/menu ]; then
	echo 'Configuring Fluxbox menu...'
	cat > ~/.fluxbox/menu <<EOF
[begin] (SolarNetwork Dev)
        [exec] (Eclipse) { ~/eclipse/eclipse -data ~/workspace } <~/eclipse/icon.xpm>
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
if [ -x ~/eclipse/eclipse -a ! -e ~/.fluxbox/startup ]; then
	echo 'Configuring Eclipse to start on login...'
	cat > ~/.fluxbox/startup <<EOF
#!/bin/sh

xmodmap "/home/solardev/.Xmodmap"

if [ -x ~/eclipse/eclipse ]; then
	~/eclipse/eclipse -data ~/workspace &
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

# Install EGit
# ls -1d ~/eclipse/features/org.eclipse.egit* >/dev/null 2>&1
# if [ $? -ne 0 -a -x ~/eclipse/eclipse ]; then
# 	echo 'Installing EGit...'
# 	~/eclipse/eclipse -application org.eclipse.equinox.p2.director \
# 		-repository http://download.eclipse.org/releases/luna \
# 		-installIU org.eclipse.egit.feature.group \
# 		-tag AddEGit \
# 		-destination ~/eclipse/ -profile SDKProfile
# fi

cat <<EOF

SolarNetwork development environment setup complete. Log into the VM as
solardev:solardev and Eclipse will launch automatically. Right-click on
the desktop to access a menu of other options.
EOF
