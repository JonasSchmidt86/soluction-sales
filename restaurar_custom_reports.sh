#!/bin/bash

# Configurações
USUARIO="postgres"
BANCO="moveisrosa"
TABELA="custom_reports"
ARQUIVO_BACKUP="/Users/jonas/Desktop/BANCO/custom_reports.sql"

# 1. Truncar a tabela
echo "Limpando dados da tabela $TABELA..."
psql -U "$USUARIO" -d "$BANCO" -c "TRUNCATE TABLE $TABELA RESTART IDENTITY CASCADE;"

# 2. Restaurar os dados
echo "Restaurando backup da tabela $TABELA..."
psql -U "$USUARIO" -d "$BANCO" -f "$ARQUIVO_BACKUP"

echo "Restauração concluída com sucesso!"
