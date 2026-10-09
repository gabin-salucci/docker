#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE_NAME="job03-helloworld"
BUILD_DIR="${HOME}/docker-jobs/script/job03"

mkdir -p "$BUILD_DIR"

cat > "${BUILD_DIR}/Dockerfile" <<'DOCKERFILE'
FROM debian:stable-slim
CMD ["sh", "-c", "echo 'Hello World depuis mon image Debian personnalisée !'"]
DOCKERFILE

echo "=== Job 03 : construction de l'image ==="
echo "Répertoire : $BUILD_DIR"
echo "\$ docker build -t $IMAGE_NAME $BUILD_DIR"
docker build -t "$IMAGE_NAME" "$BUILD_DIR"

echo
echo "=== Exécution et vérification ==="
echo "\$ docker run --rm $IMAGE_NAME"
docker run --rm "$IMAGE_NAME"

echo
echo "Vérification : docker image inspect $IMAGE_NAME"
docker image inspect "$IMAGE_NAME" --format \
    'OK : image {{.RepoTags}} créée, basée sur {{.Os}}/{{.Architecture}}.'