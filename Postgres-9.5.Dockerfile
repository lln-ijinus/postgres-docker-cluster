FROM postgres:9.5
ARG POSTGRES_VERSION=9.5

RUN echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && apt-get update --fix-missing && \
		apt-get install -y wget ca-certificates && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && apt-get update && \
    apt-get install -y postgresql-server-dev-$POSTGRES_VERSION postgresql-$POSTGRES_VERSION-repmgr barman-cli rsync
		
# Inherited variables
# ENV POSTGRES_PASSWORD monkey_pass
# ENV POSTGRES_USER monkey_user
# ENV POSTGRES_DB monkey_db

ENV CLUSTER_NAME=pg_cluster \
	## special repmgr db for cluster info
	REPLICATION_DB=replication_db \
	REPLICATION_USER=replication_user \
	REPLICATION_PASSWORD=replication_pass \
	REPLICATION_PRIMARY_PORT=5432 \
	## Host for replication (REQUIRED, NO DEFAULT)
	# REPLICATION_PRIMARY_HOST
	## Integer number of node (REQUIRED, NO DEFAULT)
	# NODE_ID=1
	## Node name (REQUIRED, NO DEFAULT)
	# NODE_NAME=node1
	## (default: `hostname` of the node)
	# CLUSTER_NODE_NETWORK_NAME=null
	NODE_PRIORITY=100 \
	PARTNER_NODES="" \
  ## in format variable1:value1[,variable2:value2[,...]]
  ## used for pgpool.conf file
	# CONFIGS=listen_addresses:'*'
  ## File will be put in $MASTER_ROLE_LOCK_FILE_NAME when:
  ##    - node starts as a primary node/master
  ##    - node promoted to a primary node/master
  ## File does not exist
  ##    - if node starts as a standby
	MASTER_ROLE_LOCK_FILE_NAME=$PGDATA/master.lock \
  ## File will be put in $STANDBY_ROLE_LOCK_FILE_NAME when:
  ##    - event repmgrd_failover_follow happened
  ## contains upstream NODE_ID
  ## that basically used when standby changes upstream node set by default
	STANDBY_ROLE_LOCK_FILE_NAME=$PGDATA/standby.lock \
	## For how long in seconds repmgr will wait for postgres start on current node
  ## Should be big enough to perform replication clone
	REPMGR_WAIT_POSTGRES_START_TIMEOUT=300 \
	#### Advanced options ####
	REPMGR_PID_FILE=/tmp/repmgrd.pid \
	WAIT_SYSTEM_IS_STARTING=5 \
	STOPPING_LOCK_FILE=/tmp/stop.pid \
	STOPPING_TIMEOUT=15 \
	CONNECT_TIMEOUT=2 \
	RECONNECT_ATTEMPTS=3 \
	RECONNECT_INTERVAL=5 \
	MASTER_RESPONSE_TIMEOUT=20 \
	LOG_LEVEL=INFO \
	# Clean $PGDATA directory before start
	FORCE_CLEAN=0 \
	CHECK_PGCONNECT_TIMEOUT=10 \
	## never clean $PGDATA directory (exit with a message)
	NEVER_CLEAN=0 \
	## Set to 1 to create replication user and db on an existing database
	## - Do it if it is a master db, can connect to the database but not to the replication db
	## - Also update postgresql config
	## - For update from a simple postgres docker image
	UPDATE_EXISTING_DB=0 \
	#### Barman configuration ####
	## barman server name
	BARMAN_SERVER="" \
	BARMAN_SSH_PORT=22 \
	BARMAN_USE_REPLICATION_SLOTS=1 \
	BARMAN_USE_RSYNC=0 \
	BARMAN_INCOMING_WALS_DIRECTORY="" \
	BARMAN_SSH_PUB_PATH=/etc/pg_cluster.pub \
	BARMAN_SSH_PRIV_PATH=/etc/pg_cluster.key 
	



COPY ./pgsql/bin /usr/local/bin/cluster
RUN chmod -R +x /usr/local/bin/cluster ; ln -s /usr/local/bin/cluster/functions/* /usr/local/bin/
COPY ./pgsql/configs /var/cluster_configs

EXPOSE 5432

VOLUME /var/lib/postgresql/data
USER root

CMD ["/usr/local/bin/cluster/entrypoint.sh"]