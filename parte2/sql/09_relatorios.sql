-- =============================================================
-- SCRIPT 09 — Relatórios Gerenciais
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
--   Implementa os 4 relatórios gerenciais globais requeridos
--   pelo enunciado (item 12), consultando as tabelas de fatos
--   e dimensões do DW integrado.
-- =============================================================


-- =============================================================
-- RELATÓRIO A) Controle de Pátio
-- Quantitativo de veículos por grupo e origem
-- (própria = empresa dona do pátio, externa = outra empresa)
--
-- POR QUE USAR VIEWS PARA RELATÓRIOS?
--   As tabelas dimensionais e de fatos usam Surrogate Keys (sk_*) para manter
--   a integridade. Para o usuário gerencial final, no entanto, esses IDs não fazem
--   sentido. 
--   Criamos Views que executam os JOINs ligando a fato às dimensões e trazem
--   os nomes legíveis (nomes de pátios, grupos, marcas, etc.), mantendo a 
--   complexidade de modelagem escondida do analista de BI.
-- =============================================================

CREATE OR REPLACE VIEW dw.relatorio_a_controle_patio AS
SELECT
    dp.nome_patio                               AS patio,
    dp.empresa_dona                             AS empresa_dona_patio,
    dgv.nome_grupo                              AS grupo_veiculo,
    dgv.classe_luxo                             AS classe_luxo,
    fps.origem_veiculo                          AS origem,  -- PROPRIA ou EXTERNA
    dt.data_completa                            AS data_snapshot,
    COUNT(*)                                    AS total_veiculos
FROM dw.fato_patio_snapshot fps
JOIN dw.dim_tempo          dt  ON dt.sk_tempo  = fps.sk_tempo
JOIN dw.dim_patio          dp  ON dp.sk_patio  = fps.sk_patio
JOIN dw.dim_veiculo        dv  ON dv.sk_veiculo = fps.sk_veiculo
JOIN dw.dim_grupo_veiculo  dgv ON dgv.sk_grupo  = fps.sk_grupo
GROUP BY dp.nome_patio, dp.empresa_dona, dgv.nome_grupo, dgv.classe_luxo,
         fps.origem_veiculo, dt.data_completa
ORDER BY dp.nome_patio, dgv.nome_grupo, fps.origem_veiculo;

-- Consulta executável — snapshot mais recente por pátio:
SELECT *
FROM dw.relatorio_a_controle_patio
WHERE data_snapshot = (SELECT MAX(data_completa) FROM dw.dim_tempo
                       WHERE sk_tempo IN (SELECT sk_tempo FROM dw.fato_patio_snapshot));


-- =============================================================
-- RELATÓRIO B) Controle das Locações
-- Quantitativo de veículos alugados por grupo, tempo de locação
-- e tempo restante para devolução
-- =============================================================

CREATE OR REPLACE VIEW dw.relatorio_b_controle_locacoes AS
SELECT
    dgv.nome_grupo                                              AS grupo_veiculo,
    dgv.classe_luxo                                             AS classe_luxo,
    fl.status_locacao                                           AS status,
    COUNT(*)                                                    AS total_locacoes,
    AVG(fl.duracao_dias_real)                                   AS media_dias_duracao,
    MAX(fl.duracao_dias_real)                                   AS max_dias,
    MIN(fl.duracao_dias_real)                                   AS min_dias,
    -- Tempo restante previsto (só locações ativas)
    AVG(
        CASE
            WHEN fl.status_locacao = 'EM_ANDAMENTO'
            THEN fl.duracao_dias_prevista - (CURRENT_DATE - dt_ret.data_completa)
            ELSE NULL
        END
    )                                                           AS media_dias_restantes,
    SUM(COALESCE(fl.valor_total, 0))                            AS receita_total
FROM dw.fato_locacao fl
JOIN dw.dim_grupo_veiculo  dgv    ON dgv.sk_grupo     = fl.sk_grupo
JOIN dw.dim_tempo          dt_ret ON dt_ret.sk_tempo  = fl.sk_tempo_retirada
GROUP BY dgv.nome_grupo, dgv.classe_luxo, fl.status_locacao
ORDER BY dgv.nome_grupo, fl.status_locacao;

-- Consulta detalhada por mês:
SELECT
    dt.ano,
    dt.mes,
    dt.nome_mes,
    dgv.nome_grupo,
    COUNT(*)                        AS total_locacoes,
    SUM(fl.duracao_dias_real)       AS total_dias_locados,
    SUM(fl.valor_total)             AS receita_mes
FROM dw.fato_locacao fl
JOIN dw.dim_grupo_veiculo dgv ON dgv.sk_grupo = fl.sk_grupo
JOIN dw.dim_tempo dt          ON dt.sk_tempo  = fl.sk_tempo_retirada
WHERE fl.status_locacao = 'CONCLUIDA'
GROUP BY dt.ano, dt.mes, dt.nome_mes, dgv.nome_grupo
ORDER BY dt.ano, dt.mes, dgv.nome_grupo;


