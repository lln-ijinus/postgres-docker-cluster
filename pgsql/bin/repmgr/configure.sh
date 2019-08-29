#!/usr/bin/env bash
set -e

echo ">>> Setting up repmgr..."
REPMGR_CONFIG_FILE=/etc/repmgr.conf
cp -f /var/cluster_configs/repmgr.conf $REPMGR_CONFIG_FILE

if [ -z "$CLUSTER_NODE_NETWORK_NAME" ]; then
    export CLUSTER_NODE_NETWORK_NAME="`hostname`"
fi

echo ">>> Setting up repmgr config file '$REPMGR_CONFIG_FILE'..."
echo "

pg_bindir=/usr/lib/postgresql/$PG_MAJOR/bin
cluster=$CLUSTER_NAME
node=$NODE_ID
node_name=$NODE_NAME
conninfo='user=$REPLICATION_USER password=$REPLICATION_PASSWORD host=$CLUSTER_NODE_NETWORK_NAME dbname=$REPLICATION_DB port=$REPLICATION_PRIMARY_PORT connect_timeout=$CONNECT_TIMEOUT'
failover=automatic
promote_command='PGPASSWORD=$REPLICATION_PASSWORD repmgr standby promote --log-level DEBUG --verbose'
follow_command='PGPASSWORD=$REPLICATION_PASSWORD repmgr standby follow -W --log-level DEBUG --verbose'
reconnect_attempts=$RECONNECT_ATTEMPTS
reconnect_interval=$RECONNECT_INTERVAL
master_response_timeout=$MASTER_RESPONSE_TIMEOUT
loglevel=$LOG_LEVEL
priority=$NODE_PRIORITY
" >> $REPMGR_CONFIG_FILE
if [[ "$BARMAN_SERVER" != "" ]] && [[ -e "$BARMAN_SSH_PRIV_PATH" ]]; then
	echo "barman_server=$BARMAN_SERVER" >> $REPMGR_CONFIG_FILE
	echo "restore_command=/usr/bin/barman-wal-restore --parallel=4 --bzip2 $BARMAN_SERVER $CLUSTER_NAME %f %p" >> $REPMGR_CONFIG_FILE
fi

echo ">>> Setting up upstream node..."
if [[ "$CURRENT_REPLICATION_PRIMARY_HOST" != "" ]]; then

    LOCKED_STANDBY=`cat $STANDBY_ROLE_LOCK_FILE_NAME || echo ''`
    echo ">>> Previously Locked standby upstream node LOCKED_STANDBY='$LOCKED_STANDBY'"
    if [[ "$LOCKED_STANDBY" != '' ]]; then
        REPLICATION_UPSTREAM_NODE_ID="$LOCKED_STANDBY"
    else
				# allow giving port 
				CURRENT_REPLICATION_PRIMARY_PORT=$REPLICATION_PRIMARY_PORT
				CURRENT_REPLICATION_PRIMARY_HOST_ONLY=$CURRENT_REPLICATION_PRIMARY_HOST
				if [[ "$CURRENT_REPLICATION_PRIMARY_HOST" == *":"* ]];then 
					CURRENT_REPLICATION_PRIMARY_PORT=${CURRENT_REPLICATION_PRIMARY_HOST##*:}
					CURRENT_REPLICATION_PRIMARY_HOST_ONLY=${CURRENT_REPLICATION_PRIMARY_HOST%:*}
				fi
        wait_db $CURRENT_REPLICATION_PRIMARY_HOST_ONLY $CURRENT_REPLICATION_PRIMARY_PORT $REPLICATION_USER $REPLICATION_PASSWORD $REPLICATION_DB 300
        sleep "$WAIT_SYSTEM_IS_STARTING" && sleep 5
        REPLICATION_UPSTREAM_NODE_ID=`PGPASSWORD=$REPLICATION_PASSWORD psql --username "$REPLICATION_USER" -h $CURRENT_REPLICATION_PRIMARY_HOST_ONLY -p $CURRENT_REPLICATION_PRIMARY_PORT -d $REPLICATION_DB -tAc "SELECT id FROM repmgr_$CLUSTER_NAME.repl_nodes WHERE conninfo LIKE '% host=$CURRENT_REPLICATION_PRIMARY_HOST_ONLY%' LIMIT 1"`
    fi

    if [[ "$REPLICATION_UPSTREAM_NODE_ID" == "" ]]; then
        echo ">>> Can not get REPLICATION_UPSTREAM_NODE_ID from LOCK file or by CURRENT_REPLICATION_PRIMARY_HOST=$CURRENT_REPLICATION_PRIMARY_HOST"
        exit 1
    fi

    echo "upstream_node=$REPLICATION_UPSTREAM_NODE_ID" >> $REPMGR_CONFIG_FILE
fi
chown postgres $REPMGR_CONFIG_FILE