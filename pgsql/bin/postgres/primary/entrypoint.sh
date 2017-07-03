#!/usr/bin/env bash

/usr/local/bin/cluster/postgres/primary/configure.sh

echo ">>> Creating replication user '$REPLICATION_USER'"
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "CREATE ROLE $REPLICATION_USER WITH REPLICATION PASSWORD '$REPLICATION_PASSWORD' SUPERUSER CREATEDB  CREATEROLE INHERIT LOGIN;"

echo ">>> Creating replication db '$REPLICATION_DB'"
createdb $REPLICATION_DB -O $REPLICATION_USER

if [[ "$BARMAN_SERVER" != "" ]] && [[ "$BARMAN_USE_REPLICATION_SLOTS" == "1" ]]; then
	psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "SELECT * FROM pg_create_physical_replication_slot('barman');"
fi
#TODO: make it more flexible, allow set of IPs
echo "host replication $REPLICATION_USER 0.0.0.0/0 md5" >> $PGDATA/pg_hba.conf
