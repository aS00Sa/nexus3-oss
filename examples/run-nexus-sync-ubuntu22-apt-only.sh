#!/usr/bin/env bash
set -euo pipefail
# Синхронизация только APT proxy Ubuntu 22.04 (jammy) в Nexus + запись вывода в лог.
# Переменные окружения (необязательно):
#   INV   — инвентарь (по умолчанию ../inventory-localdomain.ini)
#   LOG   — путь к логу (по умолчанию ../logs/nexus-sync-ubuntu22-<timestamp>.log)
#   EXTRA — доп. аргументы ansible-playbook, напр. EXTRA='-u root --private-key ~/.ssh/id_ed25519'

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export ANSIBLE_CONFIG="${ANSIBLE_CONFIG:-$ROOT/ansible.cfg}"
INV="${INV:-$ROOT/inventory-localdomain.ini}"
LOGDIR="$ROOT/logs"
mkdir -p "$LOGDIR"
LOG="${LOG:-$LOGDIR/nexus-sync-ubuntu22-$(date +%Y%m%d-%H%M%S).log}"
EXTRA="${EXTRA:-}"

set -x
ansible-playbook -i "$INV" "$ROOT/install.yml" \
  -e @"$ROOT/examples/extra-vars-nexus-sync-ubuntu22-apt-only.yml" \
  $EXTRA \
  -v 2>&1 | tee "$LOG"
set +x
echo "Лог: $LOG"
