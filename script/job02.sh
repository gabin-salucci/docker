#!/usr/bin/env bash
set -Eeuo pipefail

echo "=== Job 02 : test de Docker avec hello-world ==="

if ! command -v docker >/dev/null 2>&1; then
    echo "ERREUR : Docker n'est pas installé ou absent du PATH."
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    echo "ERREUR : le daemon Docker ne répond pas."
    echo "Essaie : sudo systemctl start docker"
    echo "Puis relance ce script avec sudo si nécessaire."
    exit 1
fi

echo "\$ docker run --rm hello-world"
docker run --rm hello-world

echo
echo "Vérification : docker --version"
docker --version

echo
echo "OK : Docker a exécuté le conteneur hello-world."