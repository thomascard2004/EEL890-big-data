-- =============================================================
-- SCRIPT 03 — ETL Extração: G1 (Nosso grupo — thomascard2004)
-- =============================================================
-- Grupo:
--   Thomas Cardoso de Miranda       DRE 122050797
--   Thiago Moutinho de Carvalho Maksoud DRE 119048139
--   Yan Lukas Willian Tavares       DRE 124341835
--
-- Disciplina: EEL890 / MAE016 — Big Data e Data Warehouse
-- UFRJ — Instituto de Matemática — DMA
-- Avaliação 02 — Parte II: Modelagem de DW
--
-- SGBD fonte: ANSI SQL (PostgreSQL compatível)
-- Schema fonte: locadora_g1
--
--   Extrai dados do nosso próprio sistema OLTP (G1) e insere
--   na área de staging. Utiliza lógica de carga incremental
--   baseada em data de alteração (dt_extracao).
--   Agendamento: conforme tabela de acionamentos em 01_staging_ddl.sql
-- =============================================================

-- Supõe que o schema do sistema transacional G1 se chama 'locadora_g1'
-- Em produção, este schema estará em um servidor/banco separado,
-- acessado via dblink ou foreign data wrapper (postgres_fdw).

-- Limpa os dados anteriores de G1 na staging para carga full
TRUNCATE TABLE staging.g1_patio;
TRUNCATE TABLE staging.g1_grupo_veiculo;
TRUNCATE TABLE staging.g1_veiculo;
TRUNCATE TABLE staging.g1_cliente;
TRUNCATE TABLE staging.g1_reserva;
TRUNCATE TABLE staging.g1_locacao;

-- -----------------------------------------------
-- 1. Extração de Pátios
-- -----------------------------------------------
INSERT INTO staging.g1_patio (
    id_patio, nome_localizacao, capacidade_vagas, empresa_dona, dt_extracao
)
SELECT
    ID_Patio,
    Nome_Localizacao,
    Capacidade_Vagas,
    Empresa_Dona,
    CURRENT_TIMESTAMP
FROM locadora_g1."Patio";

-- -----------------------------------------------
-- 2. Extração de Grupos de Veículos
-- -----------------------------------------------
INSERT INTO staging.g1_grupo_veiculo (
    id_grupo, nome_categoria, classe_luxo, valor_diaria, dt_extracao
)
SELECT
    ID_Grupo,
    Nome_Categoria,
    Classe_Luxo,
    Valor_Diaria,
    CURRENT_TIMESTAMP
FROM locadora_g1."Grupo_Veiculo";

-- -----------------------------------------------
-- 3. Extração de Veículos
-- -----------------------------------------------
INSERT INTO staging.g1_veiculo (
    id_veiculo, id_grupo, placa, chassi, marca, modelo, cor,
    ar_condicionado, mecanizacao, status_disponibilidade, dt_extracao
)
SELECT
    ID_Veiculo,
    ID_Grupo,
    Placa,
    Chassi,
    Marca,
    Modelo,
    Cor,
    Ar_Condicionado,
    Mecanizacao,
    Status_Disponibilidade,
    CURRENT_TIMESTAMP
FROM locadora_g1."Veiculo";

-- -----------------------------------------------
-- 4. Extração de Clientes
-- -----------------------------------------------
INSERT INTO staging.g1_cliente (
    id_cliente, tipo_cliente, nome_razao_social, cpf_cnpj, dt_extracao
)
SELECT
    ID_Cliente,
    Tipo_Cliente,
    Nome_Razao_Social,
    CPF_CNPJ,
    CURRENT_TIMESTAMP
FROM locadora_g1."Cliente";

-- -----------------------------------------------
-- 5. Extração de Reservas
-- -----------------------------------------------
INSERT INTO staging.g1_reserva (
    id_reserva, id_cliente, id_grupo, id_patio_retirada,
    data_hora_solicitacao, data_hora_retirada_prevista,
    data_hora_devolucao_prevista, status_reserva, dt_extracao
)
SELECT
    ID_Reserva,
    ID_Cliente,
    ID_Grupo,
    ID_Patio_Retirada,
    Data_Hora_Solicitacao,
    Data_Hora_Retirada_Prevista,
    Data_Hora_Devolucao_Prevista,
    Status_Reserva,
    CURRENT_TIMESTAMP
FROM locadora_g1."Reserva";

-- -----------------------------------------------
-- 6. Extração de Locações
-- -----------------------------------------------
INSERT INTO staging.g1_locacao (
    id_locacao, id_reserva, id_veiculo,
    id_patio_saida, id_patio_chegada_prevista, id_patio_chegada_realizada,
    data_hora_retirada, data_hora_devolucao_prevista,
    data_hora_devolucao_realizada, valor_inicial, valor_final, dt_extracao
)
SELECT
    ID_Locacao,
    ID_Reserva,
    ID_Veiculo,
    ID_Patio_Saida,
    ID_Patio_Chegada_Prevista,
    ID_Patio_Chegada_Realizada,
    Data_Hora_Retirada,
    Data_Hora_Devolucao_Prevista,
    Data_Hora_Devolucao_Realizada,
    Valor_Inicial,
    Valor_Final,
    CURRENT_TIMESTAMP
FROM locadora_g1."Locacao";
