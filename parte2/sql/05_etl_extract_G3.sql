-- =============================================================
-- SCRIPT 05 — ETL Extração: G3 (guilherme-hu/EEL890---Big-Data)
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
-- Fonte: Bernardo Brandão (123289593), Enzo Sampaio (123386206),
--        Giovanni Almeida (123184214), Guilherme Hu (123224674),
--        Maria Victoria Ramos (123311073)
-- Repo:  https://github.com/guilherme-hu/EEL890---Big-Data
-- SGBD fonte: MySQL 8 (traduzido para PostgreSQL na extração)
-- Schema fonte: locadora_g3
--
-- Descrição:
--   Extrai dados do sistema OLTP do grupo G3 (guilherme-hu).
--   Este grupo tem schema MySQL com 18 tabelas incluindo:
--   Endereco, Dados_cobranca, Documento_cliente, Cliente,
--   Grupo, Especificacoes_const, Especificacoes_var, Veiculo,
--   Empresa, Patio, Vaga, Seguro, Pagamento, Reserva, Caucao,
--   Locacao, Devolucao, Extensao_reserva.
--
--   Desnormalizações necessárias:
--   - Patio: JOIN com Empresa e Endereco para obter cidade/UF
--   - Veiculo: JOIN com Especificacoes_const para ar_cond
--   - Locacao + Devolucao: unir para obter pátio de entrega
--   - Cliente: JOIN com Endereco para cidade de origem
-- =============================================================

TRUNCATE TABLE staging.g3_patio;
TRUNCATE TABLE staging.g3_grupo;
TRUNCATE TABLE staging.g3_veiculo;
TRUNCATE TABLE staging.g3_cliente;
TRUNCATE TABLE staging.g3_reserva;
TRUNCATE TABLE staging.g3_locacao;
TRUNCATE TABLE staging.g3_devolucao;
TRUNCATE TABLE staging.g3_vaga;

-- -----------------------------------------------
-- 1. Extração de Pátios (desnormalizado com Empresa e Endereço)
-- -----------------------------------------------
INSERT INTO staging.g3_patio (
    id_patio, nome_patio, id_empresa, nome_empresa,
    cidade, uf, dt_extracao
)
SELECT
    p.Id_patio,
    p.Nome_patio,
    e.Id_empresa,
    e.Nome_empresa,
    en.Cidade,
    en.UF,
    CURRENT_TIMESTAMP
FROM locadora_g3."Patio" p
JOIN locadora_g3."Empresa" e  ON e.Id_empresa  = p.Id_empresa
JOIN locadora_g3."Endereco" en ON en.Id_endereco = p.Id_endereco;

-- -----------------------------------------------
-- 2. Extração de Grupos de Veículos
-- -----------------------------------------------
INSERT INTO staging.g3_grupo (
    id_grupo, nome, descricao, diaria_grupo, dt_extracao
)
SELECT
    Id_grupo,
    Nome,
    Descricao,
    Diaria_grupo,
    CURRENT_TIMESTAMP
FROM locadora_g3."Grupo";

-- -----------------------------------------------
-- 3. Extração de Veículos (com especificações constantes)
-- -----------------------------------------------
INSERT INTO staging.g3_veiculo (
    id_veiculo, id_grupo, categoria, marca, modelo, ano,
    cor, chassi, placa, ar_condicionado, direcao_auto, dt_extracao
)
SELECT
    v.Id_veiculo,
    v.Id_grupo,
    v.Categoria,
    v.Marca,
    v.Modelo,
    v.Ano,
    v.Cor,
    v.Chassi,
    v.Placa,
    CASE WHEN ec.Ar_condicionado = 1 THEN TRUE ELSE FALSE END AS ar_condicionado,
    CASE WHEN ec.Direcao_automatica = 1 THEN TRUE ELSE FALSE END AS direcao_auto,
    CURRENT_TIMESTAMP
FROM locadora_g3."Veiculo" v
JOIN locadora_g3."Especificacoes_const" ec ON ec.Id_spec_const = v.Id_spec_const;

-- -----------------------------------------------
-- 4. Extração de Clientes (com cidade de origem do Endereço)
-- -----------------------------------------------
INSERT INTO staging.g3_cliente (
    id_cliente, nome_completo, cpf, nacionalidade,
    cidade, uf, dt_extracao
)
SELECT
    c.Id_cliente,
    c.Nome_completo,
    dc.CPF,
    c.Nacionalidade,
    en.Cidade,
    en.UF,
    CURRENT_TIMESTAMP
FROM locadora_g3."Cliente" c
JOIN locadora_g3."Documento_cliente" dc ON dc.Id_documento = c.Id_documento
JOIN locadora_g3."Endereco" en          ON en.Id_endereco  = c.Id_endereco;

-- -----------------------------------------------
-- 5. Extração de Reservas
-- -----------------------------------------------
INSERT INTO staging.g3_reserva (
    id_reserva, id_cliente, id_grupo,
    id_patio_origem, id_patio_fim,
    data_inicio_combinada, data_fim_combinada,
    data_reserva, estado_reserva, preco_final, dt_extracao
)
SELECT
    Id_reserva,
    Id_cliente,
    Id_grupo,
    Id_patio_origem,
    Id_patio_fim,
    Data_inicio_combinada,
    Data_fim_combinada,
    Data_reserva,
    Estado_reserva,
    Preco_final,
    CURRENT_TIMESTAMP
FROM locadora_g3."Reserva";

-- -----------------------------------------------
-- 6. Extração de Locações
-- -----------------------------------------------
INSERT INTO staging.g3_locacao (
    id_locacao, id_reserva, id_veiculo, id_patio,
    data_locacao, dt_extracao
)
SELECT
    Id_locacao,
    Id_reserva,
    Id_veiculo,
    Id_patio,
    Data_locacao,
    CURRENT_TIMESTAMP
FROM locadora_g3."Locacao";

-- -----------------------------------------------
-- 7. Extração de Devoluções (pátio de entrega via Vaga)
-- -----------------------------------------------
INSERT INTO staging.g3_devolucao (
    id_devolucao, id_locacao, id_vaga,
    data_devolucao, dt_extracao
)
SELECT
    Id_devolucao,
    Id_locacao,
    Id_vaga,
    Data_devolucao,
    CURRENT_TIMESTAMP
FROM locadora_g3."Devolucao";

-- -----------------------------------------------
-- 8. Extração de Vagas (para resolver pátio de entrega)
-- -----------------------------------------------
INSERT INTO staging.g3_vaga (
    id_vaga, cod_vaga, id_patio, dt_extracao
)
SELECT
    Id_vaga,
    Cod_vaga,
    Id_patio,
    CURRENT_TIMESTAMP
FROM locadora_g3."Vaga";
