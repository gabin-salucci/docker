#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE_NAME="job08-nginx"
CONTAINER_NAME="job08-nginx"
HOST_PORT="${HOST_PORT:-8081}"
BUILD_DIR="${HOME}/docker-jobs/script/job08"

mkdir -p "${BUILD_DIR}/html"

cat > "${BUILD_DIR}/Dockerfile" <<'DOCKERFILE'
FROM debian:stable-slim

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends nginx \
    && rm -rf /var/lib/apt/lists/*

COPY html/ /var/www/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
DOCKERFILE

cat > "${BUILD_DIR}/html/index.html" <<'HTML'
<!doctype html>
<html lang="fr">
  <head><meta charset="utf-8"><title>Job 08</title></head>
  <body><h1>Nginx construit depuis une image Debian</h1></body>
</html>
HTML

echo "Construction de l'image..."
docker build -t "$IMAGE_NAME" "$BUILD_DIR"

if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    echo "Suppression de l'ancien conteneur $CONTAINER_NAME."
    docker rm -f "$CONTAINER_NAME"
fi

docker run -d \
    --name "$CONTAINER_NAME" \
    -p "${HOST_PORT}:80" \
    "$IMAGE_NAME"

echo
docker ps --filter "name=^/${CONTAINER_NAME}$"
echo
echo "Test HTTP :"
curl --fail --silent --show-error "http://127.0.0.1:${HOST_PORT}/"
echo
echo "OK : ouvre http://IP_DE_LA_VM:${HOST_PORT}/ depuis ton PC."