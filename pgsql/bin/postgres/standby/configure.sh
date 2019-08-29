#!/usr/bin/env bash

CONFIG_FILE=$PGDATA/postgresql.conf

HAS_LOCAL_CONF=`grep '/etc/postgresql/local.conf' $CONFIG_FILE`
if [[ "$HAS_LOCAL_CONF" == "" ]]; then
	echo ">>> Add local conf to $CONFIG_FILE"
	echo "include_if_exists = '/etc/postgresql/local.conf'" >> $CONFIG_FILE
fi

echo "port=$REPLICATION_PRIMARY_PORT" > /etc/postgresql/local.conf
IFS=',' read -ra CONFIG_PAIRS <<< "$LOCAL_CONFIGS"
for CONFIG_PAIR in "${CONFIG_PAIRS[@]}"
do
    IFS=':' read -ra CONFIG <<< "$CONFIG_PAIR"
    VAR="${CONFIG[0]}"
    VAL="${CONFIG[1]}"
    echo ">>>>>> Adding local config '$VAR'='$VAL' "
    echo "$VAR = $VAL" >> /etc/postgresql/local.conf
done