-- =============================================================
-- RELATÓRIO C) Controle de Reservas
-- Quantitativo por grupo, pátio, tempo de retirada futura e
-- cidade de origem dos clientes
-- =============================================================

CREATE OR REPLACE VIEW dw.relatorio_c_controle_reservas AS
SELECT
    dgv.nome_grupo                              AS grupo_veiculo,
    dp.nome_patio                               AS patio_retirada,
    dc.cidade_origem                            AS cidade_cliente,
    dc.uf_origem                                AS uf_cliente,
    dt_ret.ano                                  AS ano_retirada_prevista,
    dt_ret.mes                                  AS mes_retirada_prevista,
    dt_ret.nome_mes                             AS nome_mes_retirada,
    fr.status_reserva                           AS status,
    COUNT(*)                                    AS total_reservas,
    AVG(fr.duracao_prevista_dias)               AS media_duracao_prevista
FROM dw.fato_reserva fr
JOIN dw.dim_grupo_veiculo  dgv    ON dgv.sk_grupo  = fr.sk_grupo
JOIN dw.dim_patio          dp     ON dp.sk_patio   = fr.sk_patio_retirada
JOIN dw.dim_cliente        dc     ON dc.sk_cliente = fr.sk_cliente
JOIN dw.dim_tempo          dt_ret ON dt_ret.sk_tempo = fr.sk_tempo_retirada_prev
GROUP BY dgv.nome_grupo, dp.nome_patio, dc.cidade_origem, dc.uf_origem,
         dt_ret.ano, dt_ret.mes, dt_ret.nome_mes, fr.status_reserva
ORDER BY dt_ret.ano, dt_ret.mes, dgv.nome_grupo, dp.nome_patio;

-- Reservas para a semana seguinte:
SELECT
    dgv.nome_grupo,
    dp.nome_patio,
    dc.cidade_origem,
    COUNT(*) AS reservas_proxima_semana
FROM dw.fato_reserva fr
JOIN dw.dim_grupo_veiculo dgv ON dgv.sk_grupo  = fr.sk_grupo
JOIN dw.dim_patio         dp  ON dp.sk_patio   = fr.sk_patio_retirada
JOIN dw.dim_cliente       dc  ON dc.sk_cliente = fr.sk_cliente
JOIN dw.dim_tempo         dt  ON dt.sk_tempo   = fr.sk_tempo_retirada_prev
WHERE dt.data_completa BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '7 days'
  AND fr.status_reserva NOT IN ('CANCELADA')
GROUP BY dgv.nome_grupo, dp.nome_patio, dc.cidade_origem
ORDER BY reservas_proxima_semana DESC;


-- =============================================================
-- RELATÓRIO D) Grupos de Veículos Mais Alugados × Origem dos Clientes
-- =============================================================

CREATE OR REPLACE VIEW dw.relatorio_d_grupos_por_cidade AS
SELECT
    dc.cidade_origem                            AS cidade_cliente,
    dc.uf_origem                                AS uf_cliente,
    dgv.nome_grupo                              AS grupo_veiculo,
    dgv.classe_luxo                             AS classe_luxo,
    COUNT(*)                                    AS total_locacoes,
    SUM(fl.duracao_dias_real)                   AS total_dias_locados,
    SUM(fl.valor_total)                         AS receita_total,
    ROUND(AVG(fl.valor_total), 2)               AS ticket_medio
FROM dw.fato_locacao fl
JOIN dw.dim_cliente       dc  ON dc.sk_cliente = fl.sk_cliente
JOIN dw.dim_grupo_veiculo dgv ON dgv.sk_grupo  = fl.sk_grupo
WHERE fl.status_locacao = 'CONCLUIDA'
GROUP BY dc.cidade_origem, dc.uf_origem, dgv.nome_grupo, dgv.classe_luxo
ORDER BY total_locacoes DESC;

-- Top 10 combinações cidade × grupo:
SELECT *
FROM dw.relatorio_d_grupos_por_cidade
LIMIT 10;

-- Ranking de grupos mais alugados (consolidado):
SELECT
    dgv.nome_grupo,
    dgv.classe_luxo,
    COUNT(*)                AS total_locacoes,
    SUM(fl.valor_total)     AS receita_total
FROM dw.fato_locacao fl
JOIN dw.dim_grupo_veiculo dgv ON dgv.sk_grupo = fl.sk_grupo
WHERE fl.status_locacao = 'CONCLUIDA'
GROUP BY dgv.nome_grupo, dgv.classe_luxo
ORDER BY total_locacoes DESC;
