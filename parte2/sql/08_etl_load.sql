-- =============================================================
-- SCRIPT 08 — ETL Carga: Dimensões e Fatos do DW
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
-- SGBD: PostgreSQL (ANSI SQL:1999+)
--
-- Descrição:
--   Carrega as dimensões e tabelas de fatos do DW a partir
--   das tabelas de staging transformadas.
--   Ordem de carga: Dimensões → Fatos (respeitar FKs)
--   Estratégia: TRUNCATE + INSERT FULL (simplificada para
--   o escopo acadêmico; em produção usaria SCD Tipo 2).
-- =============================================================

-- =============================================================
-- 0. LIMPAR DW PARA RECARGA
-- =============================================================
TRUNCATE TABLE dw.fato_patio_snapshot CASCADE;
TRUNCATE TABLE dw.fato_reserva CASCADE;
TRUNCATE TABLE dw.fato_locacao CASCADE;
TRUNCATE TABLE dw.dim_veiculo CASCADE;
TRUNCATE TABLE dw.dim_cliente CASCADE;
TRUNCATE TABLE dw.dim_grupo_veiculo CASCADE;
TRUNCATE TABLE dw.dim_empresa CASCADE;
TRUNCATE TABLE dw.dim_patio CASCADE;
TRUNCATE TABLE dw.dim_tempo CASCADE;

-- =============================================================
-- 1. CARGA DA dim_tempo
--    Popula todos os dias de 2020 a 2030
-- =============================================================
INSERT INTO dw.dim_tempo (
    data_completa, dia, mes, trimestre, semestre, ano,
    num_semana_ano, dia_semana_num, dia_semana_nome,
    nome_mes, eh_fim_semana
)
SELECT
    d::DATE AS data_completa,
    EXTRACT(DAY   FROM d)::INT AS dia,
    EXTRACT(MONTH FROM d)::INT AS mes,
    EXTRACT(QUARTER FROM d)::INT AS trimestre,
    CASE WHEN EXTRACT(MONTH FROM d) <= 6 THEN 1 ELSE 2 END AS semestre,
    EXTRACT(YEAR  FROM d)::INT AS ano,
    EXTRACT(WEEK  FROM d)::INT AS num_semana_ano,
    EXTRACT(DOW   FROM d)::INT + 1 AS dia_semana_num,   -- 1=Dom
    TO_CHAR(d, 'Day') AS dia_semana_nome,
    TO_CHAR(d, 'Month') AS nome_mes,
    EXTRACT(DOW FROM d) IN (0, 6) AS eh_fim_semana
FROM generate_series('2020-01-01'::DATE, '2030-12-31'::DATE, INTERVAL '1 day') AS d;

-- =============================================================
-- 2. CARGA DA dim_empresa
-- =============================================================

-- G1: empresa única (dona de cada pátio)
INSERT INTO dw.dim_empresa (id_empresa_orig, nome_empresa, cnpj, fonte_grupo)
SELECT DISTINCT
    ROW_NUMBER() OVER () AS id_empresa_orig,
    empresa_dona,
    NULL,
    'G1'
FROM staging.g1_patio;

-- G2: não tem tabela de empresa; empresa implícita pelo pátio
INSERT INTO dw.dim_empresa (id_empresa_orig, nome_empresa, cnpj, fonte_grupo)
VALUES (NULL, 'EMPRESA_G2', NULL, 'G2');

-- G3: tabela Empresa com CNPJ
INSERT INTO dw.dim_empresa (id_empresa_orig, nome_empresa, cnpj, fonte_grupo)
SELECT DISTINCT
    id_empresa,
    nome_empresa,
    NULL,
    'G3'
FROM staging.g3_patio;

-- G4: tabela Parceira
INSERT INTO dw.dim_empresa (id_empresa_orig, nome_empresa, cnpj, fonte_grupo)
SELECT DISTINCT
    ROW_NUMBER() OVER () AS id_empresa_orig,
    nome_parceira,
    NULL,
    'G4'
FROM staging.g4_patio;

-- =============================================================
-- 3. CARGA DA dim_patio
-- =============================================================

