#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Exécute ce script avec sudo : sudo $0" >&2
  exit 1
fi

if [[ ! -r /etc/os-release ]]; then
  echo "Impossible d'identifier la distribution (/etc/os-release introuvable)." >&2
  exit 1
fi

. /etc/os-release

if [[ "${ID:-}" != "debian" ]]; then
  echo "Ce script est prévu pour Debian. Distribution détectée : ${PRETTY_NAME:-inconnue}" >&2
  exit 1
fi

case "${VERSION_CODENAME:-}" in
  bookworm|trixie) ;;
  *)
    echo "Version Debian non prise en charge par ce script : ${VERSION_CODENAME:-inconnue}" >&2
    echo "Versions prévues : Bookworm 12 et Trixie 13." >&2
    exit 1
    ;;
esac

apt-get update
apt-get install -y ca-certificates curl

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

architecture="$(dpkg --print-architecture)"

cat > /etc/apt/sources.list.d/docker.sources <<REPO
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: ${VERSION_CODENAME}
Components: stable
Architectures: ${architecture}
Signed-By: /etc/apt/keyrings/docker.asc
REPO

apt-get update
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

systemctl enable --now docker

echo
echo "Installation terminée."
docker --version
docker compose version
docker run --rm hello-world


chmod +x installer-docker.sh
sudo ./installer-docker.sh