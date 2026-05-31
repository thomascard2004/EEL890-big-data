-- =============================================================
-- SCRIPT 04 — ETL Extração: G2 (gupessanha/locadora-dw-parte1)
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
-- Fonte: Gustavo Oliveira Pessanha da Silva (DRE 122051824)
--        André Vinícius Lobo Giron (DRE 122050404)
-- Repo:  https://github.com/gupessanha/locadora-dw-parte1
-- SGBD fonte: PostgreSQL
-- Schema fonte: locadora_g2
--
-- Descrição:
--   Extrai dados do sistema OLTP do grupo G2 (gupessanha).
--   Este grupo tem o schema mais completo: patio, vaga, grupo
--   (com franquia_km_diaria), veiculo, cliente (PF+PJ),
--   condutor, reserva, locacao, cobranca.
--
--   Observação: cliente_pf e cliente_pj são subclasses de cliente,
--   então fazemos JOIN para desnormalizar em staging.
-- =============================================================

TRUNCATE TABLE staging.g2_patio;
TRUNCATE TABLE staging.g2_grupo;
TRUNCATE TABLE staging.g2_veiculo;
TRUNCATE TABLE staging.g2_cliente;
TRUNCATE TABLE staging.g2_reserva;
TRUNCATE TABLE staging.g2_locacao;

-- -----------------------------------------------
-- 1. Extração de Pátios
-- -----------------------------------------------
INSERT INTO staging.g2_patio (
    id_patio, nome, endereco, capacidade_vagas, dt_extracao
)
SELECT
    id_patio,
    nome,
    endereco,
    capacidade_vagas,
    CURRENT_TIMESTAMP
FROM locadora_g2.patio;

-- -----------------------------------------------
-- 2. Extração de Grupos de Veículos
-- -----------------------------------------------
INSERT INTO staging.g2_grupo (
    id_grupo, codigo, nome, classe_luxo,
    valor_diaria, franquia_km_diaria, dt_extracao
)
SELECT
    id_grupo,
    codigo,
    nome,
    classe_luxo,
    valor_diaria,
    franquia_km_diaria,
    CURRENT_TIMESTAMP
FROM locadora_g2.grupo;

-- -----------------------------------------------
-- 3. Extração de Veículos
-- -----------------------------------------------
INSERT INTO staging.g2_veiculo (
    id_veiculo, grupo_id, patio_origem_id, placa, chassi,
    marca, modelo, cor, ano_fabricacao, mecanizacao,
    tem_ar_condicionado, km_atual, situacao, dt_extracao
)
SELECT
    id_veiculo,
    grupo_id,
    patio_origem_id,
    placa,
    chassi,
    marca,
    modelo,
    cor,
    ano_fabricacao,
    mecanizacao,
    tem_ar_condicionado,
    km_atual,
    situacao,
    CURRENT_TIMESTAMP
FROM locadora_g2.veiculo;

-- -----------------------------------------------
-- 4. Extração de Clientes (desnormalizando PF+PJ)
-- -----------------------------------------------
-- PF: traz CPF, data_nascimento
INSERT INTO staging.g2_cliente (
    id_cliente, tipo_pessoa, nome, email, telefone, cidade_origem,
    cpf, data_nascimento, dt_extracao
)
SELECT
    c.id_cliente,
    c.tipo_pessoa,
    c.nome,
    c.email,
    c.telefone,
    c.cidade_origem,
    pf.cpf,
    pf.data_nascimento,
    CURRENT_TIMESTAMP
FROM locadora_g2.cliente c
JOIN locadora_g2.cliente_pf pf ON pf.cliente_id = c.id_cliente
WHERE c.tipo_pessoa = 'PF';

-- PJ: traz CNPJ
INSERT INTO staging.g2_cliente (
    id_cliente, tipo_pessoa, nome, email, telefone, cidade_origem,
    cnpj, dt_extracao
)
SELECT
    c.id_cliente,
    c.tipo_pessoa,
    c.nome,
    c.email,
    c.telefone,
    c.cidade_origem,
    pj.cnpj,
    CURRENT_TIMESTAMP
FROM locadora_g2.cliente c
JOIN locadora_g2.cliente_pj pj ON pj.cliente_id = c.id_cliente
WHERE c.tipo_pessoa = 'PJ';

-- -----------------------------------------------
-- 5. Extração de Reservas
-- -----------------------------------------------
INSERT INTO staging.g2_reserva (
    id_reserva, cliente_id, grupo_id,
    patio_retirada_id, patio_devolucao_id,
    data_reserva, data_retirada_prevista,
    data_devolucao_prevista, estado, dt_extracao
)
SELECT
    id_reserva,
    cliente_id,
    grupo_id,
    patio_retirada_id,
    patio_devolucao_id,
    data_reserva,
    data_retirada_prevista,
    data_devolucao_prevista,
    estado,
    CURRENT_TIMESTAMP
FROM locadora_g2.reserva;

-- -----------------------------------------------
-- 6. Extração de Locações
-- -----------------------------------------------
INSERT INTO staging.g2_locacao (
    id_locacao, reserva_id, cliente_id, veiculo_id,
    patio_retirada_id, patio_devolucao_id,
    data_retirada_real, data_devolucao_real,
    km_saida, km_chegada, valor_diaria_aplicada,
    status, dt_extracao
)
SELECT
    id_locacao,
    reserva_id,
    cliente_id,
    veiculo_id,
    patio_retirada_id,
    patio_devolucao_id,
    data_retirada_real,
    data_devolucao_real,
    km_saida,
    km_chegada,
    valor_diaria_aplicada,
    status,
    CURRENT_TIMESTAMP
FROM locadora_g2.locacao;