INSERT INTO dw.dim_patio (id_patio_orig, nome_patio, empresa_dona, cidade, uf, fonte_grupo)
SELECT id_patio, nome_localizacao, empresa_dona, NULL, NULL, 'G1'
FROM staging.g1_patio;

INSERT INTO dw.dim_patio (id_patio_orig, nome_patio, empresa_dona, cidade, uf, fonte_grupo)
SELECT id_patio, nome, 'EMPRESA_G2', NULL, NULL, 'G2'
FROM staging.g2_patio;

INSERT INTO dw.dim_patio (id_patio_orig, nome_patio, empresa_dona, cidade, uf, fonte_grupo)
SELECT id_patio, nome_patio, nome_empresa, cidade, uf, 'G3'
FROM staging.g3_patio;

INSERT INTO dw.dim_patio (id_patio_orig, nome_patio, empresa_dona, cidade, uf, fonte_grupo)
SELECT id_patio, cd_patio, nome_parceira, cidade, uf, 'G4'
FROM staging.g4_patio;

-- =============================================================
-- 4. CARGA DA dim_grupo_veiculo
-- =============================================================

INSERT INTO dw.dim_grupo_veiculo (id_grupo_orig, codigo_grupo, nome_grupo, classe_luxo, valor_diaria, fonte_grupo)
SELECT id_grupo, NULL, nome_categoria, classe_luxo, valor_diaria, 'G1'
FROM staging.g1_grupo_veiculo;

INSERT INTO dw.dim_grupo_veiculo (id_grupo_orig, codigo_grupo, nome_grupo, classe_luxo, valor_diaria, fonte_grupo)
SELECT id_grupo, codigo, nome, classe_luxo, valor_diaria, 'G2'
FROM staging.g2_grupo;

INSERT INTO dw.dim_grupo_veiculo (id_grupo_orig, codigo_grupo, nome_grupo, classe_luxo, valor_diaria, fonte_grupo)
SELECT id_grupo, NULL, nome, NULL, diaria_grupo, 'G3'
FROM staging.g3_grupo;

INSERT INTO dw.dim_grupo_veiculo (id_grupo_orig, codigo_grupo, nome_grupo, classe_luxo, valor_diaria, fonte_grupo)
SELECT id_categoria, NULL, classificacao, classe_luxo_conf, valor_diaria_base, 'G4'
FROM staging.g4_categoria;

-- =============================================================
-- 5. CARGA DA dim_veiculo
-- =============================================================

INSERT INTO dw.dim_veiculo (
    id_veiculo_orig, placa, chassi, marca, modelo, ano_fabricacao,
    cor, mecanizacao, ar_condicionado, sk_grupo, sk_empresa_origem, fonte_grupo
)
SELECT
    v.id_veiculo, v.placa, v.chassi, v.marca, v.modelo, NULL,
    v.cor, v.mecanizacao, v.ar_condicionado,
    dg.sk_grupo, NULL, 'G1'
FROM staging.g1_veiculo v
JOIN dw.dim_grupo_veiculo dg ON dg.id_grupo_orig = v.id_grupo AND dg.fonte_grupo = 'G1';

INSERT INTO dw.dim_veiculo (
    id_veiculo_orig, placa, chassi, marca, modelo, ano_fabricacao,
    cor, mecanizacao, ar_condicionado, sk_grupo, sk_empresa_origem, fonte_grupo
)
SELECT
    v.id_veiculo, v.placa, v.chassi, v.marca, v.modelo, v.ano_fabricacao,
    v.cor, v.mecanizacao, v.tem_ar_condicionado,
    dg.sk_grupo,
    (SELECT sk_empresa FROM dw.dim_empresa WHERE fonte_grupo='G2' LIMIT 1),
    'G2'
FROM staging.g2_veiculo v
JOIN dw.dim_grupo_veiculo dg ON dg.id_grupo_orig = v.grupo_id AND dg.fonte_grupo = 'G2';

