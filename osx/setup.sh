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

../bin/solardev-git.sh $WORKSPACE
cd .
../bin/solardev-workspace.sh $WORKSPACE
cd .
./setup-db.sh $WORKSPACE
