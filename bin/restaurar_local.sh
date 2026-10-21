#!/usr/bin/env bash
#
# Restaura, na maquina LOCAL (desenvolvimento), o backup baixado da producao:
#   - recria o banco "moveisrosa" local a partir do dump
#   - sincroniza a pasta storage/ local com a do backup
#
# ATENCAO: isto APAGA e recria o banco de desenvolvimento local "moveisrosa"
# e sobrescreve a pasta storage/ local. Use quando quer a base de producao aqui.
#
# Uso:
#   bin/restaurar_local.sh                 # usa backups/latest
#   bin/restaurar_local.sh 20260101_120000 # usa um backup especifico
#
# Pre-requisito: ter rodado bin/backup_producao.sh antes.

set -euo pipefail

# ---- Config local (dev) ----
LOCAL_DB="${LOCAL_DB:-moveisrosa}"
LOCAL_USER="${LOCAL_USER:-jonas}"
LOCAL_HOST="${LOCAL_HOST:-localhost}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_ROOT="${ROOT_DIR}/backups"
WHICH="${1:-latest}"
SRC="${BACKUP_ROOT}/${WHICH}"
DUMP="${SRC}/${LOCAL_DB}.dump"

if [ ! -e "${DUMP}" ]; then
  echo "ERRO: dump nao encontrado em ${DUMP}"
  echo "Rode antes: bin/backup_producao.sh (ou informe um timestamp valido)."
  exit 1
fi

echo "==> Restaurar backup '${WHICH}' no banco LOCAL '${LOCAL_DB}'"
echo "    dump: ${DUMP}"
echo "!!  Isto APAGA o banco local '${LOCAL_DB}' e sobrescreve storage/ local."
read -r -p "Confirma? (digite 'sim'): " RESP
if [ "${RESP}" != "sim" ]; then
  echo "Cancelado."
  exit 1
fi

# 1) Encerra conexoes e recria o banco local.
echo "==> [1/3] recriando o banco local..."
psql -U "${LOCAL_USER}" -h "${LOCAL_HOST}" -d postgres -v ON_ERROR_STOP=1 <<SQL
SELECT pg_terminate_backend(pid) FROM pg_stat_activity
 WHERE datname = '${LOCAL_DB}' AND pid <> pg_backend_pid();
DROP DATABASE IF EXISTS ${LOCAL_DB};
CREATE DATABASE ${LOCAL_DB} OWNER ${LOCAL_USER};
SQL

# 2) Restaura o dump (formato custom). --no-owner/--no-privileges para nao
#    exigir os mesmos roles/permissoes da producao no ambiente local.
echo "==> [2/3] restaurando o dump..."
pg_restore --no-owner --no-privileges -U "${LOCAL_USER}" -h "${LOCAL_HOST}" \
  -d "${LOCAL_DB}" "${DUMP}" || echo "(avisos do pg_restore acima sao normais)"

# 3) Sincroniza o storage/ local com o do backup.
echo "==> [3/3] sincronizando storage/ local..."
if [ -d "${SRC}/storage" ]; then
  rsync -a --delete "${SRC}/storage/" "${ROOT_DIR}/storage/"
else
  echo "(backup sem pasta storage/ — pulado)"
fi

echo ""
echo "==> Restauracao concluida. Banco local '${LOCAL_DB}' atualizado da producao."
echo "    Rode as migrations locais se o seu codigo tiver migrations novas:"
echo "      RAILS_ENV=development bundle exec rails db:migrate"
