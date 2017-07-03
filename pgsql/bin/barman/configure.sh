#!/bin/bash
mkdir /home/postgres
chown postgres /home/postgres/

if [[ "$BARMAN_SERVER" != "" ]] && [[ -e "$BARMAN_SSH_PRIV_PATH" ]]; then
	cp $BARMAN_SSH_PRIV_PATH /home/postgres/.ssh/id_rsa
fi
if [[ -e "$BARMAN_SSH_PUB_PATH" ]]; then
	cat  $BARMAN_SSH_PUB_PATH >> /home/postgres/.ssh/authorized_keys
	if [[ "$BARMAN_SERVER" != "" ]]; then
		ssh-keygen -R $BARMAN_SERVER
		ssh-keyscan -H $BARMAN_SERVER >> /home/postgres/.ssh/known_hosts
	fi
fi
chmod 0600 /home/postgres/.ssh/* && chown postgres /home/postgres/.ssh/*
#gosu postgres ssh-keygen -t rsa -N "" -f /home/postgres/.ssh/id_rsa

## Créer une clé privée / publique qui servira pour tous les serveurs, mettre la clé publique dans le .ssh/authorized_keys de l'utilisateur barman pour barman et de l'utilisateur postgres pour les base de données
## mettre la clé privée dans .ssh/id_rsa ou utiliser l'option -i au ssh pour lui fournir la clé privée
## Voir pour les known_hosts automatique ! : ssh -o StrictHostKeyChecking=no