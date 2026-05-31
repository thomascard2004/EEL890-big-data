-- =============================================================
-- SCRIPT 01 — Criação da Área de Staging (Área de Transição)
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
-- FREQUÊNCIA DE EXTRAÇÃO:
--   Clientes / Veículos  → Diária às 02:00 / 02:30
--   Pátios/Vagas         → Semanal, domingo às 03:00
--   Reservas             → A cada 6h (00:00, 06:00, 12:00, 18:00)
--   Locações ativas      → A cada 6h (01:00, 07:00, 13:00, 19:00)
--   Locações fechadas    → Diária às 03:00
-- =============================================================

-- Remove e recria o schema do zero.
-- CASCADE remove todas as tabelas filhas automaticamente.
DROP SCHEMA IF EXISTS staging CASCADE;
CREATE SCHEMA staging;

-- =============================================
-- G1 — Nosso grupo (ANSI SQL / PostgreSQL)
-- =============================================

-- Pátios: empresa_dona distingue frota própria x externa (Rel. A)
CREATE TABLE staging.g1_patio (
    id_patio            INT,
    nome_localizacao    VARCHAR(100),
    capacidade_vagas    INT,
    empresa_dona        VARCHAR(100),
    dt_extracao         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Grupos de veículos (categorias comerciais com preço de diária)
CREATE TABLE staging.g1_grupo_veiculo (
    id_grupo        INT,
    nome_categoria  VARCHAR(50),
    classe_luxo     VARCHAR(50),
    valor_diaria    DECIMAL(10,2),
    dt_extracao     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Frota. 'mecanizacao' vem em formatos variados (AUTO, AUTOMÁTICO...)
-- e será padronizado para MANUAL/AUTOMATICA no script 07.
CREATE TABLE staging.g1_veiculo (
    id_veiculo              INT,
    id_grupo                INT,
    placa                   VARCHAR(10),
    chassi                  VARCHAR(50),
    marca                   VARCHAR(50),
    modelo                  VARCHAR(50),
    cor                     VARCHAR(30),
    ar_condicionado         BOOLEAN,
    mecanizacao             VARCHAR(20),   -- conformado no script 07
    status_disponibilidade  VARCHAR(20),
    dt_extracao             TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Clientes. G1 não tem cidade de origem → o ETL usará 'NAO_INFORMADO'.
CREATE TABLE staging.g1_cliente (
    id_cliente          INT,
    tipo_cliente        CHAR(2),           -- 'PF' ou 'PJ'
    nome_razao_social   VARCHAR(150),
    cpf_cnpj            VARCHAR(20),
    endereco_completo   TEXT,
    dt_extracao         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE staging.g1_reserva (
    id_reserva                  INT,
    id_cliente                  INT,
    id_grupo                    INT,
    id_patio_retirada           INT,
    data_hora_solicitacao       TIMESTAMP,
    data_hora_retirada_prevista TIMESTAMP,
    data_hora_devolucao_prevista TIMESTAMP,
    status_reserva              VARCHAR(20),
    dt_extracao                 TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Locações. O par (id_patio_saida, id_patio_chegada_realizada)
-- alimenta a Matriz de Markov. NULL em devolucao_realizada = ativa.
CREATE TABLE staging.g1_locacao (
    id_locacao                      INT,
    id_reserva                      INT,
    id_veiculo                      INT,
    id_patio_saida                  INT,
    id_patio_chegada_prevista       INT,
    id_patio_chegada_realizada      INT,   -- destino real (pode diferir do previsto)
    data_hora_retirada              TIMESTAMP,
    data_hora_devolucao_prevista    TIMESTAMP,
    data_hora_devolucao_realizada   TIMESTAMP, -- NULL se ativa
    valor_inicial                   DECIMAL(10,2),
    valor_final                     DECIMAL(10,2),
    dt_extracao                     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- G2 — gupessanha (PostgreSQL)
-- Destaque: clientes PF/PJ em tabelas separadas (herança);
--           campo franquia_km_diaria exclusivo deste grupo.
-- =============================================

CREATE TABLE staging.g2_patio (
    id_patio            INT,
    nome                VARCHAR(100),
    endereco            VARCHAR(200),
    capacidade_vagas    INT,
    dt_extracao         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- franquia_km_diaria: km inclusos por diária sem custo extra (só G2)
CREATE TABLE staging.g2_grupo (
    id_grupo            INT,
    codigo              VARCHAR(10),
    nome                VARCHAR(50),
    classe_luxo         VARCHAR(20),
    valor_diaria        NUMERIC(10,2),
    franquia_km_diaria  INT,
    dt_extracao         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE staging.g2_veiculo (
    id_veiculo          INT,
    grupo_id            INT,
    patio_origem_id     INT,              -- pátio base do veículo
    placa               VARCHAR(8),
    chassi              VARCHAR(17),
    marca               VARCHAR(30),
    modelo              VARCHAR(50),
    cor                 VARCHAR(20),
    ano_fabricacao      INT,
    mecanizacao         VARCHAR(10),
    tem_ar_condicionado BOOLEAN,
    km_atual            INT,
    situacao            VARCHAR(15),
    dt_extracao         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- DESNORMALIZADO: PF e PJ unificados aqui. No OLTP de origem estavam
-- em tabelas separadas (cliente_pf e cliente_pj). Apenas um de
-- cpf/cnpj estará preenchido conforme tipo_pessoa.
CREATE TABLE staging.g2_cliente (
    id_cliente      INT,
    tipo_pessoa     VARCHAR(2),
    nome            VARCHAR(150),
    email           VARCHAR(150),
    telefone        VARCHAR(20),
    cidade_origem   VARCHAR(80),
    cpf             VARCHAR(11),    -- preenchido só para PF
    data_nascimento DATE,           -- preenchido só para PF
    cnpj            VARCHAR(14),    -- preenchido só para PJ
    dt_extracao     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE staging.g2_reserva (
    id_reserva              INT,
    cliente_id              INT,
    grupo_id                INT,
    patio_retirada_id       INT,
    patio_devolucao_id      INT,
    data_reserva            TIMESTAMP,
    data_retirada_prevista  TIMESTAMP,
    data_devolucao_prevista TIMESTAMP,
    estado                  VARCHAR(20),
    dt_extracao             TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- km_saida e km_chegada permitem calcular km_percorridos no script 07.
CREATE TABLE staging.g2_locacao (
    id_locacao              INT,
    reserva_id              INT,
    cliente_id              INT,
    veiculo_id              INT,
    patio_retirada_id       INT,
    patio_devolucao_id      INT,
    data_retirada_real      TIMESTAMP,
    data_devolucao_real     TIMESTAMP,
    km_saida                INT,
    km_chegada              INT,
    valor_diaria_aplicada   NUMERIC(10,2),
    status                  VARCHAR(15),
    dt_extracao             TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- G3 — guilherme-hu (MySQL 8 → PostgreSQL)
-- Destaque: 18 tabelas, mecanização é BOOLEAN,
--           pátio de entrega resolvido via Devolucao→Vaga→Patio.
-- =============================================

-- Desnormalizado com empresa e cidade (JOIN feito no script 05)
CREATE TABLE staging.g3_patio (
    id_patio        INT,
    nome_patio      VARCHAR(150),
    id_empresa      INT,
    nome_empresa    VARCHAR(150),
    cidade          VARCHAR(100),
    uf              CHAR(2),
    dt_extracao     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE staging.g3_grupo (
    id_grupo        INT,
    nome            VARCHAR(100),
    descricao       TEXT,
    diaria_grupo    DECIMAL(10,2),
    dt_extracao     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- direcao_auto é BOOLEAN (MySQL). Será convertido para
-- 'AUTOMATICA'/'MANUAL' no script 07 em mecanizacao_conf.
CREATE TABLE staging.g3_veiculo (
    id_veiculo      INT,
    id_grupo        INT,
    categoria       VARCHAR(50),
    marca           VARCHAR(60),
    modelo          VARCHAR(60),
    ano             VARCHAR(4),    -- string no MySQL original
    cor             VARCHAR(40),
    chassi          CHAR(17),
    placa           CHAR(7),
    ar_condicionado BOOLEAN,
    direcao_auto    BOOLEAN,       -- TRUE=AUTOMATICA, FALSE=MANUAL
    dt_extracao     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE staging.g3_cliente (
    id_cliente      INT,
    nome_completo   VARCHAR(200),
    cpf             CHAR(11),
    nacionalidade   VARCHAR(60),
    cidade          VARCHAR(100),
    uf              CHAR(2),
    dt_extracao     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- estado_reserva é INT (0, 1, 2) em vez de texto.
-- Mapeado para EM_ANDAMENTO/CANCELADA/CONFIRMADA no script 07.
CREATE TABLE staging.g3_reserva (
    id_reserva              INT,
    id_cliente              INT,
    id_grupo                INT,
    id_patio_origem         INT,
    id_patio_fim            INT,
    data_inicio_combinada   TIMESTAMP,
    data_fim_combinada      TIMESTAMP,
    data_reserva            DATE,
    estado_reserva          INT,    -- 0=em andamento, 1=cancelada, 2=confirmada
    preco_final             DECIMAL(10,2),
    dt_extracao             TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- NÃO tem pátio de entrega! Só tem pátio de retirada (id_patio).
-- O pátio de entrega é resolvido no script 07 via g3_devolucao → g3_vaga.
CREATE TABLE staging.g3_locacao (
    id_locacao      INT,
    id_reserva      INT,
    id_veiculo      INT,
    id_patio        INT,           -- pátio de RETIRADA apenas
    data_locacao    TIMESTAMP,
    dt_extracao     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    -- ATENÇÃO: colunas id_patio_entrega e status_conformado são
    -- adicionadas via ALTER TABLE no script 07.
);

-- Armazena ID da vaga de devolução. Script 07 usa esta tabela
-- para obter id_patio a partir de id_vaga.
CREATE TABLE staging.g3_devolucao (
    id_devolucao    INT,
    id_locacao      INT,
    id_vaga         INT,           -- aponta para g3_vaga → g3_patio
    data_devolucao  TIMESTAMP,
    dt_extracao     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela-ponte: vaga → pátio. Necessária para saber onde o carro foi devolvido.
CREATE TABLE staging.g3_vaga (
    id_vaga     INT,
    cod_vaga    VARCHAR(50),
    id_patio    INT,               -- este é o pátio de entrega!
    dt_extracao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- G4 — mhscardoso (PostgreSQL)
-- Destaque: usa "Motorista" em vez de "Cliente";
--           pátio resolvido via IDVagaRetirada e IDVagaDevolvida;
--           classe de luxo usa letras ('A','B','C').
-- =============================================

-- Desnormalizado com cidade/UF e nome da empresa parceira.
CREATE TABLE staging.g4_patio (
    id_patio            INT,
    cd_patio            VARCHAR(50),
    lotacao             INT,
    horario_abertura    TIME,
    horario_fechamento  TIME,
    cidade              VARCHAR(100),
    uf                  CHAR(2),
    nome_parceira       VARCHAR(255),
    dt_extracao         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 'classe_luxo' usa CHAR(1): 'A'=BASICO, 'B'=INTERMEDIARIO, 'C'=LUXO.
-- Será convertida para texto descritivo no script 07.
CREATE TABLE staging.g4_categoria (
    id_categoria        INT,
    classificacao       VARCHAR(50),
    classe_luxo         CHAR(1),    -- A / B / C → conformado no script 07
    valor_diaria_base   DECIMAL(10,2),
    tracao_4x4          BOOLEAN,
    dt_extracao         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE staging.g4_veiculo (
    id_veiculo          INT,
    placa               VARCHAR(10),
    chassi              VARCHAR(30),
    modelo              VARCHAR(100),
    ano                 INT,
    ar_condicionado     BOOLEAN,
    ultima_km           INT,
    valor_diaria        DECIMAL(10,2),
    id_categoria        INT,
    dt_extracao         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Equivalente ao Cliente dos outros grupos. Nome/CPF/cidade
-- vêm de PessoaFisica e Endereco (desnormalizado no script 06).
CREATE TABLE staging.g4_motorista (
    id_motorista    INT,
    cpf             VARCHAR(11),
    nome            VARCHAR(255),
    cnh             VARCHAR(20),
    categoria_cnh   VARCHAR(5),
    cidade          VARCHAR(100),
    uf              CHAR(2),
    dt_extracao     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE staging.g4_reserva (
    id_reserva          INT,
    dt_reserva          TIMESTAMP,
    dt_retirada_prevista TIMESTAMP,
    status              VARCHAR(20),
    dt_extracao         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- NÃO tem id_patio diretamente — usa id_vaga_retirada e id_vaga_devolvida.
-- Script 07 resolve cada vaga para o pátio correspondente.
CREATE TABLE staging.g4_locacao (
    id_locacao          INT,
    valor_diaria        DECIMAL(10,2),
    dt_retirada         TIMESTAMP,
    dt_chegada          TIMESTAMP,         -- NULL se ativa
    id_vaga_retirada    INT,               -- resolvido para pátio no script 07
    id_vaga_devolvida   INT,               -- resolvido para pátio no script 07
    id_veiculo          INT,
    id_reserva          INT,
    id_motorista        INT,
    dt_extracao         TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    -- ATENÇÃO: id_patio_retirada, id_patio_entrega e status_conformado
    -- são adicionados via ALTER TABLE no script 07.
);

-- Tabela-ponte: id_vaga → id_patio (mesmo papel do g3_vaga).
CREATE TABLE staging.g4_vaga (
    id_vaga     INT,
    cod_vaga    VARCHAR(50),
    id_patio    INT,
    dt_extracao TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
