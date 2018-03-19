#!/bin/bash
# This script configures the Eclipse workspace
#
# Usage: ./solardev-workspace.sh <workspace> (<git location>)
# if no git location is specified then the workspace will be used

WORKSPACE=${1:-~/workspace}
GIT_HOME=${2:-~/git}
SCRIPT_HOME=${3:-/vagrant}

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
LAUNCH_FILE="$SCRIPT_HOME/eclipse/SolarNetwork.launch"
if [ ! -e $WORKSPACE/.metadata/.plugins/org.eclipse.debug.core/.launches/SolarNetwork.launch -a -e $LAUNCH_FILE ]; then
  echo -e '\nCreating SolarNetwork Eclipse launch configuration...'
  if [ ! -d $WORKSPACE/.metadata/.plugins/org.eclipse.debug.core/.launches ]; then
    mkdir -p $WORKSPACE/.metadata/.plugins/org.eclipse.debug.core/.launches
  fi
  cp $LAUNCH_FILE $WORKSPACE/.metadata/.plugins/org.eclipse.debug.core/.launches
fi

# Configure SolarNetwork toString() format template
if [ ! -e "$WORKSPACE/.metadata/.plugins/org.eclipse.jdt.ui/dialog_settings.xml" ]; then
  echo -e '\nCreating SolarNetwork Eclipse toString template configuration...'
  if [ ! -d "$WORKSPACE/.metadata/.plugins/org.eclipse.jdt.ui" ]; then
    mkdir -p "$WORKSPACE/.metadata/.plugins/org.eclipse.jdt.ui"
  fi
  cp "$SCRIPT_HOME/eclipse/org.eclipse.jdt.ui/dialog_settings.xml" "$WORKSPACE/.metadata/.plugins/org.eclipse.jdt.ui/dialog_settings.xml"
elif [ -e "$SCRIPT_HOME/bin/add-tostring-template.awk" ]; then
  if ! grep -q "SolarNetwork" "$WORKSPACE/.metadata/.plugins/org.eclipse.jdt.ui/dialog_settings.xml"; then
    echo -e '\nCreating SolarNetwork Eclipse toString template configuration...'
    awk -f $SCRIPT_HOME/bin/add-tostring-template.awk $WORKSPACE/.metadata/.plugins/org.eclipse.jdt.ui/dialog_settings.xml >/tmp/dialog_settings.xml
    mv -f /tmp/dialog_settings.xml $WORKSPACE/.metadata/.plugins/org.eclipse.jdt.ui/dialog_settings.xml
  fi
fi

# Install SolarNetwork code templates and formatting rules
setProperty () {
  # expects: property name, value, file path
  if grep -q "^$1=" "$3"; then
    # Update the existing property
    awk -v pat="^$1=" -v value="`echo "$1=$2"  | sed -e 's/=/\\=/g' -e 's/\\n/\\\\n/g'`" '{ if ($0 ~ pat) print value; else print $0; }' $3 > $3.tmp
    mv $3.tmp $3
  else
    # Append as a new property
    printf "$1=$2\n" >> $3
  fi
}

getXmlPropertyFromFile () {
  # expects: file path
  sed -e ':a' -e 'N' -e '$!ba' -e 's/\n/\\\\n/g' -e 's/=/\\=/g' $1
}

JDT_UI_PREFS="$WORKSPACE/.metadata/.plugins/org.eclipse.core.runtime/.settings/org.eclipse.jdt.ui.prefs"
if [ ! -e "$JDT_UI_PREFS" ]; then
  touch $JDT_UI_PREFS
fi
echo -e '\nUpdating SolarNetwork Eclipse code templates and formatting rules...'
code_templates="`getXmlPropertyFromFile $GIT_HOME/solarnetwork-build/solarnetwork-osgi-target/defs/solarnetwork-codetemplates.xml`"
formatterprofiles="`getXmlPropertyFromFile $GIT_HOME/solarnetwork-build/solarnetwork-osgi-target/defs/solarnetwork-codeformat.xml`"

setProperty "formatter_profile" "_SolarNetwork" "$JDT_UI_PREFS"
setProperty "org.eclipse.jdt.ui.text.code_templates_migrated" "true" "$JDT_UI_PREFS"
setProperty "org.eclipse.jdt.ui.formatterprofiles" "$formatterprofiles" "$JDT_UI_PREFS"
setProperty "org.eclipse.jdt.ui.text.custom_code_templates" "$code_templates" "$JDT_UI_PREFS"

# Configure auto formatting on save
setProperty "editor_save_participant_org.eclipse.jdt.ui.postsavelistener.cleanup" "true" "$JDT_UI_PREFS"

setProperty "sp_cleanup.format_source_code" "true" "$JDT_UI_PREFS"
setProperty "sp_cleanup.format_source_code_changes_only" "false" "$JDT_UI_PREFS"

setProperty "sp_cleanup.organize_imports" "true" "$JDT_UI_PREFS"

setProperty "sp_cleanup.on_save_use_additional_actions" "true" "$JDT_UI_PREFS"
setProperty "sp_cleanup.remove_unused_imports" "true" "$JDT_UI_PREFS"
setProperty "sp_cleanup.remove_unnecessary_casts" "true" "$JDT_UI_PREFS"
setProperty "sp_cleanup.add_missing_annotations" "true" "$JDT_UI_PREFS"
setProperty "sp_cleanup.add_missing_override_annotations" "true" "$JDT_UI_PREFS"
setProperty "sp_cleanup.add_missing_override_annotations_interface_methods" "true" "$JDT_UI_PREFS"
setProperty "sp_cleanup.add_missing_deprecated_annotations" "true" "$JDT_UI_PREFS"

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
