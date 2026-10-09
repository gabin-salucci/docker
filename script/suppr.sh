#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Exécute ce script avec sudo : sudo $0" >&2
  exit 1
fi
read -r -p 'Pour confirmer, tape exactement SUPPRIMER DOCKER : ' confirmation

if [[ "$confirmation" != "SUPPRIMER DOCKER" ]]; then
  echo "Confirmation incorrecte. Aucune modification effectuée."
  exit 1
fi

echo "Arrêt des services Docker..."
systemctl stop docker.service docker.socket containerd.service 2>/dev/null || true

paquets=(
  docker-ce
  docker-ce-cli
  docker-ce-rootless-extras
  docker.io
  docker-compose
  docker-compose-v2
  docker-doc
  docker-buildx-plugin
  docker-compose-plugin
  podman-docker
  containerd
  containerd.io
  runc
)

paquets_installes=()
for paquet in "${paquets[@]}"; do
  if dpkg-query -W -f='${db:Status-Status}' "$paquet" 2>/dev/null | grep -qx installed; then
    paquets_installes+=("$paquet")
  fi
done

if (("\${#paquets_installes[@]}" > 0)); then
  echo "Suppression des paquets : \${paquets_installes[*]}"
  apt-get purge -y "\${paquets_installes[@]}"
else
  echo "Aucun paquet Docker correspondant trouvé."
fi

apt-get autoremove --purge -y

echo "Suppression des données et configurations Docker..."
rm -rf /var/lib/docker
rm -rf /var/lib/containerd
rm -rf /etc/docker
rm -f /etc/apt/sources.list.d/docker.list
rm -f /etc/apt/sources.list.d/docker.sources
rm -f /etc/apt/keyrings/docker.asc
rm -f /usr/share/keyrings/docker-archive-keyring.gpg

echo "Nettoyage de la liste des paquets..."
apt-get update

echo "Suppression terminée. Vérifie les éventuels paquets résiduels avec :"
echo "  dpkg -l | grep -E 'docker|containerd|runc'"
EOF

chmod +x supprimer-docker.sh
sudo ./supprimer-docker.sh