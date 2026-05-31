-- =============================================================
-- SCRIPT 02 — Esquema Estrela do Data Warehouse (Star Schema)
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
--   Cada dimensão usa um ID sintético (SERIAL / auto-incremento)
--   como chave primária, independente do ID original do OLTP.
--   Isso permite integrar dados de múltiplas fontes sem conflito
--   de IDs e protege o DW de mudanças nos sistemas de origem.
--
-- GRANULARIDADE dos fatos:
--   fato_locacao     → 1 linha por locação (ativa ou concluída)
--   fato_reserva     → 1 linha por reserva cadastrada
--   fato_patio_snapshot → 1 linha por veículo × pátio × dia
-- =============================================================

-- Remove e recria o schema dw do zero.
DROP SCHEMA IF EXISTS dw CASCADE;
CREATE SCHEMA dw;

-- =============================================================
-- DIMENSÕES
-- As dimensões respondem às perguntas: QUEM? QUANDO? ONDE? O QUÊ?
-- =============================================================

-- -------------------------------------------------------------
-- dim_tempo: QUANDO? — hierarquia temporal completa
-- Pré-populada com todos os dias de 2020 a 2030 (script 08).
-- Permite análise por dia, semana, mês, trimestre, semestre e ano.
-- Necessária para os Relatórios B (tempo de locação) e C (reservas futuras).
-- -------------------------------------------------------------
CREATE TABLE dw.dim_tempo (
    sk_tempo        SERIAL PRIMARY KEY,
    data_completa   DATE        NOT NULL UNIQUE,   -- chave natural usada nos JOINs com staging
    dia             INT         NOT NULL,
    mes             INT         NOT NULL,
    trimestre       INT         NOT NULL,
    semestre        INT         NOT NULL,
    ano             INT         NOT NULL,
    num_semana_ano  INT         NOT NULL,           -- semana ISO (1–53)
    dia_semana_num  INT         NOT NULL,           -- 1=Domingo ... 7=Sábado
    dia_semana_nome VARCHAR(15) NOT NULL,
    nome_mes        VARCHAR(15) NOT NULL,
    eh_fim_semana   BOOLEAN     NOT NULL            -- TRUE para sábados e domingos
);

