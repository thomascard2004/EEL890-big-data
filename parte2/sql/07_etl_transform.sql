-- =============================================================
-- SCRIPT 07 — ETL Transformação
-- =============================================================
-- Grupo:
--   Thomas Cardoso de Miranda       DRE 122050797
--   Thiago Moutinho de Carvalho Maksoud DRE 119048139
--   Yan Lukas Willian Tavares       DRE 124341835
--
-- Disciplina: EEL890 / MAE016 — Big Data e Data Warehouse
-- UFRJ — Instituto de Matemática — DMA
--
-- O QUE FAZ A FASE DE TRANSFORMAÇÃO?
--   Após a extração (scripts 03-06), os dados estão na staging
--   mas ainda estão "sujos" — formatos diferentes entre grupos,
--   campos calculados faltando, e tipos incompatíveis.
--   Este script resolve todos esses problemas ANTES de carregar
--   no DW (script 08), garantindo que o DW receba dados limpos.
--
-- TRANSFORMAÇÕES REALIZADAS:
--   G1: padroniza mecanização, calcula status e durações
--   G2: padroniza texto, calcula km percorridos e durações
--   G3: converte mecanização BOOLEAN→texto, estado_reserva INT→texto,
--       resolve pátio de entrega via Devolucao→Vaga→Patio
--   G4: resolve pátios via IDVaga, calcula durações e status,
--       converte classe de luxo (A/B/C) para texto descritivo
-- =============================================================

-- =============================================================
-- TRANSFORMAÇÕES G1
-- =============================================================

-- PROBLEMA: o OLTP do G1 armazenava mecanização com vários formatos:
--   'AUTO', 'AUTOMÁTICO', 'AUTOMATICA', 'AUTOMATICO', etc.
-- SOLUÇÃO: normalizar tudo para 'AUTOMATICA' ou 'MANUAL'.
-- UPPER+TRIM remove espaços e garante comparação case-insensitive.
UPDATE staging.g1_veiculo
SET mecanizacao = CASE
    WHEN UPPER(TRIM(mecanizacao)) IN ('AUTOMATICO','AUTOMÁTICO','AUTO','AUTOMATICA','AUTOMÁTICA') THEN 'AUTOMATICA'
    ELSE 'MANUAL'
END;

-- Garante que status de reserva seja sempre maiúsculo e sem espaços.
UPDATE staging.g1_reserva
SET status_reserva = UPPER(TRIM(status_reserva));

-- PROBLEMA: o G1 não tinha coluna de status_locacao no OLTP.
-- SOLUÇÃO: inferir o status a partir da data de devolução:
--   → Se data_devolucao_realizada está preenchida: locação CONCLUIDA
--   → Se data_devolucao_realizada é NULL: locação EM_ANDAMENTO
-- ADD COLUMN IF NOT EXISTS evita erro se o script for executado duas vezes.
ALTER TABLE staging.g1_locacao ADD COLUMN IF NOT EXISTS status_conformado VARCHAR(15);
UPDATE staging.g1_locacao
SET status_conformado = CASE
    WHEN data_hora_devolucao_realizada IS NOT NULL THEN 'CONCLUIDA'
    ELSE 'EM_ANDAMENTO'
END;

-- Calcula duração real da locação em dias inteiros (EXTRACT(DAY ...)).
-- NULL para locações ainda em andamento (sem data de devolução).
ALTER TABLE staging.g1_locacao ADD COLUMN IF NOT EXISTS duracao_dias_real INT;
UPDATE staging.g1_locacao
SET duracao_dias_real = CASE
    WHEN data_hora_devolucao_realizada IS NOT NULL
    THEN EXTRACT(DAY FROM (data_hora_devolucao_realizada - data_hora_retirada))::INT
    ELSE NULL
END;

-- Calcula duração prevista (sempre disponível, pois foi acordada na reserva).
ALTER TABLE staging.g1_locacao ADD COLUMN IF NOT EXISTS duracao_dias_prevista INT;
UPDATE staging.g1_locacao
SET duracao_dias_prevista =
    EXTRACT(DAY FROM (data_hora_devolucao_prevista - data_hora_retirada))::INT;

-- =============================================================
-- TRANSFORMAÇÕES G2
-- =============================================================

-- G2 já usa MANUAL/AUTOMATICA, mas pode ter espaços ou caixa mista.
-- UPPER+TRIM garante uniformidade.
UPDATE staging.g2_veiculo
SET mecanizacao = UPPER(TRIM(mecanizacao));