INSERT INTO dw.dim_veiculo (
    id_veiculo_orig, placa, chassi, marca, modelo, ano_fabricacao,
    cor, mecanizacao, ar_condicionado, sk_grupo, sk_empresa_origem, fonte_grupo
)
SELECT
    v.id_veiculo, v.placa, v.chassi, v.marca, v.modelo,
    v.ano::INT,
    v.cor, v.mecanizacao_conf, v.ar_condicionado,
    dg.sk_grupo, NULL, 'G3'
FROM staging.g3_veiculo v
JOIN dw.dim_grupo_veiculo dg ON dg.id_grupo_orig = v.id_grupo AND dg.fonte_grupo = 'G3';

INSERT INTO dw.dim_veiculo (
    id_veiculo_orig, placa, chassi, marca, modelo, ano_fabricacao,
    cor, mecanizacao, ar_condicionado, sk_grupo, sk_empresa_origem, fonte_grupo
)
SELECT
    v.id_veiculo, v.placa, v.chassi, NULL, v.modelo,
    v.ano, NULL, NULL, v.ar_condicionado,
    dg.sk_grupo, NULL, 'G4'
FROM staging.g4_veiculo v
JOIN dw.dim_grupo_veiculo dg ON dg.id_grupo_orig = v.id_categoria AND dg.fonte_grupo = 'G4';

-- =============================================================
-- 6. CARGA DA dim_cliente
-- =============================================================

INSERT INTO dw.dim_cliente (id_cliente_orig, nome, tipo_pessoa, cpf_cnpj, cidade_origem, uf_origem, fonte_grupo)
SELECT id_cliente, nome_razao_social, tipo_cliente, cpf_cnpj, 'NAO_INFORMADO', NULL, 'G1'
FROM staging.g1_cliente;

INSERT INTO dw.dim_cliente (id_cliente_orig, nome, tipo_pessoa, cpf_cnpj, cidade_origem, uf_origem, fonte_grupo)
SELECT id_cliente, nome, tipo_pessoa,
    COALESCE(cpf, cnpj), cidade_origem, NULL, 'G2'
FROM staging.g2_cliente;

INSERT INTO dw.dim_cliente (id_cliente_orig, nome, tipo_pessoa, cpf_cnpj, cidade_origem, uf_origem, fonte_grupo)
SELECT id_cliente, nome_completo, 'PF', cpf, cidade, uf, 'G3'
FROM staging.g3_cliente;

-- G4: usa Motorista como proxy de cliente (PF)
INSERT INTO dw.dim_cliente (id_cliente_orig, nome, tipo_pessoa, cpf_cnpj, cidade_origem, uf_origem, fonte_grupo)
SELECT id_motorista, nome, 'PF', cpf, cidade, uf, 'G4'
FROM staging.g4_motorista;

-- =============================================================
-- 7. CARGA DA fato_locacao
--
-- COMO FUNCIONA O LOOKUP DE SURROGATE KEYS (SK)?
--   Na carga de tabelas de fato, os dados vêm da staging contendo os IDs
--   naturais das fontes (ex: id_cliente = 200). Não podemos inserir esse ID
--   diretamente no DW pois ele não garante unicidade global (outro grupo pode
--   ter outro cliente com ID 200).
--
--   Para resolver isso, fazemos JOINs com as dimensões correspondentes
--   usando o ID original AND o identificador do grupo (ex: fonte_grupo = 'G1').
--   Isso recupera a Surrogate Key única e sequencial (sk_cliente) que
--   representa esse cliente no DW.
-- =============================================================

-- G1
INSERT INTO dw.fato_locacao (
    id_locacao_orig, sk_tempo_retirada, sk_tempo_devolucao,
    sk_cliente, sk_veiculo, sk_grupo, sk_patio_retirada, sk_patio_entrega,
    duracao_dias_prevista, duracao_dias_real, valor_diaria, valor_total,
    locacao_intercompanhia, status_locacao, fonte_grupo
)
SELECT
    l.id_locacao,
    dt_ret.sk_tempo,
    dt_dev.sk_tempo,
    dc.sk_cliente,
    dv.sk_veiculo,
    dg.sk_grupo,
    dp_sai.sk_patio,
    dp_che.sk_patio,
    l.duracao_dias_prevista,
    l.duracao_dias_real,
    gv.valor_diaria,
    l.valor_final,
    (l.id_patio_saida IS DISTINCT FROM l.id_patio_chegada_realizada),
    l.status_conformado,
    'G1'
