#!/bin/bash
# Sets up the SolarNetwork PostgreSQL DB

WORKSPACE="$1"
DB="${2:-solarnetwork}"
DB_OWNER="${3:-solarnet}"

# Make sure that a workspace has been specified
if [ -z "$WORKSPACE" ]; then
  "A SolarNetwork workspace must be specified"
  exit 1
fi

# Check that PostgreSQL is installed
type -P psql &>/dev/null && echo "Configuring postgres"  || { echo "$psql command not found."; exit 1; }

## Set up the PostgreSQL database
#dropdb solarnetwork
#dropuser solarnet

#dropdb solarnet_unittest
#dropuser solarnet_test

createuser -AD "$DB_OWNER"
psql -U postgres -d postgres -c "ALTER ROLE $DB_OWNER WITH PASSWORD '$DB_OWNER'"
createdb -E UNICODE -l C -T template0 -O "$DB_OWNER" "$DB"
psql -U postgres -d "$DB" -c 'CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public'
psql -U postgres -d "$DB" -c 'CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public'
psql -U postgres -d "$DB" -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public'

# Setup base database
cd $WORKSPACE/solarnetwork-central/solarnet-db-setup/postgres

psql -d "$DB" -U "$DB_OWNER" -f postgres-init.sql

# DRAS extensions
if [ -d "$WORKSPACE/solarnetwork-dras" ]; then
  echo "Installing DRAS extensions"

  cd $WORKSPACE/solarnetwork-dras/net.solarnetwork.central.dras/defs/sql/postgres

  psql -d "$DB" -U "$DB_OWNER" -f dras-reboot.sql
  psql -d "$DB" -U "$DB_OWNER" -c "ALTER ROLE $DB_OWNER SET intervalstyle = 'iso_8601'"
fi
