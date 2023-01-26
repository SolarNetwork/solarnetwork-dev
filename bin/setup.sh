#!/usr/bin/env bash
# Configures a development environment on OSX
# Requires Eclipse and PLSQL to be installed
#
# Usage: ./setup.sh -w <eclipse workspace> -g <git checkout dir>

GIT_HOME=""
WORKSPACE=""

while getopts ":g:w:" opt; do
	case $opt in
		g) GIT_HOME="${OPTARG}";;
		w) WORKSPACE="${OPTARG}";;
		*)
			echo "Unknown argument ${OPTARG}"
			exit 1
	esac
done
shift $(($OPTIND - 1))

# Make sure that a workspace has been specified
if [ -z "$WORKSPACE" ]; then
  echo "Usage: ./setup.sh -w <workspace> [-g <git checkout dir>]"
  exit 1
elif [ -z "$GIT_HOME" ]; then
	echo "Defaulting git checkout directory to Eclipse workspace [$WORKSPACE]."
	GIT_HOME="$WORKSPACE"
fi

./solardev-git.sh -g "$GIT_HOME"
cd .
./solardev-workspace.sh -w "$WORKSPACE" -g "$GIT_HOME" ../
cd .
./solardev-db.sh -w "$WORKSPACE"
