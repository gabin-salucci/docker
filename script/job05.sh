#!/usr/bin/env bash
set -Eeuo pipefail

BASHRC="${HOME}/.bashrc"
MARKER="# Aliases Docker - job 05"

if ! touch "$BASHRC" 2>/dev/null; then
    echo "Impossible d'écrire dans $BASHRC" >&2
    exit 1
fi

if grep -Fq "$MARKER" "$BASHRC"; then
    echo "Les alias du job 05 sont déjà présents dans $BASHRC."
    exit 0
fi

cat >> "$BASHRC" <<'ALIASES'

# Aliases Docker - job 05
alias d='docker'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias dimg='docker image ls'
alias dvol='docker volume ls'
alias dnet='docker network ls'
alias dlog='docker logs'
alias dexec='docker exec -it'
alias dstop='docker stop'
alias drm='docker rm'
alias drmi='docker image rm'
alias dprune='docker system prune'
ALIASES

echo "Alias ajoutés dans $BASHRC"
echo "Pour les charger dans ce terminal : source ~/.bashrc"
echo "Exemple : dpsa ; dimg ; dexec nom_du_conteneur bash"