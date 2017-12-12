#!/bin/bash
# Sets up the SolarNetwork PostgreSQL DB

WORKSPACE=$1

# Make sure that a workspace has been specified
if [ -z "$WORKSPACE" ]; then
  "A SolarNetwork workspace must be specified"
  exit 1
fi

# Check that PostgreSQL is installed
type -P psql &>/dev/null && echo "Configuring psql"  || { echo "$psql command not found."; exit 1; }

# Set up the PostgreSQL database
dropdb solarnetwork
dropuser solarnet

dropdb solarnet_unittest
dropuser solarnet_test

createuser -AD solarnet
psql -U postgres -d postgres -c "alter user solarnet with password 'solarnet';"
createdb -E UNICODE -l C -T template0 -O solarnet solarnetwork
createlang plv8 solarnetwork
psql -U postgres -d solarnetwork -c "CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;"
psql -U postgres -d solarnetwork -c "CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;"

createuser -AD solarnet_test
psql -U postgres -d postgres -c "alter user solarnet_test with password 'solarnet_test';"
createdb -E UNICODE -l C -T template0 -O solarnet_test solarnet_unittest
createlang plv8 solarnet_unittest
psql -U postgres -d solarnet_unittest -c "CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;"
psql -U postgres -d solarnet_unittest -c "CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;"

# Setup base database
cd $WORKSPACE/solarnetwork-central/solarnet-db-setup/postgres

# for some reason, plv8 often chokes on the inline comments, so strip them out
sed -e '/^\/\*/d' -e '/^ \*/d' postgres-init-plv8.sql | psql -d solarnetwork -U postgres
psql -d solarnetwork -U solarnet -f postgres-init.sql
# Loading of initial data via postgres-init-data.sql is not currently supported
# psql -d solarnetwork -U solarnet -f postgres-init-data.sql

# for some reason, plv8 often chokes on the inline comments, so strip them out
sed -e '/^\/\*/d' -e '/^ \*/d' postgres-init-plv8.sql | psql -d solarnet_unittest -U postgres
psql -d solarnet_unittest -U solarnet_test -f postgres-init.sql

# DRAS extensions
if [ -d "$WORKSPACE/solarnetwork-dras" ]; then
  echo "Installing DRAS extensions"

  cd $WORKSPACE/solarnetwork-dras/net.solarnetwork.central.dras/defs/sql/postgres

  psql -d solarnetwork -U solarnet -f dras-reboot.sql
  psql -d solarnetwork -U solarnet -c "ALTER ROLE solarnet SET intervalstyle = 'iso_8601'"
fi
