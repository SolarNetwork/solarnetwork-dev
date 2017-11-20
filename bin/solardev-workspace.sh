#!/bin/bash
# This script configures the Eclipse workspace
#
# Usage: ./solardev-workspace.sh <workspace> (<git location>)
# if no git location is specified then the workspace will be used

WORKSPACE=$1
GIT_HOME=$2

# Make sure that a workspace has been specified
if [ -z "$WORKSPACE" ]; then
  echo "Usage: ./solardev-workspace.sh <workspace> (<git location>)"
  exit 1
fi
if [ -z "$GIT_HOME" ]; then
  echo "No Git directory specified, defaulting to using workspace: $WORKSPACE"
  GIT_HOME=$WORKSPACE
fi

if [ ! -d $WORKSPACE ]; then
  mkdir -p $WORKSPACE
fi

echo "Configuring SolarNetwork workspace: $WORKSPACE"

LAUNCH_FILE="../eclipse/SolarNetwork.launch"
if [ -e /vagrant/eclipse/SolarNetwork.launch ]; then
  # Use the vagrant location when in that context
  LAUNCH_FILE="/vagrant/eclipse/SolarNetwork.launch"
fi
echo "Launch file: $LAUNCH_FILE"

# Setup Eclipse
if [ ! -d  $WORKSPACE/.metadata/.plugins/org.eclipse.core.runtime/.settings ]; then
  mkdir -p $WORKSPACE/.metadata/.plugins/org.eclipse.core.runtime/.settings
fi

# Add Git repos to Eclipse configuration
# Make sure that the selected GIT_HOME is used by egit in eclipse
# This allows us to generate multiple workspaces with independent source
if [ ! -e $WORKSPACE/.metadata/.plugins/org.eclipse.core.runtime/.settings/org.eclipse.egit.core.prefs ]; then
  echo -e '\nConfiguring SolarNetwork git repositories in Eclipse...'
  cat > $WORKSPACE/.metadata/.plugins/org.eclipse.core.runtime/.settings/org.eclipse.egit.core.prefs <<EOF
GitRepositoriesView.GitDirectories=$GIT_HOME/solarnetwork-central/.git\:$GIT_HOME/solarnetwork-common/.git\:$GIT_HOME/solarnetwork-node/.git\:$GIT_HOME/solarnetwork-build/.git\:$GIT_HOME/solarnetwork-external/.git\:
RepositorySearchDialogSearchPath=$GIT_HOME
eclipse.preferences.version=1
core_defaultRepositoryDir=$GIT_HOME
EOF
fi

# Add SolarNetwork target platform configuration
if [ ! -e $WORKSPACE/.metadata/.plugins/org.eclipse.core.runtime/.settings/org.eclipse.pde.core.prefs ]; then
  echo -e '\nConfiguring SolarNetwork Eclipse PDE target platform...'
  cat > $WORKSPACE/.metadata/.plugins/org.eclipse.core.runtime/.settings/org.eclipse.pde.core.prefs <<EOF
eclipse.preferences.version=1
workspace_target_handle=resource\:/solarnetwork-osgi-target/defs/solarnetwork-gemini.target
EOF
fi

# Add SolarNetwork debug launch configuration to Eclipse
if [ ! -e $WORKSPACE/.metadata/.plugins/org.eclipse.debug.core/.launches/SolarNetwork.launch -a -e $LAUNCH_FILE ]; then
  echo -e '\nCreating SolarNetwork Eclipse launch configuration...'
  if [ ! -d $WORKSPACE/.metadata/.plugins/org.eclipse.debug.core/.launches ]; then
    mkdir -p $WORKSPACE/.metadata/.plugins/org.eclipse.debug.core/.launches
  fi
  cp $LAUNCH_FILE $WORKSPACE/.metadata/.plugins/org.eclipse.debug.core/.launches
fi

# Configure the eclipse workspace projects

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
  "solarnetwork-common/net.solarnetwork.pidfile" \
  "solarnetwork-node/net.solarnetwork.node.config" \
  "solarnetwork-node/net.solarnetwork.node.setup.developer" \
  "solarnetwork-node/net.solarnetwork.node.upload.mock" \
  "solarnetwork-node/net.solarnetwork.node.system.ssh" )
# Generate Eclipse Team Project Set of all projects to import
if [ ! -e $WORKSPACE/SolarNetworkTeamProjectSet.psf ]; then
  echo -e '\nCreating Eclipse team project set...'
  cat > $WORKSPACE/SolarNetworkTeamProjectSet.psf <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<psf version="2.0">
<provider id="org.eclipse.egit.core.GitProvider">
EOF

  cd $GIT_HOME
  projects=`ls -1d */*`
  for project in $projects; do
    if elementIn "$project" "${skipProjects[@]}"; then
      echo "Skipping project $project"
    else
      addTeamProviderRepo "$project" $WORKSPACE/SolarNetworkTeamProjectSet.psf
    fi
  done

  cat >> $WORKSPACE/SolarNetworkTeamProjectSet.psf <<EOF
</provider>
</psf>
EOF
fi
