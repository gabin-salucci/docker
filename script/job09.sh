#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="${HOME}/docker-jobs/script/job09"
mkdir -p "${PROJECT_DIR}/data"

cat > "${PROJECT_DIR}/compose.yaml" <<'YAML'
services:
  registry:
    image: registry:2
    container_name: job09-registry
    environment:
      REGISTRY_STORAGE_DELETE_ENABLED: "true"
    volumes:
      - ./data:/var/lib/registry
    ports:
      - "5000:5000"
    restart: unless-stopped

  registry-ui:
    image: joxit/docker-registry-ui:main
    container_name: job09-registry-ui
    depends_on:
      - registry
    environment:
      SINGLE_REGISTRY: "true"
      REGISTRY_TITLE: "Registry local"
      NGINX_PROXY_PASS_URL: "http://registry:5000"
      DELETE_IMAGES: "true"
      SHOW_CONTENT_DIGEST: "true"
    ports:
      - "8082:80"
    restart: unless-stopped
YAML

cd "$PROJECT_DIR"
docker compose up -d

echo "Services :"
docker compose ps
echo
echo "Interface web : http://IP_DE_LA_VM:8082/"
echo "API du registry : http://IP_DE_LA_VM:5000/v2/"
echo
echo "Test :"
curl --fail --silent --show-error http://127.0.0.1:5000/v2/
echo
echo "Pour pousser une image de test :"
echo "docker pull hello-world"
echo "docker tag hello-world localhost:5000/hello-world:test"
echo "docker push localhost:5000/hello-world:test"