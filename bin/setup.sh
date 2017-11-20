#!/bin/bash
# Configures a development environment on OSX
# Requires Eclipse and PLSQL to be installed
#
# Usage: ./setup.sh <eclipse workspace>

WORKSPACE=$1

# Make sure that a workspace has been specified
if [ -z "$WORKSPACE" ]; then
  echo "Usage: ./setup.sh <workspace>"
  exit 1
fi

./solardev-git.sh $WORKSPACE
cd .
./solardev-workspace.sh $WORKSPACE
cd .
./solardev-db.sh $WORKSPACE
