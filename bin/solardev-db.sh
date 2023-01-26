#!/bin/bash
# Sets up the SolarNetwork PostgreSQL DB

WORKSPACE=""
DB="solarnetwork"
DB_OWNER="solarnet"

while getopts ":D:g:O:w:" opt; do
	case $opt in
		D) DB="${OPTARG}";;
		g) GIT_HOME="${OPTARG}";;
		O) DB_OWNER="${OPTARG}";;
		w) WORKSPACE="${OPTARG}";;
		*)
			echo "Unknown argument ${OPTARG}"
			exit 1
	esac
done
shift $(($OPTIND - 1))

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

#dropdb solarnetwork_unittest
#dropuser solartest

createuser -AD "$DB_OWNER"
psql -U postgres -d postgres -c "ALTER ROLE $DB_OWNER WITH PASSWORD '$DB_OWNER'"
createdb -E UNICODE -l C -T template0 -O "$DB_OWNER" "$DB"
psql -U postgres -d "$DB" -c 'CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public'
psql -U postgres -d "$DB" -c 'CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public'
psql -U postgres -d "$DB" -c 'CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public'
psql -U postgres -d "$DB" -c 'CREATE EXTENSION IF NOT EXISTS timescaledb WITH SCHEMA public'
psql -U postgres -d "$DB" -c 'CREATE EXTENSION IF NOT EXISTS aggs_for_vecs WITH SCHEMA public'

# Setup base database
cd $WORKSPACE/solarnetwork-central/solarnet-db-setup/postgres

psql -d "$DB" -U "$DB_OWNER" -f postgres-init.sql
