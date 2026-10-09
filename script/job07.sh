#!/usr/bin/env bash
set -Eeuo pipefail

# Adresse de la VM Debian, joignable depuis le PC où tourne FileZilla.
FTP_PUBLICHOST="${1:-}"

if [[ -z "$FTP_PUBLICHOST" ]]; then
    echo "Usage : $0 IP_DE_LA_VM"
    echo "Exemple : $0 192.168.1.50"
    exit 2
fi

if ! docker compose version >/dev/null 2>&1; then
    echo "Docker Compose plugin introuvable. Installe docker-compose-plugin." >&2
    exit 1
fi

PROJECT_DIR="${HOME}/docker-jobs/script/job07"
WEB_DIR="${PROJECT_DIR}/web"
mkdir -p "$WEB_DIR"

cat > "${PROJECT_DIR}/compose.yaml" <<'YAML'
services:
  nginx:
    image: nginx:alpine
    container_name: job07-nginx
    ports:
      - "8080:80"
    volumes:
      - ./web:/usr/share/nginx/html:ro
    restart: unless-stopped

  ftp:
    image: stilliard/pure-ftpd:latest
    container_name: job07-ftp
    environment:
      FTP_USER_NAME: eleve
      FTP_USER_PASS: changer-ce-mot-de-passe
      FTP_USER_HOME: /home/eleve
      PUBLICHOST: ${FTP_PUBLICHOST}
      FTP_PASSIVE_PORTS: 30000:30009
    ports:
      - "2121:21"
      - "30000-30009:30000-30009"
    volumes:
      - ./web:/home/eleve
    restart: unless-stopped
YAML

cat > "${PROJECT_DIR}/.env" <<EOF
FTP_PUBLICHOST=${FTP_PUBLICHOST}
EOF

echo "Fichiers du projet : $PROJECT_DIR"
echo "Démarrage des services..."
cd "$PROJECT_DIR"
docker compose up -d

echo
docker compose ps
echo
echo "Depuis FileZilla, connexion FTP :"
echo "Hôte : $FTP_PUBLICHOST | Port : 2121 | Utilisateur : eleve"
echo "Mot de passe : changer-ce-mot-de-passe"
echo "Mode de transfert : passif"
echo
echo "Après avoir envoyé index.html, vérifier dans un navigateur :"
echo "http://IP_DE_LA_VM:8080/"
echo
echo "Le site est servi depuis : $WEB_DIR"
echo "Remplace le mot de passe de démonstration avant toute utilisation hors laboratoire."