-- Mesma limpeza para classe_luxo dos grupos de veículo.
UPDATE staging.g2_grupo
SET classe_luxo = UPPER(TRIM(classe_luxo));

-- Padronizar status das locações para maiúsculo.
UPDATE staging.g2_locacao
SET status = UPPER(TRIM(status));

-- Calcula duração real em dias para o G2.
ALTER TABLE staging.g2_locacao ADD COLUMN IF NOT EXISTS duracao_dias_real INT;
UPDATE staging.g2_locacao
SET duracao_dias_real = CASE
    WHEN data_devolucao_real IS NOT NULL
    THEN EXTRACT(DAY FROM (data_devolucao_real - data_retirada_real))::INT
    ELSE NULL
END;

-- Calcula duração prevista para o G2, buscando datas na tabela de reservas
-- via JOIN (a locação G2 não armazena as datas previstas diretamente).
ALTER TABLE staging.g2_locacao ADD COLUMN IF NOT EXISTS duracao_dias_prevista INT;
UPDATE staging.g2_locacao
SET duracao_dias_prevista =
    EXTRACT(DAY FROM (data_devolucao_prevista - data_retirada_prevista))::INT
FROM staging.g2_reserva r
WHERE staging.g2_locacao.reserva_id = r.id_reserva;

-- EXCLUSIVO DO G2: calcula km percorridos = km_chegada - km_saida.
-- NULL se qualquer um dos campos estiver faltando.
ALTER TABLE staging.g2_locacao ADD COLUMN IF NOT EXISTS km_percorridos INT;
UPDATE staging.g2_locacao
SET km_percorridos = CASE
    WHEN km_chegada IS NOT NULL AND km_saida IS NOT NULL
    THEN km_chegada - km_saida
    ELSE NULL
END;

-- =============================================================
-- TRANSFORMAÇÕES G3
-- =============================================================

-- PROBLEMA: G3 armazenava mecanização como BOOLEAN (MySQL: 1/0).
-- SOLUÇÃO: converter TRUE → 'AUTOMATICA', FALSE → 'MANUAL'.
-- Adicionamos nova coluna 'mecanizacao_conf' para não sobrescrever
-- o BOOLEAN original (boa prática de auditoria).
ALTER TABLE staging.g3_veiculo ADD COLUMN IF NOT EXISTS mecanizacao_conf VARCHAR(15);
UPDATE staging.g3_veiculo
SET mecanizacao_conf = CASE
    WHEN direcao_auto = TRUE THEN 'AUTOMATICA'
    ELSE 'MANUAL'
END;

-- PROBLEMA: G3 armazenava estado_reserva como INT (0, 1, 2).
-- SOLUÇÃO: mapear para texto descritivo usado em todo o DW.
ALTER TABLE staging.g3_reserva ADD COLUMN IF NOT EXISTS status_conformado VARCHAR(25);
UPDATE staging.g3_reserva
SET status_conformado = CASE
    WHEN estado_reserva = 0 THEN 'EM_ANDAMENTO'
    WHEN estado_reserva = 1 THEN 'CANCELADA'
    WHEN estado_reserva = 2 THEN 'CONFIRMADA'
    ELSE 'DESCONHECIDO'
END;

-- Calcula duração prevista das reservas G3 a partir das datas combinadas.
ALTER TABLE staging.g3_reserva ADD COLUMN IF NOT EXISTS duracao_prevista_dias INT;
UPDATE staging.g3_reserva
SET duracao_prevista_dias =
    EXTRACT(DAY FROM (data_fim_combinada - data_inicio_combinada))::INT;

-- PROBLEMA COMPLEXO DO G3: a tabela Locacao não registra o pátio de entrega.
-- O pátio de entrega está em: Devolucao.id_vaga → Vaga.id_patio
-- SOLUÇÃO: subconsulta correlacionada que percorre essa cadeia para cada locação.
-- LIMIT 1 garante que pegamos apenas uma devolução por locação.
ALTER TABLE staging.g3_locacao ADD COLUMN IF NOT EXISTS id_patio_entrega INT;
UPDATE staging.g3_locacao l
SET id_patio_entrega = (
    SELECT v.id_patio
    FROM staging.g3_devolucao d
    JOIN staging.g3_vaga v ON v.id_vaga = d.id_vaga
    WHERE d.id_locacao = l.id_locacao
    LIMIT 1
);