FROM staging.g1_locacao l
JOIN staging.g1_veiculo sv    ON sv.id_veiculo = l.id_veiculo
JOIN dw.dim_tempo dt_ret      ON dt_ret.data_completa = l.data_hora_retirada::DATE
LEFT JOIN dw.dim_tempo dt_dev ON dt_dev.data_completa = l.data_hora_devolucao_realizada::DATE
JOIN dw.dim_cliente dc        ON dc.id_cliente_orig = (
    SELECT r.id_cliente FROM staging.g1_reserva r WHERE r.id_reserva = l.id_reserva LIMIT 1
) AND dc.fonte_grupo = 'G1'
JOIN dw.dim_veiculo dv        ON dv.id_veiculo_orig = l.id_veiculo AND dv.fonte_grupo = 'G1'
JOIN dw.dim_grupo_veiculo dg  ON dg.id_grupo_orig = sv.id_grupo AND dg.fonte_grupo = 'G1'
JOIN dw.dim_grupo_veiculo gvd ON gvd.sk_grupo = dg.sk_grupo  -- alias para valor_diaria
JOIN staging.g1_grupo_veiculo gv ON gv.id_grupo = sv.id_grupo
JOIN dw.dim_patio dp_sai      ON dp_sai.id_patio_orig = l.id_patio_saida AND dp_sai.fonte_grupo = 'G1'
LEFT JOIN dw.dim_patio dp_che ON dp_che.id_patio_orig = l.id_patio_chegada_realizada AND dp_che.fonte_grupo = 'G1';

-- G2
INSERT INTO dw.fato_locacao (
    id_locacao_orig, sk_tempo_retirada, sk_tempo_devolucao,
    sk_cliente, sk_veiculo, sk_grupo, sk_patio_retirada, sk_patio_entrega,
    duracao_dias_prevista, duracao_dias_real, valor_diaria, valor_total,
    km_percorridos, locacao_intercompanhia, status_locacao, fonte_grupo
)
SELECT
    l.id_locacao,
    dt_ret.sk_tempo,
    dt_dev.sk_tempo,
    dc.sk_cliente,
    dv.sk_veiculo,
    dg.sk_grupo,
    dp_ret.sk_patio,
    dp_ent.sk_patio,
    l.duracao_dias_prevista,
    l.duracao_dias_real,
    l.valor_diaria_aplicada,
    l.valor_diaria_aplicada * l.duracao_dias_real,
    l.km_percorridos,
    (l.patio_retirada_id IS DISTINCT FROM l.patio_devolucao_id),
    l.status,
    'G2'
FROM staging.g2_locacao l
JOIN staging.g2_veiculo sv       ON sv.id_veiculo = l.veiculo_id
JOIN dw.dim_tempo dt_ret         ON dt_ret.data_completa = l.data_retirada_real::DATE
LEFT JOIN dw.dim_tempo dt_dev    ON dt_dev.data_completa = l.data_devolucao_real::DATE
JOIN dw.dim_cliente dc           ON dc.id_cliente_orig = l.cliente_id AND dc.fonte_grupo = 'G2'
JOIN dw.dim_veiculo dv           ON dv.id_veiculo_orig = l.veiculo_id AND dv.fonte_grupo = 'G2'
JOIN dw.dim_grupo_veiculo dg     ON dg.id_grupo_orig = sv.grupo_id AND dg.fonte_grupo = 'G2'
JOIN dw.dim_patio dp_ret         ON dp_ret.id_patio_orig = l.patio_retirada_id AND dp_ret.fonte_grupo = 'G2'
LEFT JOIN dw.dim_patio dp_ent    ON dp_ent.id_patio_orig = l.patio_devolucao_id AND dp_ent.fonte_grupo = 'G2';

