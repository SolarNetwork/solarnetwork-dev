#!/bin/bash
# Configures a development environment on OSX
# Requires Eclipse and PLSQL to be installed
#
# Usage: ./setup.sh <eclipse workspace> <git home>

WORKSPACE=$1
GIT=${2:-$WORKSPACE}

# Make sure that a workspace has been specified
if [ -z "$WORKSPACE" ]; then
  echo "Usage: ./setup.sh <workspace> [<git home>]"
  exit 1
fi

./solardev-git.sh $GIT
cd .
./solardev-workspace.sh $WORKSPACE $GIT ../
cd .
./solardev-db.sh $WORKSPACE
