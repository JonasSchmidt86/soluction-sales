#!/usr/bin/env bash
#
# Backup COMPLETO da producao (Hostinger) para a maquina local:
#   - dump do banco PostgreSQL "moveisrosa" (formato custom, comprimido)
#   - pasta storage/ (imagens IMG/Produtos, XMLs, pacotes)
#
# Baixa tudo para ./backups/<timestamp>/ e atualiza ./backups/latest ->
# apontando para o backup mais recente (usado pelo restaurar_local.sh).
#
# Pre-requisitos:
#   - acesso SSH por chave: ssh root@85.31.231.205 (sem senha)
#   - pg_dump/psql no servidor (ja instalados: PG 16)
#
# Uso:
#   bin/backup_producao.sh
#
# Ordem recomendada do fluxo (deploy -> backup -> restore):
#   1) git push + deploy em producao (migrations rodam la)
#   2) bin/backup_producao.sh        (baixa a base ja migrada)
#   3) bin/restaurar_local.sh        (restaura localmente)

set -euo pipefail

# ---- Carrega segredos de um arquivo LOCAL fora do git (se existir) ----
# Crie bin/.env.backup (ignorado pelo git) com, por exemplo:
#   PG_PASSWORD=suaSenhaDoPostgres
ENV_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.env.backup"
# shellcheck disable=SC1090
[ -f "${ENV_FILE}" ] && . "${ENV_FILE}"

# ---- Config (sobrescreva por env se precisar) ----
SSH_HOST="${SSH_HOST:-root@85.31.231.205}"
REMOTE_APP="${REMOTE_APP:-/home/jonas/www/soluction-sales}"
PG_DB="${PG_DB:-moveisrosa}"
PG_USER="${PG_USER:-jonas}"
PG_HOST="${PG_HOST:-localhost}"
# Senha do postgres de producao: NAO fica no script. Vem de env ou do
# bin/.env.backup (ambos fora do git). Sem ela, o script aborta com instrucao.
PG_PASSWORD="${PG_PASSWORD:-}"

if [ -z "${PG_PASSWORD}" ]; then
  echo "ERRO: PG_PASSWORD nao definida."
  echo "Defina em bin/.env.backup (PG_PASSWORD=...) ou rode:"
  echo "  PG_PASSWORD='suaSenha' bin/backup_producao.sh"
  exit 1
fi

# Caminho local dos backups (ignorado pelo git).
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_ROOT="${ROOT_DIR}/backups"
STAMP="$(date +%Y%m%d_%H%M%S)"
DEST="${BACKUP_ROOT}/${STAMP}"
REMOTE_TMP="/tmp/bkp_moveisrosa_${STAMP}"

echo "==> Backup de producao (${SSH_HOST})"
echo "    banco: ${PG_DB}  |  destino local: ${DEST}"
mkdir -p "${DEST}"

# 1) Dump do banco no servidor (formato custom -Fc = comprimido e restauravel
#    com pg_restore). Gerado em /tmp no servidor e depois baixado.
echo "==> [1/3] pg_dump no servidor..."
ssh "${SSH_HOST}" "mkdir -p '${REMOTE_TMP}' && PGPASSWORD='${PG_PASSWORD}' pg_dump -Fc -U '${PG_USER}' -h '${PG_HOST}' -d '${PG_DB}' -f '${REMOTE_TMP}/${PG_DB}.dump'"

# 2) Baixa o dump.
echo "==> [2/3] baixando o dump do banco..."
scp "${SSH_HOST}:${REMOTE_TMP}/${PG_DB}.dump" "${DEST}/${PG_DB}.dump"

# 3) Baixa a pasta storage/ (rsync incremental; usa SSH). --delete mantem o
#    espelho identico ao servidor (remove localmente o que nao existe mais la).
echo "==> [3/3] sincronizando storage/ (rsync)..."
rsync -az --delete -e ssh "${SSH_HOST}:${REMOTE_APP}/storage/" "${DEST}/storage/"

# Limpa o dump temporario do servidor.
ssh "${SSH_HOST}" "rm -rf '${REMOTE_TMP}'" || true

# Aponta latest -> este backup (link relativo, para o restore achar sempre).
ln -sfn "${STAMP}" "${BACKUP_ROOT}/latest"

echo ""
echo "==> Backup concluido:"
echo "    ${DEST}/${PG_DB}.dump"
echo "    ${DEST}/storage/"
du -sh "${DEST}" 2>/dev/null || true
echo "    (latest -> ${STAMP})"
echo ""
echo "Para restaurar localmente:  bin/restaurar_local.sh"