-- G3
INSERT INTO dw.fato_locacao (
    id_locacao_orig, sk_tempo_retirada, sk_tempo_devolucao,
    sk_cliente, sk_veiculo, sk_grupo, sk_patio_retirada, sk_patio_entrega,
    duracao_dias_prevista, duracao_dias_real, valor_diaria, valor_total,
    locacao_intercompanhia, status_locacao, fonte_grupo
)
SELECT
    l.id_locacao,
    dt_ret.sk_tempo,
    dt_dev.sk_tempo,
    dc.sk_cliente,
    dv.sk_veiculo,
    dg.sk_grupo,
    dp_ret.sk_patio,
    dp_ent.sk_patio,
    r.duracao_prevista_dias,
    CASE
        WHEN l.data_devolucao IS NOT NULL
        THEN EXTRACT(DAY FROM (l.data_devolucao - l.data_locacao))::INT
        ELSE NULL
    END,
    gr.diaria_grupo,
    r.preco_final,
    (l.id_patio IS DISTINCT FROM l.id_patio_entrega),
    l.status_conformado,
    'G3'
FROM staging.g3_locacao l
JOIN staging.g3_reserva r        ON r.id_reserva = l.id_reserva
JOIN staging.g3_veiculo sv       ON sv.id_veiculo = l.id_veiculo
JOIN staging.g3_grupo gr         ON gr.id_grupo = sv.id_grupo
JOIN dw.dim_tempo dt_ret         ON dt_ret.data_completa = l.data_locacao::DATE
LEFT JOIN dw.dim_tempo dt_dev    ON dt_dev.data_completa = l.data_devolucao::DATE
JOIN dw.dim_cliente dc           ON dc.id_cliente_orig = r.id_cliente AND dc.fonte_grupo = 'G3'
JOIN dw.dim_veiculo dv           ON dv.id_veiculo_orig = l.id_veiculo AND dv.fonte_grupo = 'G3'
JOIN dw.dim_grupo_veiculo dg     ON dg.id_grupo_orig = sv.id_grupo AND dg.fonte_grupo = 'G3'
JOIN dw.dim_patio dp_ret         ON dp_ret.id_patio_orig = l.id_patio AND dp_ret.fonte_grupo = 'G3'
LEFT JOIN dw.dim_patio dp_ent    ON dp_ent.id_patio_orig = l.id_patio_entrega AND dp_ent.fonte_grupo = 'G3';

-- G4
INSERT INTO dw.fato_locacao (
    id_locacao_orig, sk_tempo_retirada, sk_tempo_devolucao,
    sk_cliente, sk_veiculo, sk_grupo, sk_patio_retirada, sk_patio_entrega,
    duracao_dias_real, valor_diaria, valor_total,
    locacao_intercompanhia, status_locacao, fonte_grupo
)
SELECT
    l.id_locacao,
    dt_ret.sk_tempo,
    dt_dev.sk_tempo,
    dc.sk_cliente,
    dv.sk_veiculo,
    dg.sk_grupo,
    dp_ret.sk_patio,
    dp_ent.sk_patio,
    l.duracao_dias_real,
    l.valor_diaria,
    l.valor_diaria * l.duracao_dias_real,
    (l.id_patio_retirada IS DISTINCT FROM l.id_patio_entrega),
    l.status_conformado,
    'G4'
FROM staging.g4_locacao l
JOIN staging.g4_veiculo sv       ON sv.id_veiculo = l.id_veiculo
JOIN dw.dim_tempo dt_ret         ON dt_ret.data_completa = l.dt_retirada::DATE
LEFT JOIN dw.dim_tempo dt_dev    ON dt_dev.data_completa = l.dt_chegada::DATE
JOIN dw.dim_cliente dc           ON dc.id_cliente_orig = l.id_motorista AND dc.fonte_grupo = 'G4'
JOIN dw.dim_veiculo dv           ON dv.id_veiculo_orig = l.id_veiculo AND dv.fonte_grupo = 'G4'
JOIN dw.dim_grupo_veiculo dg     ON dg.id_grupo_orig = sv.id_categoria AND dg.fonte_grupo = 'G4'
LEFT JOIN dw.dim_patio dp_ret    ON dp_ret.id_patio_orig = l.id_patio_retirada AND dp_ret.fonte_grupo = 'G4'
LEFT JOIN dw.dim_patio dp_ent    ON dp_ent.id_patio_orig = l.id_patio_entrega AND dp_ent.fonte_grupo = 'G4';

