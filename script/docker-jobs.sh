#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="${HOME}/docker-jobs"
FTP_IMAGE="stilliard/pure-ftpd"
REGISTRY_UI_IMAGE="joxit/docker-registry-ui:latest"

say()  { printf '\n%s\n' "$*"; }
fail() { printf 'ERREUR : %s\n' "$*" >&2; exit 1; }

confirm() {
    local answer
    read -r -p "$1 [o/N] " answer
    [[ "$answer" =~ ^[OoYy]$ ]]
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || fail "Commande requise introuvable : $1"
}

get_ips() {
    if command -v ip >/dev/null 2>&1; then
        ip -o -4 addr show scope global | awk '{split($4,a,"/"); print a[1]}'
    fi
}

choose_ip() {
    local ips=()
    mapfile -t ips < <(get_ips)

    if ((${#ips[@]} == 0)); then
        read -r -p "IP de la VM à utiliser : " LAB_IP
    elif ((${#ips[@]} == 1)); then
        LAB_IP="${ips[0]}"
        say "IP détectée : $LAB_IP"
    else
        say "Adresses IPv4 détectées :"
        local i
        for i in "${!ips[@]}"; do
            printf '  %d) %s\n' "$((i + 1))" "${ips[$i]}"
        done
        read -r -p "Choisis le numéro de l’interface du labo : " choice
        [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#ips[@]})) \
            || fail "Choix d’IP invalide."
        LAB_IP="${ips[$((choice - 1))]}"
    fi
}

init_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        fail "Docker n'est pas installé. Lance d'abord le job 10 > Installer Docker."
    fi

    if docker info >/dev/null 2>&1; then
        DOCKER=(docker)
    elif command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
        DOCKER=(sudo docker)
    else
        fail "Docker est installé, mais le démon n'est pas accessible. Vérifie le service et les permissions."
    fi

    mkdir -p "$BASE_DIR"
}

compose() {
    if docker compose version >/dev/null 2>&1; then
        docker compose "$@"
    elif sudo docker compose version >/dev/null 2>&1; then
        sudo docker compose "$@"
    else
        fail "Le plugin Docker Compose n'est pas disponible."
    fi
}

job02() {
    init_docker
    say "Test de Docker avec hello-world"
    "${DOCKER[@]}" run --rm hello-world
    say "Commandes utiles :"
    "${DOCKER[@]}" ps -a
    "${DOCKER[@]}" images
}

job03() {
    init_docker
    local dir="$BASE_DIR/job03"
    mkdir -p "$dir"

    cat > "$dir/Dockerfile" <<'EOF'
FROM debian:bookworm-slim
CMD ["sh", "-c", "echo 'Hello world depuis une image Debian minimale'"]
EOF

    "${DOCKER[@]}" build -t job03-helloworld "$dir"
    "${DOCKER[@]}" run --rm --name job03-helloworld job03-helloworld
}

job04() {
    init_docker
    local dir="$BASE_DIR/job04"
    mkdir -p "$dir"

    cat > "$dir/Dockerfile" <<'EOF'
FROM debian:bookworm-slim
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends openssh-server \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /run/sshd \
 && echo 'root:root123' | chpasswd \
 && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
 && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D", "-e"]
EOF

    "${DOCKER[@]}" build -t job04-ssh "$dir"
    "${DOCKER[@]}" rm -f job04-ssh >/dev/null 2>&1 || true
    "${DOCKER[@]}" run -d --name job04-ssh -p 2222:22 job04-ssh
    choose_ip
    say "Connexion depuis le PC : ssh -p 2222 root@$LAB_IP"
    say "Mot de passe du labo : root123"
}

job05() {
    local rc="$HOME/.bashrc"
    local marker="# Aliases Docker - ajoutés par docker-jobs.sh"

    if grep -Fq "$marker" "$rc" 2>/dev/null; then
        say "Les alias Docker sont déjà présents dans $rc."
        return
    fi

    cat >> "$rc" <<'EOF'

# Aliases Docker - ajoutés par docker-jobs.sh
alias d='docker'
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias drm='docker rm'
alias drmi='docker rmi'
alias dlogs='docker logs'
alias dexec='docker exec -it'
alias dstop='docker stop'
alias dstart='docker start'
EOF

    say "Alias ajoutés à $rc. Recharge-les avec : source ~/.bashrc"
}

job06() {
    init_docker
    "${DOCKER[@]}" volume create partage-job06 >/dev/null
    "${DOCKER[@]}" run --rm \
        --mount source=partage-job06,target=/partage \
        debian:bookworm-slim \
        sh -c 'echo "Fichier écrit par le premier conteneur" > /partage/test.txt'
    "${DOCKER[@]}" run --rm \
        --mount source=partage-job06,target=/partage,readonly \
        debian:bookworm-slim \
        cat /partage/test.txt

    say "Gestion du volume :"
    say "  docker volume ls"
    say "  docker volume inspect partage-job06"
    say "  docker volume rm partage-job06  # supprime le volume et ses données"
}

job07() {
    init_docker
    choose_ip

    local dir="$BASE_DIR/job07"
    mkdir -p "$dir/site"

    read -r -p "Nom et prénom à afficher dans index.html : " fullname
    [[ -n "$fullname" ]] || fail "Le nom/prénom ne peut pas être vide."

    printf '<!doctype html><html lang="fr"><meta charset="utf-8"><title>Job 07</title><body><h1>%s</h1></body></html>\n' \
        "$fullname" > "$dir/site/index.html"

    cat > "$dir/compose.yaml" <<EOF
services:
  nginx:
    image: nginx:alpine
    container_name: job07-nginx
    ports:
      - "8080:80"
    volumes:
      - ./site:/usr/share/nginx/html:ro
    depends_on:
      - ftp

  ftp:
    image: ${FTP_IMAGE}
    container_name: job07-ftp
    environment:
      PUBLICHOST: "${LAB_IP}"
      FTP_USER_NAME: "student"
      FTP_USER_PASS: "student123"
      FTP_USER_HOME: "/home/student"
      FTP_USER_UID: "1000"
      FTP_USER_GID: "1000"
    ports:
      - "2121:21"
      - "30000-30009:30000-30009"
    volumes:
      - ./site:/home/student
EOF

    compose -f "$dir/compose.yaml" up -d
    say "Nginx : http://$LAB_IP:8080"
    say "FileZilla : hôte $LAB_IP, port 2121, utilisateur student, mot de passe student123"
    say "Mode FTP : passif. Plage de ports : 30000-30009."
    say "Le dossier partagé est : $dir/site"
}

job08() {
    init_docker
    local dir="$BASE_DIR/job08"
    mkdir -p "$dir/html"

    cat > "$dir/Dockerfile" <<'EOF'
FROM debian:bookworm-slim
RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends nginx \
 && rm -rf /var/lib/apt/lists/*
COPY html/ /var/www/html/
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF

    cat > "$dir/html/index.html" <<'EOF'
<!doctype html>
<html lang="fr"><meta charset="utf-8">
<title>Job 08</title>
<h1>Nginx construit depuis un Dockerfile Debian</h1>
EOF

    "${DOCKER[@]}" build -t job08-nginx "$dir"
    "${DOCKER[@]}" rm -f job08-nginx >/dev/null 2>&1 || true
    "${DOCKER[@]}" run -d --name job08-nginx -p 8081:80 job08-nginx
    choose_ip
    say "Ouvre http://$LAB_IP:8081"
}

job09() {
    init_docker
    choose_ip

    local dir="$BASE_DIR/job09"
    mkdir -p "$dir"

    cat > "$dir/compose.yaml" <<EOF
services:
  registry:
    image: registry:2
    container_name: job09-registry
    ports:
      - "5000:5000"
    environment:
      REGISTRY_STORAGE_DELETE_ENABLED: "false"
    volumes:
      - registry-data:/var/lib/registry

  ui:
    image: ${REGISTRY_UI_IMAGE}
    container_name: job09-registry-ui
    ports:
      - "8082:80"
    environment:
      SINGLE_REGISTRY: "true"
      REGISTRY_TITLE: "Registry local du labo"
      DELETE_IMAGES: "false"
      SHOW_CONTENT_DIGEST: "true"
      NGINX_PROXY_PASS_URL: "http://registry:5000"
      REGISTRY_URL: "http://${LAB_IP}:5000"
    depends_on:
      - registry

volumes:
  registry-data:
EOF

    compose -f "$dir/compose.yaml" up -d
    say "Interface web : http://$LAB_IP:8082"
    say "API du registry : http://$LAB_IP:5000/v2/"
    say "Exemple d’envoi d’image :"
    say "  docker pull hello-world"
    say "  docker tag hello-world $LAB_IP:5000/hello-world"
    say "  docker push $LAB_IP:5000/hello-world"
    say "Sur le client Docker, un registry HTTP peut nécessiter la configuration insecure-registries."
}

install_docker() {
    [[ -r /etc/os-release ]] || fail "Impossible d'identifier la distribution."
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ "${ID:-}" == "debian" ]] || fail "Ce script d'installation cible Debian, pas ${ID:-inconnue}."

    command -v sudo >/dev/null 2>&1 || fail "sudo est requis pour l'installation."
    sudo -v

    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg \
        -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    local codename arch
    codename="${VERSION_CODENAME:-}"
    arch="$(dpkg --print-architecture)"
    [[ -n "$codename" ]] || fail "VERSION_CODENAME absent ; vérifie la version Debian."

    printf 'Types: deb\nURIs: https://download.docker.com/linux/debian\nSuites: %s\nComponents: stable\nArchitectures: %s\nSigned-By: /etc/apt/keyrings/docker.asc\n' \
        "$codename" "$arch" | sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null

    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo systemctl enable --now docker
    sudo docker run --rm hello-world
}

uninstall_docker() {
    cat <<'EOF'
ATTENTION : cette opération supprime les conteneurs, images, volumes,
réseaux Docker et les données associées sur cette machine.
Elle peut supprimer des données irrécupérables.
EOF
    read -r -p "Pour confirmer, tape exactement REMOVE-DOCKER-DATA : " answer
    [[ "$answer" == "REMOVE-DOCKER-DATA" ]] || { say "Annulé."; return; }

    command -v sudo >/dev/null 2>&1 || fail "sudo est requis."
    sudo -v
    sudo systemctl stop docker docker.socket containerd 2>/dev/null || true

    sudo apt-get purge -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin docker.io docker-compose \
        docker-doc podman-docker 2>/dev/null || true
    sudo apt-get autoremove -y

    # Suppression définitive des données locales Docker.
    sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker
    say "Nettoyage Docker terminé."
}

run_job() {
    local job="$1"
    case "$job" in
        job02) job02 ;;
        job03) job03 ;;
        job04) job04 ;;
        job05) job05 ;;
        job06) job06 ;;
        job07) job07 ;;
        job08) job08 ;;
        job09) job09 ;;
        job10-install) install_docker ;;
        job10-clean) uninstall_docker ;;
        *) fail "Job inconnu : $job" ;;
    esac
}

while true; do
    cat <<'EOF'

========== Menu Docker ==========
  job02       Tester Docker / commandes de base
  job03       Image hello-world construite depuis Debian
  job04       Image SSH et redirection de port
  job05       Ajouter des alias Docker à ~/.bashrc
  job06       Volume partagé entre deux conteneurs
  job07       Nginx + FTP + volume web partagé
  job08       Nginx construit depuis un Dockerfile Debian
  job09       Registry local + interface web
  job10       Installation ou suppression complète de Docker
  quitter     Quitter
EOF

    read -r -p "Ton choix : " selection
    case "$selection" in
        quitter|q|Q) exit 0 ;;
        job10)
            printf '\n  1) Installer Docker sur Debian\n  2) Supprimer Docker et toutes ses données\n'
            read -r -p "Choisis 1 ou 2 : " subchoice
            case "$subchoice" in
                1) run_job job10-install ;;
                2) run_job job10-clean ;;
                *) say "Choix invalide." ;;
            esac
            ;;
        job02|job03|job04|job05|job06|job07|job08|job09)
            if confirm "Lancer $selection ?"; then
                run_job "$selection"
            else
                say "Annulé."
            fi
            ;;
        *) say "Choix inconnu." ;;
    esac
done