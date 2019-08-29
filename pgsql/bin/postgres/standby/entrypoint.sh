#!/usr/bin/env bash
set -e

# allow giving port 
CURRENT_REPLICATION_PRIMARY_PORT=$REPLICATION_PRIMARY_PORT
CURRENT_REPLICATION_PRIMARY_HOST_ONLY=$CURRENT_REPLICATION_PRIMARY_HOST
if [[ "$CURRENT_REPLICATION_PRIMARY_HOST" == *":"* ]];then 
	CURRENT_REPLICATION_PRIMARY_PORT=${CURRENT_REPLICATION_PRIMARY_HOST##*:}
	CURRENT_REPLICATION_PRIMARY_HOST_ONLY=${CURRENT_REPLICATION_PRIMARY_HOST%:*}
fi
echo ">>> Waiting for primary node..."
wait_db $CURRENT_REPLICATION_PRIMARY_HOST_ONLY $CURRENT_REPLICATION_PRIMARY_PORT $REPLICATION_USER $REPLICATION_PASSWORD $REPLICATION_DB 300
sleep "$WAIT_SYSTEM_IS_STARTING" && sleep 5

echo ">>> Starting standby node..."
if ! has_pg_cluster; then
    echo ">>>>>> Instance hasn't been set up yet. Clonning primary node..."
    PGPASSWORD=$REPLICATION_PASSWORD gosu postgres repmgr -h $CURRENT_REPLICATION_PRIMARY_HOST_ONLY -p $CURRENT_REPLICATION_PRIMARY_PORT -U $REPLICATION_USER -d $REPLICATION_DB -D $PGDATA standby clone --fast-checkpoint --force
fi
/usr/local/bin/cluster/postgres/standby/configure.sh
rm -f $MASTER_ROLE_LOCK_FILE_NAME # that file should not be here
echo ">>> Starting postgres..."
exec gosu postgres postgres