-- -------------------------------------------------------------
-- dim_patio: ONDE? — os 6 pátios compartilhados
-- 'empresa_dona' é usada no Relatório A para classificar se um
-- veículo é 'PROPRIA' (pertence à empresa dona do pátio)
-- ou 'EXTERNA' (pertence a uma das outras 5 empresas parceiras).
-- 'fonte_grupo' garante que IDs de pátio de grupos diferentes
-- não sejam confundidos (G1 pode ter id_patio=1 e G2 também).
-- -------------------------------------------------------------
CREATE TABLE dw.dim_patio (
    sk_patio        SERIAL PRIMARY KEY,
    id_patio_orig   INT         NOT NULL,           -- PK no OLTP de origem
    nome_patio      VARCHAR(100) NOT NULL,
    empresa_dona    VARCHAR(100) NOT NULL,           -- empresa proprietária do espaço físico
    cidade          VARCHAR(100),
    uf              CHAR(2),
    fonte_grupo     VARCHAR(5)  NOT NULL,            -- 'G1','G2','G3','G4'
    dt_carga        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- -------------------------------------------------------------
-- dim_empresa: as 6 locadoras do consórcio
-- Usada no Relatório A para comparar a empresa do veículo
-- com a empresa dona do pátio onde ele está estacionado.
-- -------------------------------------------------------------
CREATE TABLE dw.dim_empresa (
    sk_empresa      SERIAL PRIMARY KEY,
    id_empresa_orig INT,
    nome_empresa    VARCHAR(150) NOT NULL,
    cnpj            VARCHAR(14),
    fonte_grupo     VARCHAR(5)  NOT NULL,
    dt_carga        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- -------------------------------------------------------------
-- dim_grupo_veiculo: O QUÊ? — categorias comerciais dos veículos
-- Todos os 4 relatórios gerenciais exigem agrupamento por grupo.
-- Ex: Econômico, SUV, Luxo, etc.
-- -------------------------------------------------------------
CREATE TABLE dw.dim_grupo_veiculo (
    sk_grupo        SERIAL PRIMARY KEY,
    id_grupo_orig   INT         NOT NULL,
    codigo_grupo    VARCHAR(20),                    -- código alfanumérico da categoria
    nome_grupo      VARCHAR(100) NOT NULL,
    classe_luxo     VARCHAR(50),                    -- BASICO / INTERMEDIARIO / LUXO
    valor_diaria    DECIMAL(10,2),
    fonte_grupo     VARCHAR(5)  NOT NULL,
    dt_carga        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- -------------------------------------------------------------
-- dim_veiculo: a frota física de todos os grupos
-- Vincula cada locação a um veículo específico para rastrear
-- a movimentação individual entre pátios (base da Cadeia de Markov).
-- mecanizacao é conformada: apenas 'MANUAL' ou 'AUTOMATICA'.
-- -------------------------------------------------------------
CREATE TABLE dw.dim_veiculo (
    sk_veiculo          SERIAL PRIMARY KEY,
    id_veiculo_orig     INT         NOT NULL,       -- ID no OLTP de origem
    placa               VARCHAR(10),
    chassi              VARCHAR(17),
    marca               VARCHAR(60),
    modelo              VARCHAR(60),
    ano_fabricacao      INT,
    cor                 VARCHAR(40),
    mecanizacao         VARCHAR(20),               -- MANUAL ou AUTOMATICA (conformado)
    ar_condicionado     BOOLEAN,
    sk_grupo            INT NOT NULL REFERENCES dw.dim_grupo_veiculo(sk_grupo),
    sk_empresa_origem   INT REFERENCES dw.dim_empresa(sk_empresa),
    fonte_grupo         VARCHAR(5)  NOT NULL,
    dt_carga            TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- -------------------------------------------------------------
-- dim_cliente: QUEM? — clientes PF e PJ de todas as empresas
-- 'cidade_origem' e 'uf_origem' são essenciais para os
-- Relatórios C (reservas por cidade) e D (grupos × cidade).
-- G1 não fornece cidade_origem → preenchida com 'NAO_INFORMADO'.
-- -------------------------------------------------------------
CREATE TABLE dw.dim_cliente (
    sk_cliente      SERIAL PRIMARY KEY,
    id_cliente_orig INT         NOT NULL,
    nome            VARCHAR(200) NOT NULL,
    tipo_pessoa     CHAR(2),                        -- 'PF' ou 'PJ'
    cpf_cnpj        VARCHAR(14),
    cidade_origem   VARCHAR(100),
    uf_origem       CHAR(2),
    nacionalidade   VARCHAR(60),
    fonte_grupo     VARCHAR(5)  NOT NULL,
    dt_carga        TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================
-- TABELAS DE FATOS
-- As fatos armazenam as métricas (números) que serão analisadas.
-- Cada coluna sk_* é uma FK para uma dimensão.
-- =============================================================

-- -------------------------------------------------------------
-- fato_locacao: fato central — cada linha = 1 locação
-- É a tabela mais importante do DW. Suporta:
--   Relatório A: pátio de entrega vs empresa do veículo
--   Relatório B: duração, valor e status das locações
--   Relatório D: grupos x cidade de origem do cliente
--   Cadeia de Markov: par (sk_patio_retirada, sk_patio_entrega)
--
-- sk_tempo_devolucao e sk_patio_entrega podem ser NULL
-- para locações ainda em andamento.
-- -------------------------------------------------------------
CREATE TABLE dw.fato_locacao (
    sk_locacao              SERIAL PRIMARY KEY,
    id_locacao_orig         INT         NOT NULL,

    -- Dimensão temporal: QUANDO foi retirado e devolvido?
    sk_tempo_retirada       INT NOT NULL REFERENCES dw.dim_tempo(sk_tempo),
    sk_tempo_devolucao      INT REFERENCES dw.dim_tempo(sk_tempo),  -- NULL se ativa

    -- Dimensão quem: QUEM alugou?
    sk_cliente              INT NOT NULL REFERENCES dw.dim_cliente(sk_cliente),

    -- Dimensão o quê: QUAL veículo e grupo?
    sk_veiculo              INT NOT NULL REFERENCES dw.dim_veiculo(sk_veiculo),
    sk_grupo                INT NOT NULL REFERENCES dw.dim_grupo_veiculo(sk_grupo),

    -- Dimensão onde: ONDE saiu e ONDE chegou?
    sk_patio_retirada       INT NOT NULL REFERENCES dw.dim_patio(sk_patio),
    sk_patio_entrega        INT REFERENCES dw.dim_patio(sk_patio),  -- NULL se ativa

    -- Dimensão empresa: de qual empresa é o veículo?
    sk_empresa_veiculo      INT REFERENCES dw.dim_empresa(sk_empresa),

    -- MÉTRICAS (os "fatos" propriamente ditos):
    duracao_dias_prevista   INT,            -- dias previstos no contrato
    duracao_dias_real       INT,            -- dias reais (NULL se ativa)
    valor_diaria            DECIMAL(10,2),
    valor_total             DECIMAL(10,2),  -- receita bruta da locação
    km_percorridos          INT,            -- km_chegada - km_saida (quando disponível)

    -- INDICADORES derivados:
    -- TRUE quando o carro foi devolvido em pátio diferente do de retirada
    locacao_intercompanhia  BOOLEAN NOT NULL DEFAULT FALSE,
    status_locacao          VARCHAR(15),    -- 'EM_ANDAMENTO' ou 'CONCLUIDA'

    fonte_grupo             VARCHAR(5)  NOT NULL,
    dt_carga                TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- -------------------------------------------------------------
-- fato_reserva: cada linha = 1 reserva cadastrada
-- Suporta o Relatório C (quantitativo de reservas por grupo,
-- pátio de retirada futuro e cidade de origem do cliente).
-- Permite planejar demanda futura de veículos por pátio.
-- -------------------------------------------------------------
CREATE TABLE dw.fato_reserva (
    sk_reserva              SERIAL PRIMARY KEY,
    id_reserva_orig         INT         NOT NULL,

    -- Três pontos temporais: quando foi feita, quando retira, quando devolve
    sk_tempo_solicitacao    INT NOT NULL REFERENCES dw.dim_tempo(sk_tempo),
    sk_tempo_retirada_prev  INT NOT NULL REFERENCES dw.dim_tempo(sk_tempo),
    sk_tempo_devolucao_prev INT NOT NULL REFERENCES dw.dim_tempo(sk_tempo),

    sk_cliente              INT NOT NULL REFERENCES dw.dim_cliente(sk_cliente),
    sk_grupo                INT NOT NULL REFERENCES dw.dim_grupo_veiculo(sk_grupo),
    sk_patio_retirada       INT NOT NULL REFERENCES dw.dim_patio(sk_patio),
    sk_patio_devolucao      INT REFERENCES dw.dim_patio(sk_patio),

    -- MÉTRICA: quantos dias o cliente planeja ficar com o carro
    duracao_prevista_dias   INT,
    status_reserva          VARCHAR(25),   -- 'EM_ANDAMENTO','CONFIRMADA','CANCELADA'

    fonte_grupo             VARCHAR(5)  NOT NULL,
    dt_carga                TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- -------------------------------------------------------------
-- fato_patio_snapshot: estado diário do pátio
-- Granularidade: 1 linha por veículo × pátio × dia
-- Suporta o Relatório A (controle de pátio: quantos veículos,
-- de quais grupos, e se são da própria empresa ou de parceiras).
-- Diferente de fato_locacao (que registra eventos),
-- este snapshot registra o ESTADO dos pátios a cada dia.
-- -------------------------------------------------------------
CREATE TABLE dw.fato_patio_snapshot (
    sk_snapshot         SERIAL PRIMARY KEY,

    sk_tempo            INT NOT NULL REFERENCES dw.dim_tempo(sk_tempo),
    sk_patio            INT NOT NULL REFERENCES dw.dim_patio(sk_patio),
    sk_veiculo          INT NOT NULL REFERENCES dw.dim_veiculo(sk_veiculo),
    sk_grupo            INT NOT NULL REFERENCES dw.dim_grupo_veiculo(sk_grupo),
    sk_empresa_veiculo  INT REFERENCES dw.dim_empresa(sk_empresa),

    -- 'PROPRIA': o carro pertence à empresa dona do pátio
    -- 'EXTERNA': o carro pertence a uma das outras 5 empresas parceiras
    origem_veiculo      VARCHAR(10) NOT NULL CHECK (origem_veiculo IN ('PROPRIA','EXTERNA')),

    fonte_grupo         VARCHAR(5)  NOT NULL,
    dt_carga            TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================
-- ÍNDICES DE PERFORMANCE
-- Acelerando as consultas analíticas mais frequentes.
-- Sem índices, cada relatório faria full scan nas tabelas de fatos.
-- =============================================================

-- Índices na fato_locacao (tabela mais consultada)
CREATE INDEX ix_fl_tempo_ret  ON dw.fato_locacao(sk_tempo_retirada);
CREATE INDEX ix_fl_tempo_dev  ON dw.fato_locacao(sk_tempo_devolucao);
CREATE INDEX ix_fl_cliente    ON dw.fato_locacao(sk_cliente);
CREATE INDEX ix_fl_veiculo    ON dw.fato_locacao(sk_veiculo);
CREATE INDEX ix_fl_grupo      ON dw.fato_locacao(sk_grupo);
CREATE INDEX ix_fl_patio_ret  ON dw.fato_locacao(sk_patio_retirada);
CREATE INDEX ix_fl_patio_ent  ON dw.fato_locacao(sk_patio_entrega);
CREATE INDEX ix_fl_status     ON dw.fato_locacao(status_locacao);  -- filtrado em quase todo relatório

-- Índices na fato_reserva
CREATE INDEX ix_fr_tempo_sol  ON dw.fato_reserva(sk_tempo_solicitacao);
CREATE INDEX ix_fr_cliente    ON dw.fato_reserva(sk_cliente);
CREATE INDEX ix_fr_grupo      ON dw.fato_reserva(sk_grupo);
CREATE INDEX ix_fr_patio_ret  ON dw.fato_reserva(sk_patio_retirada);

-- Índices no snapshot diário de pátio
CREATE INDEX ix_fps_tempo     ON dw.fato_patio_snapshot(sk_tempo);
CREATE INDEX ix_fps_patio     ON dw.fato_patio_snapshot(sk_patio);
CREATE INDEX ix_fps_grupo     ON dw.fato_patio_snapshot(sk_grupo);
