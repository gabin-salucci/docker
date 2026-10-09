#!/usr/bin/env bash
set -Eeuo pipefail

VOLUME="job06-partage"
CONTENEUR1="job06-a"
CONTENEUR2="job06-b"

if ! docker info >/dev/null 2>&1; then
    echo "Docker ne répond pas. Essaie : sudo systemctl start docker" >&2
    exit 1
fi

docker volume create "$VOLUME" >/dev/null

# Écrit un fichier dans le volume depuis le premier conteneur.
docker run --rm \
    --mount "type=volume,src=${VOLUME},dst=/partage" \
    debian:stable-slim \
    sh -c 'echo "Fichier créé par le conteneur A" > /partage/message.txt'

# Lit le même fichier depuis le second conteneur.
RESULTAT="$(
    docker run --rm \
        --mount "type=volume,src=${VOLUME},dst=/partage,readonly" \
        debian:stable-slim \
        cat /partage/message.txt
)"

echo "Lecture depuis le conteneur B :"
echo "$RESULTAT"

if [[ "$RESULTAT" != "Fichier créé par le conteneur A" ]]; then
    echo "ERREUR : contenu inattendu dans le volume." >&2
    exit 1
fi

echo
echo "Volume utilisé :"
docker volume inspect "$VOLUME" --format 'Nom : {{.Name}} | Point de montage : {{.Mountpoint}}'
echo
echo "OK : les deux conteneurs accèdent au même volume."
echo "Le volume est conservé après la suppression des conteneurs."
echo "Pour le supprimer plus tard : docker volume rm $VOLUME"