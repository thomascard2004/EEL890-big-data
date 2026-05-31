#!/bin/bash
set -e

echo "========================================================"
echo " INICIALIZANDO O DATA WAREHOUSE INTEGRADO (CONSORCIO)   "
echo "========================================================"

# Executa cada arquivo SQL na ordem correta.
# A pasta /sql é montada via docker-compose (volume read-only).
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    \echo '1/7: Criando Staging Area...'
    \i /sql/01_staging_ddl.sql

    \echo '2/7: Criando Star Schema (Tabelas dw)...'
    \i /sql/02_dw_star_schema.sql

    \echo '3/7: Carregando dados simulados para a Staging...'
    \i /sql/99_mock_inserts.sql

    \echo '4/7: Executando transformacoes do ETL...'
    \i /sql/07_etl_transform.sql

    \echo '5/7: Carregando dados no Data Warehouse...'
    \i /sql/08_etl_load.sql

    \echo '6/7: Criando as Views de Relatorios...'
    \i /sql/09_relatorios.sql

    \echo '7/7: Calculando a Matriz de Transicao e Markov...'
    \i /sql/10_matriz_markov.sql
EOSQL

echo "========================================================"
echo " PIPELINE FINALIZADA COM SUCESSO!                       "
echo " Banco 'locadora_dwh' pronto para consultas na porta 5432"
echo "========================================================"
