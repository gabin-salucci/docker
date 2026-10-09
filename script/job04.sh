#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE_NAME="job04-ssh"
CONTAINER_NAME="job04-ssh"
HOST_PORT="${HOST_PORT:-2222}"
BUILD_DIR="${HOME}/docker-jobs/script/job04"

mkdir -p "$BUILD_DIR"

cat > "${BUILD_DIR}/Dockerfile" <<'DOCKERFILE'
FROM debian:stable-slim

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends openssh-server \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd \
    && echo 'root:root123' | chpasswd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

EXPOSE 22
CMD ["/usr/sbin/sshd", "-D", "-e"]
DOCKERFILE

echo "=== Job 04 : construction de l'image SSH ==="
docker build -t "$IMAGE_NAME" "$BUILD_DIR"

# Supprime l'ancien conteneur de ce job, s'il existe.
if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo "Suppression de l'ancien conteneur $CONTAINER_NAME."
    docker rm -f "$CONTAINER_NAME"
fi

echo
echo "=== Création et lancement du conteneur ==="
docker run -d \
    --name "$CONTAINER_NAME" \
    -p "${HOST_PORT}:22" \
    "$IMAGE_NAME"

echo
echo "=== Vérifications ==="
docker ps --filter "name=^/${CONTAINER_NAME}$"
docker port "$CONTAINER_NAME"

if ! docker exec "$CONTAINER_NAME" sshd -t; then
    echo "ERREUR : la configuration SSH du conteneur est invalide."
    exit 1
fi

echo
echo "OK : le serveur SSH est lancé."
echo "Depuis la VM : ssh -p ${HOST_PORT} root@127.0.0.1"
echo "Depuis Arch :  ssh -p ${HOST_PORT} root@IP_DE_LA_VM"
echo "Mot de passe du labo : root123"