#!/bin/bash
# Checks out the SolarNetwork source code.
#
# Usage: ./solardev-git.sh <checkout directory>

GIT_HOME=""
GIT_BRANCH="develop"
GIT_BRANCH_FALLBACK="develop"
GIT_REPOS="build external common central node"

while getopts ":b:B:g:r:w:" opt; do
	case $opt in
		b) GIT_BRANCH="${OPTARG}";;
		B) GIT_BRANCH_FALLBACK="${OPTARG}";;
		g) GIT_HOME="${OPTARG}";;
		r) GIT_REPOS="${OPTARG}";;
		w) WORKSPACE="${OPTARG}";;
		*)
			echo "Unknown argument ${OPTARG}"
			exit 1
	esac
done
shift $(($OPTIND - 1))

# Make sure that a workspace has been specified
if [ -z "$GIT_HOME" ]; then
  echo "Usage: ./solardev-git.sh -g <checkout directory> [-b <branch> -B <fallback branch> -r <repo names>]"
  exit 1
fi

if ! grep -q lfs ~/.gitconfig >/dev/null 2>/dev/null; then
	echo -e '\nInitializing git LFS...'
	git lfs install --skip-repo
fi

if [ ! -d "$GIT_HOME" ]; then
  mkdir -p "$GIT_HOME"
fi

echo "Checking out SolarNetwork branch $GIT_BRANCH sources to: $GIT_HOME"

# Checkout SolarNetwork sources
for proj in $GIT_REPOS; do
	if [ ! -d $GIT_HOME/solarnetwork-$proj ]; then
		echo -e "\nCloning project solarnetwork-$proj..."
		mkdir -p $GIT_HOME/solarnetwork-$proj
		git clone "https://github.com/SolarNetwork/solarnetwork-$proj.git" $GIT_HOME/solarnetwork-$proj
		cd $GIT_HOME/solarnetwork-$proj

		# See if requested branch exists, and if so use that, otherwise use fallback branch
		if [ -z "$(git branch --list -a origin/$GIT_BRANCH)" ]; then
			echo -e "\nRemote branch [$GIT_BRANCH] not found in project [$proj], falling back to branch [$GIT_BRANCH_FALLBACK]"
			git checkout -b $GIT_BRANCH_FALLBACK origin/$GIT_BRANCH_FALLBACK
		else
			git checkout -b $GIT_BRANCH origin/$GIT_BRANCH
		fi
	fi
done

# Setup standard setup files
if [ ! -d "$GIT_HOME/solarnetwork-build/solarnetwork-osgi-target/config" ]; then
	echo -e '\nCreating solarnetwork-build/solarnetwork-osgi-target/config files...'
	cp -a "$GIT_HOME/solarnetwork-build/solarnetwork-osgi-target/example/config" "$GIT_HOME/solarnetwork-build/solarnetwork-osgi-target/"

	# Enable the SolarIn SSL connector in tomcat-server.xml
	sed -e '14s/$/-->/' -e '21d' "$GIT_HOME/solarnetwork-build/solarnetwork-osgi-target/example/config/tomcat-server.xml" \
		> "$GIT_HOME/solarnetwork-build/solarnetwork-osgi-target/config/tomcat-server.xml"
fi

if [ ! -e "$GIT_HOME/solarnetwork-build/solarnetwork-osgi-target/configurations/services/net.solarnetwork.jdbc.pool.hikari-central.cfg" ]; then
	echo -e '\nCreating JDBC configuration...'
	cat > "$GIT_HOME/solarnetwork-build/solarnetwork-osgi-target/configurations/services/net.solarnetwork.jdbc.pool.hikari-central.cfg" <<-EOF
		service.factoryPid = net.solarnetwork.jdbc.pool.hikari
		serviceProperty.db = central
		dataSourceFactory.filter = (osgi.jdbc.driver.class=org.postgresql.Driver)
		dataSource.url = jdbc:postgresql://localhost:5432/solarnetwork
		dataSource.user = solarnet
		dataSource.password = solarnet
		pingTest.query = SELECT CURRENT_TIMESTAMP
		minimumIdle = 1
		maximumPoolSize = 10
