-- =============================================================
-- SCRIPT 10 — Matriz de Percentuais de Movimentação entre Pátios
--             (Cadeia de Markov)
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
--:
--   Calcula a matriz estocástica de movimentação da frota
--   entre os 6 pátios. Para cada pátio de origem, calcula
--   o percentual de veículos que retornam ao mesmo pátio
--   ou são entregues em cada um dos outros pátios.
--
--     Contar todas as locações CONCLUÍDAS com
--     (patio_retirada, patio_entrega) como par ordenado.
--     Para cada pátio de retirada P_i, calcular:
--       P(ir para P_j | saiu de P_i) = count(P_i → P_j) / count(saiu de P_i)
--
-- =============================================================
-- PASSO 1: Contagem bruta de transições (patio_ret → patio_ent)
-- =============================================================
CREATE OR REPLACE VIEW dw.markov_contagem_transicoes AS
SELECT
    dp_ret.nome_patio   AS patio_origem,
    dp_ent.nome_patio   AS patio_destino,
    COUNT(*)            AS total_transicoes
FROM dw.fato_locacao fl
JOIN dw.dim_patio dp_ret ON dp_ret.sk_patio = fl.sk_patio_retirada
JOIN dw.dim_patio dp_ent ON dp_ent.sk_patio = fl.sk_patio_entrega
WHERE fl.status_locacao = 'CONCLUIDA'
  AND fl.sk_patio_entrega IS NOT NULL
GROUP BY dp_ret.nome_patio, dp_ent.nome_patio
ORDER BY dp_ret.nome_patio, dp_ent.nome_patio;

-- =============================================================
-- PASSO 2: Total de saídas por pátio de origem
-- =============================================================
CREATE OR REPLACE VIEW dw.markov_total_saidas AS
SELECT
    dp_ret.nome_patio   AS patio_origem,
    COUNT(*)            AS total_saidas
FROM dw.fato_locacao fl
JOIN dw.dim_patio dp_ret ON dp_ret.sk_patio = fl.sk_patio_retirada
WHERE fl.status_locacao = 'CONCLUIDA'
  AND fl.sk_patio_entrega IS NOT NULL
GROUP BY dp_ret.nome_patio;

-- =============================================================
-- PASSO 3: Matriz de probabilidades (percentuais)
-- Esta é a Matriz de Transição de Markov propriamente dita.
-- Cada linha representa um pátio de origem.
-- Cada coluna representa um pátio de destino.
-- O valor é P(destino | origem) = total_transicoes / total_saidas
-- =============================================================
CREATE OR REPLACE VIEW dw.markov_matriz_percentuais AS
SELECT
    t.patio_origem,
    t.patio_destino,
    t.total_transicoes,
    s.total_saidas,
    ROUND(
        t.total_transicoes::NUMERIC / NULLIF(s.total_saidas, 0) * 100,
        2
    )                   AS percentual,
    ROUND(
        t.total_transicoes::NUMERIC / NULLIF(s.total_saidas, 0),
        4
    )                   AS probabilidade
FROM dw.markov_contagem_transicoes t
JOIN dw.markov_total_saidas s ON s.patio_origem = t.patio_origem
ORDER BY t.patio_origem, t.patio_destino;

-- =============================================================
-- PASSO 4: Formato de Matriz Pivotada (crosstab)
--          Os 6 pátios são: Galeão, Santos Dumont, Rodoviária,
--          Rio Sul, Nova América, Barra Shopping
-- =============================================================

-- Exibe a matriz como relatório tabular
SELECT * FROM dw.markov_matriz_percentuais;

-- Versão pivotada usando crosstab (requer extensão tablefunc)
-- Instale com: CREATE EXTENSION IF NOT EXISTS tablefunc;
CREATE EXTENSION IF NOT EXISTS tablefunc;

-- Consulta pivotada: cada linha = origem, colunas = destinos
SELECT *
FROM crosstab(
    -- Query 1: dados ordenados (origem, destino, percentual)
    $$
    SELECT
        patio_origem,
        patio_destino,
        probabilidade
    FROM dw.markov_matriz_percentuais
    ORDER BY 1, 2
    $$,
    -- Query 2: lista dos destinos (colunas)
    $$
    SELECT DISTINCT nome_patio
    FROM dw.dim_patio
    ORDER BY 1
    $$
) AS matriz (
    patio_origem    TEXT,
    "Aeroporto Galeão"      NUMERIC,
    "Aeroporto Santos Dumont" NUMERIC,
    "Barra Shopping"        NUMERIC,
    "Nova América"          NUMERIC,
    "Rio Sul"               NUMERIC,
    "Rodoviária Novo Rio"   NUMERIC
);

