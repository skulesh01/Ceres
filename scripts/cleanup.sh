#!/bin/bash
# Cleanup script for CERES Docker runtime (Linux/macOS)
#
# Goals:
# - Bring down CERES stack cleanly (no data loss).
# - Optionally remove known stale/conflicting containers from previous runs.
#
# By default this script does NOT delete volumes.

set -euo pipefail

project_name="ceres"
clean=false
remove_known_conflicts=false
prune_networks=false
modules=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-name)
      project_name="$2"; shift 2 ;;
    --clean)
      clean=true; shift ;;
    --remove-known-conflicts)
      remove_known_conflicts=true; shift ;;
    --prune-networks)
      prune_networks=true; shift ;;
    *)
      modules+=("$1"); shift ;;
  esac
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${script_dir}/../config"
cd "${config_dir}"

if ! docker version 2>/dev/null | grep -q "Server:"; then
  echo "Docker daemon is not available. Start Docker and retry." >&2
  exit 1
fi

compose_args=("--project-name" "${project_name}")

if [[ "${clean}" == true ]]; then
  compose_files=("-f" "docker-compose-CLEAN.yml")
else
  declare -A map=(
    [core]="compose/core.yml"
    [apps]="compose/apps.yml"
    [monitoring]="compose/monitoring.yml"
    [ops]="compose/ops.yml"
    [edge]="compose/edge.yml"
  )

  if [[ ${#modules[@]} -eq 0 ]]; then
    modules=(core apps monitoring ops edge)
  fi

  compose_files=()
  for m in "${modules[@]}"; do
    key="${m,,}"
    if [[ -z "${map[$key]+x}" ]]; then
      echo "Unknown module '$m'. Allowed: core, apps, monitoring, ops, edge. Or use --clean." >&2
      exit 1
    fi
    compose_files+=("-f" "${map[$key]}")
  done
fi

echo "Bringing down CERES project '${project_name}'..."
docker compose "${compose_args[@]}" "${compose_files[@]}" down --remove-orphans >/dev/null

if [[ "${remove_known_conflicts}" == true ]]; then
  echo "Removing known stale containers from older runs..."

  known_names=(postgres redis keycloak nextcloud gitea mattermost grafana prometheus portainer nginx traefik vaultwarden syncthing node-exporter cadvisor alertmanager)
  known_prefixes=(
    "postgres:" "redis:" "quay.io/keycloak/keycloak:" "nextcloud:" "gitea/gitea:"
    "mattermost/mattermost-team-edition:" "grafana/grafana:" "prom/prometheus:"
    "portainer/portainer-ce:" "nginx:" "traefik:" "vaultwarden/server:" "linuxserver/syncthing:"
    "prom/node-exporter:" "gcr.io/cadvisor/cadvisor:" "prom/alertmanager:"
  )

  while read -r id name; do
    [[ -z "${id}" || -z "${name}" ]] && continue

    match_name=false
    for n in "${known_names[@]}"; do
      [[ "${name}" == "${n}" ]] && match_name=true && break
    done
    match_legacy=false
    [[ "${name}" == ceres-* ]] && match_legacy=true
    [[ "${match_name}" == false && "${match_legacy}" == false ]] && continue

    proj=$(docker inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}' "$id" 2>/dev/null || true)
    [[ "${proj}" == "${project_name}" ]] && continue

    img=$(docker inspect -f '{{ .Config.Image }}' "$id" 2>/dev/null || true)
    [[ -z "${img}" ]] && continue

    match_img=false
    for p in "${known_prefixes[@]}"; do
      [[ "${img}" == ${p}* ]] && match_img=true && break
    done
    [[ "${match_img}" == false ]] && continue

    echo "Removing stale container '${name}' (${img})"
    docker rm -f "$id" >/dev/null || true
  done < <(docker ps -a --format '{{.ID}} {{.Names}}')
fi

if [[ "${prune_networks}" == true ]]; then
  echo "Pruning unused networks..."
  docker network prune -f >/dev/null
fi

echo "Done."