-- =============================================================
-- 8. CARGA DA fato_reserva
-- =============================================================

-- G1
INSERT INTO dw.fato_reserva (
    id_reserva_orig, sk_tempo_solicitacao, sk_tempo_retirada_prev,
    sk_tempo_devolucao_prev, sk_cliente, sk_grupo, sk_patio_retirada,
    duracao_prevista_dias, status_reserva, fonte_grupo
)
SELECT
    r.id_reserva,
    dt_sol.sk_tempo,
    dt_ret.sk_tempo,
    dt_dev.sk_tempo,
    dc.sk_cliente,
    dg.sk_grupo,
    dp.sk_patio,
    EXTRACT(DAY FROM (r.data_hora_devolucao_prevista - r.data_hora_retirada_prevista))::INT,
    r.status_reserva,
    'G1'
FROM staging.g1_reserva r
JOIN dw.dim_tempo dt_sol ON dt_sol.data_completa = r.data_hora_solicitacao::DATE
JOIN dw.dim_tempo dt_ret ON dt_ret.data_completa = r.data_hora_retirada_prevista::DATE
JOIN dw.dim_tempo dt_dev ON dt_dev.data_completa = r.data_hora_devolucao_prevista::DATE
JOIN dw.dim_cliente dc   ON dc.id_cliente_orig = r.id_cliente AND dc.fonte_grupo = 'G1'
JOIN dw.dim_grupo_veiculo dg ON dg.id_grupo_orig = r.id_grupo AND dg.fonte_grupo = 'G1'
JOIN dw.dim_patio dp     ON dp.id_patio_orig = r.id_patio_retirada AND dp.fonte_grupo = 'G1';

-- G2
INSERT INTO dw.fato_reserva (
    id_reserva_orig, sk_tempo_solicitacao, sk_tempo_retirada_prev,
    sk_tempo_devolucao_prev, sk_cliente, sk_grupo, sk_patio_retirada, sk_patio_devolucao,
    duracao_prevista_dias, status_reserva, fonte_grupo
)
SELECT
    r.id_reserva,
    dt_sol.sk_tempo,
    dt_ret.sk_tempo,
    dt_dev.sk_tempo,
    dc.sk_cliente,
    dg.sk_grupo,
    dp_ret.sk_patio,
    dp_dev.sk_patio,
    EXTRACT(DAY FROM (r.data_devolucao_prevista - r.data_retirada_prevista))::INT,
    r.estado,
    'G2'
FROM staging.g2_reserva r
JOIN dw.dim_tempo dt_sol     ON dt_sol.data_completa = r.data_reserva::DATE
JOIN dw.dim_tempo dt_ret     ON dt_ret.data_completa = r.data_retirada_prevista::DATE
JOIN dw.dim_tempo dt_dev     ON dt_dev.data_completa = r.data_devolucao_prevista::DATE
JOIN dw.dim_cliente dc       ON dc.id_cliente_orig = r.cliente_id AND dc.fonte_grupo = 'G2'
JOIN dw.dim_grupo_veiculo dg ON dg.id_grupo_orig = r.grupo_id AND dg.fonte_grupo = 'G2'
JOIN dw.dim_patio dp_ret     ON dp_ret.id_patio_orig = r.patio_retirada_id AND dp_ret.fonte_grupo = 'G2'
LEFT JOIN dw.dim_patio dp_dev ON dp_dev.id_patio_orig = r.patio_devolucao_id AND dp_dev.fonte_grupo = 'G2';

