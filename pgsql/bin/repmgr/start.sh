#!/usr/bin/env bash
set -e

echo ">>> Waiting $REPMGR_WAIT_POSTGRES_START_TIMEOUT seconds for postgres on this node to start repmgr..."
if [[ "$CURRENT_REPLICATION_PRIMARY_HOST" == "" ]] && [[ "$UPDATE_EXISTING_DB" == "1" ]]; then
	set +e
	wait_db $CLUSTER_NODE_NETWORK_NAME $REPLICATION_PRIMARY_PORT $POSTGRES_USER $POSTGRES_PASSWORD $POSTGRES_DB $REPMGR_WAIT_POSTGRES_START_TIMEOUT
	DB_EXISTS=`PGPASSWORD=$REPLICATION_PASSWORD psql --username "$REPLICATION_USER" -h $CLUSTER_NODE_NETWORK_NAME -p $REPLICATION_PRIMARY_PORT -tAc "SELECT 1 FROM pg_database WHERE datname='$REPLICATION_DB'" template1`
	if [[ "$DB_EXISTS" != "1" ]]; then
		echo ">>> No replication database : creating it"
		gosu postgres /usr/local/bin/cluster/postgres/primary/entrypoint.sh
		[[ -e /etc/postgresql/primary.default.conf ]] && cp /etc/postgresql/primary.default.conf /etc/postgresql/primary.conf
		[[ -e /etc/postgresql/standby.conf ]] && rm /etc/postgresql/standby.conf 
		gosu postgres pg_ctl -D "$PGDATA" -m fast -w stop
		gosu postgres /docker-entrypoint.sh postgres &
	fi
	set -e
else
	wait_db $CLUSTER_NODE_NETWORK_NAME $REPLICATION_PRIMARY_PORT $REPLICATION_USER $REPLICATION_PASSWORD $REPLICATION_DB $REPMGR_WAIT_POSTGRES_START_TIMEOUT
fi

sleep "$WAIT_SYSTEM_IS_STARTING"


if [[ "$CURRENT_REPLICATION_PRIMARY_HOST" == "" ]]; then
    NODE_TYPE='master'
else
    NODE_TYPE='standby'
fi

echo ">>> Registering node with role $NODE_TYPE"
gosu postgres repmgr "$NODE_TYPE" register --force || echo ">>>>>> Can't re-register node. Means it has been already done before!"

if [[ "$NODE_TYPE" == 'standby' ]]; then
    gosu postgres /usr/local/bin/cluster/repmgr/events/execs/includes/lock_standby.sh
fi

echo ">>> Starting repmgr daemon..."
rm -rf "$REPMGR_PID_FILE"
gosu postgres repmgrd -vvv --pid-file="$REPMGR_PID_FILE"