EOF
fi

# copy conf files; skipping any that already exist
if [ -d conf/solarnetwork-central/solarnet -a -d "$GIT_HOME/solarnetwork-central/solarnet" ]; then
	echo -e '\nCreating initial SolarNet configuration...'
	cp -anv conf/solarnetwork-central/solarnet "$GIT_HOME/solarnetwork-central/"
fi

if [ ! -d "$GIT_HOME/solarnetwork-build/solarnetwork-osgi-target/conf/tls" ]; then
	echo -e '\nCreating conf/tls directory...'
	mkdir -p "$GIT_HOME/solarnetwork-build/solarnetwork-osgi-target/conf/tls"
	if cd "$GIT_HOME/solarnetwork-build/solarnetwork-osgi-target/conf/tls"; then
		ln -s ../../var/DeveloperCA/central.jks
		ln -s ../../var/DeveloperCA/central-trust.jks
		ln -s ../../var/DeveloperCA/central-trust.jks trust.jks
	fi
fi

if [ ! -e "$GIT_HOME/solarnetwork-build/solarnetwork-osgi-target/configurations/services/net.solarnetwork.node.setup.cfg" ]; then
	echo 'Creating developer SolarNode TLS configuration...'
	cat > "$GIT_HOME/solarnetwork-build/solarnetwork-osgi-target/configurations/services/net.solarnetwork.node.setup.cfg" <<-EOF
		PKIService.trustStorePassword = dev123
EOF
fi

if [ ! -e "$GIT_HOME/solarnetwork-build/solarnetwork-osgi-target/config/log4j2.xml" ]; then
	echo -e '\nCreating SolarNode logging configuration...'
	cp "$GIT_HOME/solarnetwork-build/solarnetwork-osgi-target/example/config/log4j2.xml" \
		"$GIT_HOME/solarnetwork-build/solarnetwork-osgi-target/config/log4j2.xml"
fi

if [ ! -e "$GIT_HOME/solarnetwork-external/org.eclipse.gemini.blueprint.extender.config/META-INF/spring/extender/solarnetwork-context.xml" ]; then
	echo -e '\nCreating Gemini Extender configuration...'
	cp "$GIT_HOME/solarnetwork-external/org.eclipse.gemini.blueprint.extender.config/example/META-INF/spring/extender/solarnetwork-context.xml" \
		"$GIT_HOME/solarnetwork-external/org.eclipse.gemini.blueprint.extender.config/META-INF/spring/extender/"
fi

if [ ! -e "$GIT_HOME/solarnetwork-common/net.solarnetwork.common.test/environment/local/log4j2-test.xml" ]; then
	echo -e '\nCreating common unit test logging configuration...'
	cp "$GIT_HOME/solarnetwork-common/net.solarnetwork.common.test/environment/local/log4j2-test.xml" \
		"$GIT_HOME/solarnetwork-common/net.solarnetwork.common.test/environment/local/"
fi

if [ ! -e "$GIT_HOME/solarnetwork-node/net.solarnetwork.node.test/environment/local/log4j2-test.xml" ]; then
	echo -e '\nCreating SolarNode unit test configuration...'
	cp "$GIT_HOME/solarnetwork-node/net.solarnetwork.node.test/environment/example"/* \
		"$GIT_HOME/solarnetwork-node/net.solarnetwork.node.test/environment/local/"
fi

if [ ! -e "$GIT_HOME/solarnetwork-node/net.solarnetwork.node.setup.web/web/WEB-INF/packtag.user.properties" ]; then
	echo -e '\nCreating SolarNode pack:tag configuration...'
	cp "$GIT_HOME/solarnetwork-node/net.solarnetwork.node.setup.web/example/web/WEB-INF/packtag.user.properties" \
		"$GIT_HOME/solarnetwork-node/net.solarnetwork.node.setup.web/web/WEB-INF/packtag.user.properties"
fi