-- Busca também a data de devolução para calcular status e duração real.
ALTER TABLE staging.g3_locacao ADD COLUMN IF NOT EXISTS data_devolucao TIMESTAMP;
UPDATE staging.g3_locacao l
SET data_devolucao = (
    SELECT d.data_devolucao
    FROM staging.g3_devolucao d
    WHERE d.id_locacao = l.id_locacao
    LIMIT 1
);

-- Infere status com a mesma lógica do G1: NULL em data_devolucao = ativa.
ALTER TABLE staging.g3_locacao ADD COLUMN IF NOT EXISTS status_conformado VARCHAR(15);
UPDATE staging.g3_locacao
SET status_conformado = CASE
    WHEN data_devolucao IS NOT NULL THEN 'CONCLUIDA'
    ELSE 'EM_ANDAMENTO'
END;

-- =============================================================
-- TRANSFORMAÇÕES G4
-- =============================================================

-- PROBLEMA IGUAL AO G3: G4 não registra pátio diretamente, usa id_vaga.
-- SOLUÇÃO: subconsulta em g4_vaga para obter o pátio de RETIRADA.
ALTER TABLE staging.g4_locacao ADD COLUMN IF NOT EXISTS id_patio_retirada INT;
UPDATE staging.g4_locacao l
SET id_patio_retirada = (
    SELECT v.id_patio
    FROM staging.g4_vaga v
    WHERE v.id_vaga = l.id_vaga_retirada
    LIMIT 1
);

-- Mesma lógica para o pátio de ENTREGA (devolução).
ALTER TABLE staging.g4_locacao ADD COLUMN IF NOT EXISTS id_patio_entrega INT;
UPDATE staging.g4_locacao l
SET id_patio_entrega = (
    SELECT v.id_patio
    FROM staging.g4_vaga v
    WHERE v.id_vaga = l.id_vaga_devolvida
    LIMIT 1
);

-- Calcula duração real em dias para o G4.
ALTER TABLE staging.g4_locacao ADD COLUMN IF NOT EXISTS duracao_dias_real INT;
UPDATE staging.g4_locacao
SET duracao_dias_real = CASE
    WHEN dt_chegada IS NOT NULL
    THEN EXTRACT(DAY FROM (dt_chegada - dt_retirada))::INT
    ELSE NULL
END;

-- Infere status da locação G4.
ALTER TABLE staging.g4_locacao ADD COLUMN IF NOT EXISTS status_conformado VARCHAR(15);
UPDATE staging.g4_locacao
SET status_conformado = CASE
    WHEN dt_chegada IS NOT NULL THEN 'CONCLUIDA'
    ELSE 'EM_ANDAMENTO'
END;

-- PROBLEMA: G4 usa letras para classe de luxo ('A','B','C').
-- SOLUÇÃO: mapear para os rótulos textuais conformados do DW.
ALTER TABLE staging.g4_categoria ADD COLUMN IF NOT EXISTS classe_luxo_conf VARCHAR(50);
UPDATE staging.g4_categoria
SET classe_luxo_conf = CASE
    WHEN classe_luxo = 'A' THEN 'BASICO'
    WHEN classe_luxo = 'B' THEN 'INTERMEDIARIO'
    WHEN classe_luxo = 'C' THEN 'LUXO'
    ELSE 'DESCONHECIDO'
END;

-- =============================================================
-- LIMPEZA FINAL: TRIM e UPPER em campos de texto geográfico
-- Garante que 'rio de janeiro', 'Rio De Janeiro' e 'RIO DE JANEIRO'
-- sejam tratados como o mesmo valor nos relatórios por cidade.
-- =============================================================
UPDATE staging.g1_patio SET nome_localizacao = TRIM(nome_localizacao);
UPDATE staging.g2_patio SET nome = UPPER(TRIM(nome));
UPDATE staging.g2_cliente SET cidade_origem = UPPER(TRIM(cidade_origem));
UPDATE staging.g3_patio SET cidade = UPPER(TRIM(cidade)), uf = UPPER(TRIM(uf));
UPDATE staging.g3_cliente SET cidade = UPPER(TRIM(cidade)), uf = UPPER(TRIM(uf));
UPDATE staging.g4_patio SET cidade = UPPER(TRIM(cidade)), uf = UPPER(TRIM(uf));
UPDATE staging.g4_motorista SET cidade = UPPER(TRIM(cidade)), uf = UPPER(TRIM(uf));
