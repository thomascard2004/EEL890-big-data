-- =============================================================
-- SCRIPT 06 — ETL Extração: G4 (mhscardoso/bigdata)
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
-- Fonte: Matheus Henrique Soares Cardoso
-- Repo:  https://github.com/mhscardoso/bigdata
-- SGBD fonte: PostgreSQL
-- Schema fonte: locadora_g4
--
-- Descrição:
--   Extrai dados do sistema OLTP do grupo G4 (mhscardoso).
--   Tabelas principais: Endereco, Parceira (empresa), Patio
--   (com horários de funcionamento), Vaga, Categoria, Veiculo,
--   PessoaFisica, Empresa, Motorista, CentroCusto, Reserva,
--   Locacao (com IDVagaRetirada e IDVagaDevolvida), Prontuario, Avaria.
--
--   Desnormalizações:
--   - Patio: JOIN com Endereco e Parceira para nome e cidade
--   - Veiculo: JOIN com Categoria para grupo/classe
--   - Locacao: JOIN com Vaga+Patio para obter pátio de retirada/entrega
--   - Motorista: JOIN com PessoaFisica para nome e cidade
-- =============================================================

TRUNCATE TABLE staging.g4_patio;
TRUNCATE TABLE staging.g4_categoria;
TRUNCATE TABLE staging.g4_veiculo;
TRUNCATE TABLE staging.g4_motorista;
TRUNCATE TABLE staging.g4_reserva;
TRUNCATE TABLE staging.g4_locacao;
TRUNCATE TABLE staging.g4_vaga;

-- -----------------------------------------------
-- 1. Extração de Pátios (desnormalizado com Endereço e Parceira)
-- -----------------------------------------------
INSERT INTO staging.g4_patio (
    id_patio, cd_patio, lotacao,
    horario_abertura, horario_fechamento,
    cidade, uf, nome_parceira, dt_extracao
)
SELECT
    p.IDPatio,
    p.CDPatio,
    p.Lotacao,
    p.HorarioAbertura,
    p.HorarioFechamento,
    e.Cidade,
    e.UF,
    par.Nome,
    CURRENT_TIMESTAMP
FROM locadora_g4."Patio" p
JOIN locadora_g4."Endereco" e   ON e.IDEndereco  = p.IDEndereco
JOIN locadora_g4."Parceira" par ON par.IDParceira = p.IDParceira;

-- -----------------------------------------------
-- 2. Extração de Categorias de Veículos
-- -----------------------------------------------
INSERT INTO staging.g4_categoria (
    id_categoria, classificacao, classe_luxo,
    valor_diaria_base, tracao_4x4, dt_extracao
)
SELECT
    IDCategoria,
    Classificacao,
    ClasseLuxo,
    ValorDiariaBase,
    Tracao4x4,
    CURRENT_TIMESTAMP
FROM locadora_g4."Categoria";

-- -----------------------------------------------
-- 3. Extração de Veículos
-- -----------------------------------------------
INSERT INTO staging.g4_veiculo (
    id_veiculo, placa, chassi, modelo, ano,
    ar_condicionado, ultima_km, valor_diaria,
    id_categoria, dt_extracao
)
SELECT
    IDVeiculo,
    Placa,
    Chassi,
    Modelo,
    Ano,
    ArCondicionado,
    UltimaKilometragem,
    ValorDiaria,
    IDCategoria,
    CURRENT_TIMESTAMP
FROM locadora_g4."Veiculo";

-- -----------------------------------------------
-- 4. Extração de Motoristas (desnormalizado com PessoaFisica e Endereço)
-- -----------------------------------------------
INSERT INTO staging.g4_motorista (
    id_motorista, cpf, nome, cnh, categoria_cnh,
    cidade, uf, dt_extracao
)
SELECT
    m.IDMotorista,
    pf.CPF,
    pf.Nome,
    m.CNH,
    m.CategoriaCNH,
    en.Cidade,
    en.UF,
    CURRENT_TIMESTAMP
FROM locadora_g4."Motorista" m
JOIN locadora_g4."PessoaFisica" pf ON pf.IDFisica   = m.IDFisica
JOIN locadora_g4."Endereco" en     ON en.IDEndereco = pf.IDEndereco;

-- -----------------------------------------------
-- 5. Extração de Vagas (necessário para obter pátio na locação)
-- -----------------------------------------------
INSERT INTO staging.g4_vaga (
    id_vaga, cod_vaga, id_patio, dt_extracao
)
SELECT
    IDVaga,
    CodVaga,
    IDPatio,
    CURRENT_TIMESTAMP
FROM locadora_g4."Vaga";

-- -----------------------------------------------
-- 6. Extração de Reservas
-- -----------------------------------------------
INSERT INTO staging.g4_reserva (
    id_reserva, dt_reserva, dt_retirada_prevista,
    status, dt_extracao
)
SELECT
    IDReserva,
    DtReserva,
    DtRetiradaPrevista,
    Status,
    CURRENT_TIMESTAMP
FROM locadora_g4."Reserva";

-- -----------------------------------------------
-- 7. Extração de Locações
--    IDVagaRetirada e IDVagaDevolvida permitem descobrir
--    o pátio de retirada e entrega via tabela Vaga.
-- -----------------------------------------------
INSERT INTO staging.g4_locacao (
    id_locacao, valor_diaria, dt_retirada, dt_chegada,
    id_vaga_retirada, id_vaga_devolvida,
    id_veiculo, id_reserva, id_motorista, dt_extracao
)
SELECT
    IDLocacao,
    ValorDiaria,
    DtRetirada,
    DtChegada,
    IDVagaRetirada,
    IDVagaDevolvida,
    IDVeiculo,
    IDReserva,
    IDMotorista,
    CURRENT_TIMESTAMP
FROM locadora_g4."Locacao";
