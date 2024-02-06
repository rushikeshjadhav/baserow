#!/usr/bin/env bash
set -Eeo pipefail

# A helper script which can create an empty database with a new user as specified by
# the environment variables POSTGRES_DATABASE, POSTGRES_USER and POSTGRES_PASSWORD.

docker_verify_minimum_env() {
  if [[ -z "$POSTGRES_USER" ]]; then
    echo "Must set POSTGRES_USER" 2>&1
    exit 1;
  fi
  if [[ -z "$POSTGRES_DB" ]]; then
    echo "Must set POSTGRES_DB" 2>&1
    exit 1;
  fi
  if [[ -z "$POSTGRES_PASSWORD" ]]; then
    echo "Must set POSTGRES_PASSWORD" 2>&1
    exit 1;
  fi
  if [[ -z "$PGDATA" ]]; then
    echo "Must set PGDATA" 2>&1
    exit 1;
  fi
	# check password first so we can output the warning before postgres
	# messes it up
	if [ "${#POSTGRES_PASSWORD}" -ge 100 ]; then
		cat >&2 <<-'EOWARN'
			WARNING: The supplied POSTGRES_PASSWORD is 100+ characters.
			  This will not work if used via PGPASSWORD with "psql".
			  https://www.postgresql.org/message-id/flat/E1Rqxp2-0004Qt-PL%40wrigleys.postgresql.org (BUG #6412)
			  https://github.com/docker-library/postgres/issues/507
		EOWARN
	fi
}

# Execute sql script
docker_process_sql() {
	local query_runner=( psql -v ON_ERROR_STOP=1 --no-password --no-psqlrc --dbname "$POSTGRES_DB" )
	"${query_runner[@]}" "$@"
}

# create initial database
# uses environment variables for input: POSTGRES_DB
docker_setup_db() {
	local dbAlreadyExists
	dbAlreadyExists="$(
		docker_process_sql --dbname postgres --set db="$POSTGRES_DB" --tuples-only <<-'EOSQL'
			SELECT 1 FROM pg_database WHERE datname = :'db' ;
		EOSQL
	)"
	if [ -z "$dbAlreadyExists" ]; then
		docker_process_sql --dbname postgres \
		  --set db="$POSTGRES_DB" \
		  --set pass="$POSTGRES_PASSWORD" \
		  --set user="$POSTGRES_USER" \
		  <<-'EOSQL'
			CREATE DATABASE :"db";
			create user :"user" with encrypted password :'pass';
			grant all privileges on database :"db" to :"user";
		EOSQL
	fi
}

rehash_user_password() {
		docker_process_sql --dbname $POSTGRES_DB \
		  --set pass="$POSTGRES_PASSWORD" \
		  --set user="$POSTGRES_USER" \
		  <<-'EOSQL'
                        ALTER USER :"user" WITH PASSWORD :'pass';
		EOSQL
}

# start postgresql server for setting up or running scripts
docker_temp_server_start() {
	# internal start of server in order to allow setup using psql client
	PGUSER="${PGUSER:-$POSTGRES_USER}" \
	pg_ctlcluster "$POSTGRES_VERSION" main start -- -w -o "-c listen_addresses=''"
}

# stop postgresql server after done setting up user and running scripts
docker_temp_server_stop() {
	PGUSER="${PGUSER:-postgres}" \
	pg_ctlcluster "$POSTGRES_VERSION" main stop -- -m fast -w
}

_main() {
    export PGDATA="$DATA_DIR/postgres/"
    export POSTGRES_USER=$DATABASE_USER
    export POSTGRES_PASSWORD=$DATABASE_PASSWORD
    export POSTGRES_DB=$DATABASE_NAME

    chown -R postgres:postgres "$DATA_DIR/"

    if [ "$(id -u)" = '0' ]; then
      # then restart script as postgres user
      echo "Becoming postgres superuser to run setup SQL commands:"
      su postgres -c "${BASH_SOURCE[0]} $*"
    elif [ "$1" == "setup" ]; then
      shift
      ALREADY_SETUP_INDICATOR_FILE="$PGDATA/baserow_db_setup"
      if [ -f "$ALREADY_SETUP_INDICATOR_FILE" ]; then
        echo
        echo 'PostgreSQL Database directory appears to contain a database; Skipping initialization'
        echo

        db_version=$(cat "${PGDATA}/PG_VERSION")

        if [ "$db_version" = "11" ]; then
          echo
          echo 'Upgrading PostgreSQL data directory to version 15 . . .'
          echo

          ./upgrade_postgres.sh
          upgrade_status=$?

          if [ $upgrade_status -ne 0 ]; then
            set +e
            echo
            echo "Upgrading to PostgreSQL 15 failed with exit code $upgrade_status"
            echo
            exit 1
          else
            echo
            echo '. . . PostgreSQL data directory upgrade complete, continuing setup.'
            echo
            # Re-enable 'exit immediately' option.
            set -e
          fi
        else
          echo
          echo 'PostgreSQL data directory is already compatible with PostgreSQL version 15.'
          echo
        fi
      else
        docker_verify_minimum_env

        cp -pR "/var/lib/postgresql/$POSTGRES_VERSION/main/." "$DATA_DIR/postgres/"
        docker_temp_server_start "$@"
        docker_setup_db
        touch "$ALREADY_SETUP_INDICATOR_FILE"
        docker_temp_server_stop

        echo
        echo 'PostgreSQL init process complete; ready for start up.'
        echo
      fi
    elif [ "$1" == "run" ]; then
      shift
      if [[ $(pgrep -f "bin/postgres") ]]; then
        echo "PostgreSQL is already running. Directly running SQL."
        docker_process_sql "$@"
      else
        echo "No running postgresql found, starting one up..."
        docker_temp_server_start
        docker_process_sql "$@"
        docker_temp_server_stop
      fi
    else
      echo "Unknown argument $1 it must be either 'setup' or 'run ...'"
      exit 1
    fi
}

_main "$@"
