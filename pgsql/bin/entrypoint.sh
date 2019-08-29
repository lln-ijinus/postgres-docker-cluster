#!/usr/bin/env bash
set -e

echo ">>> Setting up STOP handlers..."
for f in TERM SIGTERM QUIT SIGQUIT INT SIGINT KILL SIGKILL; do
    trap "system_stop $f" "$f"
done

echo '>>> STARTING POSTGRES...'
/usr/local/bin/cluster/postgres/entrypoint.sh & wait ${!} || echo ">>> Foreground processes returned code: '$?'"
[[ "$TEST" == "1" ]] && sleep 86400
system_exit