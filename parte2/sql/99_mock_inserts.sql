-- =============================================================
-- SCRIPT 99 — Carga de Dados Simulados (Mock Data) para Testes
-- =============================================================
-- Grupo:
--   Thomas Cardoso de Miranda       DRE 122050797
--   Thiago Moutinho de Carvalho Maksoud DRE 119048139
--   Yan Lukas Willian Tavares       DRE 124341835
--
-- Disciplina: EEL890 / MAE016 — Big Data e Data Warehouse
-- UFRJ — Instituto de Matemática — DMA
--
-- Descrição:
--   Popula a Staging Area com exatamente 60 locações estruturadas
--   para reproduzir com precisão matemática os resultados da
--   Cadeia de Markov e do Estado Estacionário do relatório.
--   Isso permite demonstrar o funcionamento do DW sem precisar
--   conectar fisicamente as bases de dados de outros grupos.
-- =============================================================

DO $$
DECLARE
    r_id INT := 1;
    l_id INT := 1;
    idx INT;
    i INT;
    
    -- Definição dos pátios:
    -- 1: Galeão, 2: Santos Dumont, 3: Barra Shopping, 
    -- 4: Nova América, 5: Rio Sul, 6: Rodoviária Novo Rio
    
    -- Vetores de transição simulados (Origem -> Destino -> Quantidade de ocorrências)
    origens INT[] := ARRAY[
        1,1,1,1,           -- De Galeão (GIG)
        2,2,2,2,           -- De Santos Dumont (SDU)
        3,3,3,3,3,         -- De Barra Shopping (BAR)
        4,4,4,4,           -- De Nova América (NOV)
        5,5,5,5,           -- De Rio Sul (SUL)
        6,6,6,6            -- De Rodoviária Novo Rio (ROD)
    ];
    
    destinos INT[] := ARRAY[
        1,2,3,5,           -- Para: GIG (3), SDU (1), BAR (4), SUL (2)
        2,1,5,3,           -- Para: SDU (4), GIG (2), SUL (3), BAR (1)
        3,1,2,4,6,         -- Para: BAR (5), GIG (2), SDU (1), NOV (1), ROD (1)
        4,6,1,3,           -- Para: NOV (6), ROD (2), GIG (1), BAR (1)
        5,1,2,3,           -- Para: SUL (4), GIG (2), SDU (2), BAR (2)
        6,1,2,4            -- Para: ROD (5), GIG (3), SDU (1), NOV (1)
    ];
    
    quantidades INT[] := ARRAY[
        3,1,4,2,           -- Soma 10
        4,2,3,1,           -- Soma 10
        5,2,1,1,1,         -- Soma 10
        6,2,1,1,           -- Soma 10
        4,2,2,2,           -- Soma 10
        5,3,1,1            -- Soma 10 (Total Geral = 60 locações)
    ];
BEGIN
    -- 1. LIMPAR DADOS EXISTENTES NA STAGING DO G1
    TRUNCATE TABLE staging.g1_patio CASCADE;
    TRUNCATE TABLE staging.g1_grupo_veiculo CASCADE;
    TRUNCATE TABLE staging.g1_veiculo CASCADE;
    TRUNCATE TABLE staging.g1_cliente CASCADE;
    TRUNCATE TABLE staging.g1_reserva CASCADE;
    TRUNCATE TABLE staging.g1_locacao CASCADE;

    -- 2. INSERIR OS 6 PÁTIOS COMPARTILHADOS
    INSERT INTO staging.g1_patio (id_patio, nome_localizacao, capacidade_vagas, empresa_dona) VALUES
    (1, 'Aeroporto Galeão', 120, 'G1'),
    (2, 'Aeroporto Santos Dumont', 80, 'G1'),
    (3, 'Barra Shopping', 150, 'G1'),
    (4, 'Nova América', 100, 'G1'),
    (5, 'Rio Sul', 90, 'G1'),
    (6, 'Rodoviária Novo Rio', 70, 'G1');

    -- 3. INSERIR GRUPO DE VEÍCULO PADRÃO
    INSERT INTO staging.g1_grupo_veiculo (id_grupo, nome_categoria, classe_luxo, valor_diaria) VALUES
    (1, 'Compacto', 'BASICO', 110.00);

    -- 4. INSERIR VEÍCULO DE TESTE (Necessário para a consistência da fatos)
    INSERT INTO staging.g1_veiculo (id_veiculo, id_grupo, placa, chassi, marca, modelo, cor, ar_condicionado, mecanizacao, status_disponibilidade) VALUES
    (101, 1, 'KXP1234', '9BWZZZ99Z99999999', 'Volkswagen', 'Gol', 'Branco', TRUE, 'MANUAL', 'Disponível');

    -- 5. INSERIR CLIENTE DE TESTE
    INSERT INTO staging.g1_cliente (id_cliente, tipo_cliente, nome_razao_social, cpf_cnpj, endereco_completo) VALUES
    (501, 'PF', 'Cliente Teste de Integração', '12345678901', 'NAO_INFORMADO');

    -- 6. GERAR AS 60 TRANSAÇÕES DE ACORDO COM A MATRIZ DE TRANSIÇÃO
    FOR idx IN 1..array_length(origens, 1) LOOP
        FOR i IN 1..quantidades[idx] LOOP
            
            -- Inserir reserva associada
            INSERT INTO staging.g1_reserva (
                id_reserva, id_cliente, id_grupo, id_patio_retirada,
                data_hora_solicitacao, data_hora_retirada_prevista, data_hora_devolucao_prevista, status_reserva
            ) VALUES (
                r_id, 501, 1, origens[idx],
                '2026-05-01 08:00:00'::TIMESTAMP, 
                '2026-05-02 09:00:00'::TIMESTAMP, 
                '2026-05-05 18:00:00'::TIMESTAMP, 
                'CONFIRMADA'
            );

            -- Inserir locação realizada
            INSERT INTO staging.g1_locacao (
                id_locacao, id_reserva, id_veiculo, id_patio_saida,
                id_patio_chegada_prevista, id_patio_chegada_realizada,
                data_hora_retirada, data_hora_devolucao_prevista, data_hora_devolucao_realizada,
                valor_inicial, valor_final
            ) VALUES (
                l_id, r_id, 101, 
                origens[idx],     -- De onde saiu
                destinos[idx],    -- Destino planejado
                destinos[idx],    -- Onde foi devolvido
                '2026-05-02 09:15:00'::TIMESTAMP, 
                '2026-05-05 18:00:00'::TIMESTAMP, 
                '2026-05-05 17:45:00'::TIMESTAMP, -- Concluída
                330.00, 330.00
            );

            r_id := r_id + 1;
            l_id := l_id + 1;
        END LOOP;
    END LOOP;
    
    RAISE NOTICE 'Mock data de teste carregado com sucesso: % reservas e % locações geradas.', r_id - 1, l_id - 1;
END $$;