-- =============================================================
-- PASSO 5: Verificação — cada linha deve somar 1.0 (100%)
-- =============================================================
SELECT
    patio_origem,
    ROUND(SUM(probabilidade), 4) AS soma_probabilidades,
    CASE
        WHEN ABS(SUM(probabilidade) - 1.0) < 0.001 THEN 'OK ✓'
        ELSE 'ERRO — linha não soma 1'
    END AS validacao
FROM dw.markov_matriz_percentuais
GROUP BY patio_origem
ORDER BY patio_origem;

-- =============================================================
-- =============================================================
-- PASSO 6: Análise de estado estacionário
-- O vetor estacionário π satisfaz: π = π × P
-- (cálculo iterativo, aqui 10 iterações de aproximação)
-- Interpretação: percentual de veículos em cada pátio no
-- equilíbrio de longo prazo.
-- =============================================================
WITH 
-- Vetor inicial uniforme: 1/6 para cada pátio
estado_inicial AS (
    SELECT nome_patio AS patio, 1.0/6 AS prob
    FROM dw.dim_patio
    GROUP BY nome_patio
),
-- Matriz de transição
matriz AS (
    SELECT patio_origem, patio_destino, probabilidade
    FROM dw.markov_matriz_percentuais
),
-- Iterações de transição (multiplicação de matrizes: V_nova = V_antiga * P)
iter1 AS (
    SELECT m.patio_destino AS patio, SUM(e.prob * m.probabilidade) AS prob
    FROM estado_inicial e JOIN matriz m ON m.patio_origem = e.patio GROUP BY m.patio_destino
),
iter2 AS (
    SELECT m.patio_destino AS patio, SUM(e.prob * m.probabilidade) AS prob
    FROM iter1 e JOIN matriz m ON m.patio_origem = e.patio GROUP BY m.patio_destino
),
iter3 AS (
    SELECT m.patio_destino AS patio, SUM(e.prob * m.probabilidade) AS prob
    FROM iter2 e JOIN matriz m ON m.patio_origem = e.patio GROUP BY m.patio_destino
),
iter4 AS (
    SELECT m.patio_destino AS patio, SUM(e.prob * m.probabilidade) AS prob
    FROM iter3 e JOIN matriz m ON m.patio_origem = e.patio GROUP BY m.patio_destino
),
iter5 AS (
    SELECT m.patio_destino AS patio, SUM(e.prob * m.probabilidade) AS prob
    FROM iter4 e JOIN matriz m ON m.patio_origem = e.patio GROUP BY m.patio_destino
),
iter6 AS (
    SELECT m.patio_destino AS patio, SUM(e.prob * m.probabilidade) AS prob
    FROM iter5 e JOIN matriz m ON m.patio_origem = e.patio GROUP BY m.patio_destino
),
iter7 AS (
    SELECT m.patio_destino AS patio, SUM(e.prob * m.probabilidade) AS prob
    FROM iter6 e JOIN matriz m ON m.patio_origem = e.patio GROUP BY m.patio_destino
),
iter8 AS (
    SELECT m.patio_destino AS patio, SUM(e.prob * m.probabilidade) AS prob
    FROM iter7 e JOIN matriz m ON m.patio_origem = e.patio GROUP BY m.patio_destino
),
iter9 AS (
    SELECT m.patio_destino AS patio, SUM(e.prob * m.probabilidade) AS prob
    FROM iter8 e JOIN matriz m ON m.patio_origem = e.patio GROUP BY m.patio_destino
),
iter10 AS (
    SELECT m.patio_destino AS patio, SUM(e.prob * m.probabilidade) AS prob
    FROM iter9 e JOIN matriz m ON m.patio_origem = e.patio GROUP BY m.patio_destino
)
SELECT
    patio                       AS patio,
    ROUND(prob * 100, 2)        AS percentual_equilibrio
FROM iter10
ORDER BY percentual_equilibrio DESC;