-- G3
INSERT INTO dw.fato_reserva (
    id_reserva_orig, sk_tempo_solicitacao, sk_tempo_retirada_prev,
    sk_tempo_devolucao_prev, sk_cliente, sk_grupo, sk_patio_retirada, sk_patio_devolucao,
    duracao_prevista_dias, status_reserva, fonte_grupo
)
SELECT
    r.id_reserva,
    dt_sol.sk_tempo,
    dt_ret.sk_tempo,
    dt_dev.sk_tempo,
    dc.sk_cliente,
    dg.sk_grupo,
    dp_ret.sk_patio,
    dp_dev.sk_patio,
    r.duracao_prevista_dias,
    r.status_conformado,
    'G3'
FROM staging.g3_reserva r
JOIN dw.dim_tempo dt_sol     ON dt_sol.data_completa = r.data_reserva
JOIN dw.dim_tempo dt_ret     ON dt_ret.data_completa = r.data_inicio_combinada::DATE
JOIN dw.dim_tempo dt_dev     ON dt_dev.data_completa = r.data_fim_combinada::DATE
JOIN dw.dim_cliente dc       ON dc.id_cliente_orig = r.id_cliente AND dc.fonte_grupo = 'G3'
JOIN dw.dim_grupo_veiculo dg ON dg.id_grupo_orig = r.id_grupo AND dg.fonte_grupo = 'G3'
JOIN dw.dim_patio dp_ret     ON dp_ret.id_patio_orig = r.id_patio_origem AND dp_ret.fonte_grupo = 'G3'
LEFT JOIN dw.dim_patio dp_dev ON dp_dev.id_patio_orig = r.id_patio_fim AND dp_dev.fonte_grupo = 'G3';

-- =============================================================
-- 9. CARGA DA fato_patio_snapshot (snapshot do dia atual)
-- =============================================================
-- Registra os veículos disponíveis em cada pátio hoje (T=hoje)
-- Em produção, seria executado diariamente pela rotina de staging.

INSERT INTO dw.fato_patio_snapshot (
    sk_tempo, sk_patio, sk_veiculo, sk_grupo,
    sk_empresa_veiculo, origem_veiculo, fonte_grupo
)
SELECT
    dt.sk_tempo,
    dp.sk_patio,
    dv.sk_veiculo,
    dv.sk_grupo,
    dv.sk_empresa_origem,
    CASE
        WHEN dp.empresa_dona = COALESCE(
            (SELECT nome_empresa FROM dw.dim_empresa de WHERE de.sk_empresa = dv.sk_empresa_origem),
            dp.empresa_dona
        ) THEN 'PROPRIA'
        ELSE 'EXTERNA'
    END,
    dv.fonte_grupo
FROM dw.dim_veiculo dv
JOIN dw.dim_patio dp     ON dp.fonte_grupo = dv.fonte_grupo
JOIN dw.dim_tempo dt     ON dt.data_completa = CURRENT_DATE
JOIN dw.dim_grupo_veiculo dg ON dg.sk_grupo = dv.sk_grupo
-- Apenas veículos G1 com status disponível (exemplo)
WHERE dv.fonte_grupo = 'G1'
  AND EXISTS (
    SELECT 1 FROM staging.g1_veiculo gv
    WHERE gv.id_veiculo = dv.id_veiculo_orig
      AND gv.status_disponibilidade = 'Disponível'
  )

UNION ALL

-- G2: veículos DISPONIVEL
SELECT
    dt.sk_tempo, dp.sk_patio, dv.sk_veiculo, dv.sk_grupo,
    dv.sk_empresa_origem,
    CASE WHEN dp.empresa_dona = 'EMPRESA_G2' THEN 'PROPRIA' ELSE 'EXTERNA' END,
    'G2'
FROM dw.dim_veiculo dv
JOIN staging.g2_veiculo sv ON sv.id_veiculo = dv.id_veiculo_orig AND dv.fonte_grupo = 'G2'
JOIN dw.dim_patio dp       ON dp.id_patio_orig = sv.patio_origem_id AND dp.fonte_grupo = 'G2'
JOIN dw.dim_tempo dt       ON dt.data_completa = CURRENT_DATE
WHERE sv.situacao = 'DISPONIVEL';
