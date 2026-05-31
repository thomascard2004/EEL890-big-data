# 📦 Data Warehouse Integrado — Consórcio de Locadoras de Veículos

**UFRJ — Instituto de Matemática — DMA**  
**Disciplina:** EEL890 / MAE016 — Big Data e Data Warehouse  
**Avaliação 02 — Parte II: Modelagem de DW**

**Grupo:**
| Nome | DRE |
|:---|:---|
| Thomas Cardoso de Miranda | 122050797 |
| Thiago Moutinho de Carvalho Maksoud | 119048139 |
| Yan Lukas Willian Tavares | 124341835 |

---

## 📋 Sobre o Projeto

Este repositório implementa o **Data Warehouse (DWH)** consolidado de um consórcio de **6 locadoras de veículos** que compartilham **6 pátios físicos** no Rio de Janeiro (Aeroporto Galeão, Santos Dumont, Barra Shopping, Nova América, Rio Sul e Rodoviária Novo Rio).

O sistema inclui:
- **Pipeline completa de ETL** (Extração, Transformação e Carga) que unifica dados de 4 fontes OLTP heterogêneas (PostgreSQL e MySQL).
- **Modelo dimensional Estrela (Star Schema)** com 5 dimensões e 3 tabelas de fatos.
- **4 Relatórios Gerenciais** (controle de pátio, locações, reservas e análise por cidade).
- **Cadeia de Markov** para previsão de redistribuição da frota entre pátios.

---

## 🛠️ Pré-requisitos

Você precisa apenas de:
- [Docker](https://docs.docker.com/get-docker/) (versão 20+)
- [Docker Compose](https://docs.docker.com/compose/install/) (versão 2+)

> **Não é necessário** instalar PostgreSQL, criar banco de dados ou rodar scripts manualmente.

---

## 🚀 Como Executar

### 1. Clone o repositório
```bash
git clone https://github.com/SEU_USUARIO/ufrj_big_data_trabalho02.git
cd ufrj_big_data_trabalho02
```

### 2. Inicie o Data Warehouse
```bash
docker compose up
```

Este único comando irá:
1. Baixar a imagem do **PostgreSQL 16**.
2. Criar a base de dados `locadora_dwh`.
3. Executar automaticamente toda a pipeline na ordem correta:
   - `01_staging_ddl.sql` → Cria a Área de Staging (tabelas temporárias).
   - `02_dw_star_schema.sql` → Cria o Esquema Estrela (dimensões e fatos).
   - `99_mock_inserts.sql` → Popula a staging com 60 locações simuladas.
   - `07_etl_transform.sql` → Transforma e padroniza os dados.
   - `08_etl_load.sql` → Carrega as dimensões e fatos no DW.
   - `09_relatorios.sql` → Cria as Views dos 4 relatórios gerenciais.
   - `10_matriz_markov.sql` → Calcula a matriz de transição e o estado estacionário.

Aguarde até ver a mensagem:
```
PIPELINE FINALIZADA COM SUCESSO!
```

### 3. Conecte ao banco de dados
Abra **outro terminal** e execute:  (ps:newgrp docker)pra não ter que reiniciar 
```bash
docker exec -it locadora_dwh_db psql -U postgres -d locadora_dwh
```

### 4. Rode as consultas de validação
Dentro do `psql`, teste os resultados:

```sql
-- Ver a matriz de probabilidade de transição entre pátios
SELECT * FROM dw.markov_matriz_percentuais;

-- Validar que cada linha da matriz soma 1.0 (propriedade estocástica)
SELECT patio_origem,
       ROUND(SUM(probabilidade), 4) AS soma,
       CASE WHEN ABS(SUM(probabilidade) - 1.0) < 0.001 THEN 'OK ✓' ELSE 'ERRO' END AS status
FROM dw.markov_matriz_percentuais
GROUP BY patio_origem
ORDER BY patio_origem;

-- Ver relatório de controle de pátio (Relatório A)
SELECT * FROM dw.relatorio_a_controle_patio;

-- Ver dados consolidados no DW
SELECT * FROM dw.dim_patio;
SELECT * FROM dw.dim_cliente WHERE fonte_grupo = 'G1';
SELECT COUNT(*) AS total_locacoes FROM dw.fato_locacao;
```

### 5. Parar o container
```bash
docker compose down
```
> Para apagar também os dados persistidos: `docker compose down -v`

---

## 📂 Estrutura do Repositório

```
ufrj_big_data_trabalho02/
│
├── docker-compose.yml          # Configuração do container PostgreSQL 16
├── init-db.sh                  # Script que executa a pipeline automaticamente
├── README.md
│
├── sql/                        # Scripts SQL (executados em ordem numérica)
│   ├── 01_staging_ddl.sql      # DDL da Área de Staging (tabelas g1_ a g4_)
│   ├── 02_dw_star_schema.sql   # DDL do Star Schema (dim_* e fato_*)
│   ├── 03_etl_extract_G1.sql   # Extração do OLTP do Grupo 1 (nosso)
│   ├── 04_etl_extract_G2.sql   # Extração do OLTP do Grupo 2 (gupessanha)
│   ├── 05_etl_extract_G3.sql   # Extração do OLTP do Grupo 3 (guilherme-hu)
│   ├── 06_etl_extract_G4.sql   # Extração do OLTP do Grupo 4 (mhscardoso)
│   ├── 07_etl_transform.sql    # Transformações: limpeza, conformação, lookups
│   ├── 08_etl_load.sql         # Carga nas dimensões e fatos (Surrogate Keys)
│   ├── 09_relatorios.sql       # Views dos 4 relatórios gerenciais
│   ├── 10_matriz_markov.sql    # Cadeia de Markov (matriz + estado estacionário)
│   └── 99_mock_inserts.sql     # Dados simulados (60 locações de teste)
│
├── schemas_outros_grupos/      # DDL original dos OLTPs dos grupos parceiros
│   ├── G1_thomascard_script_ddl.sql
│   ├── G2_gupessanha_schema.sql
│   ├── G3_guilherme_hu_schema.sql
│   └── G4_mhscardoso_create_table.sql
│
└── docs/                       # Documentação e relatórios PDF
    ├── Folha de Rosto — EEL890_MAE016 — UFRJ.pdf
    ├── Relatório ETL e Data Warehouse — EEL890_MAE016 — UFRJ.pdf
    ├── Modelo Dimensional Estrela — EEL890_MAE016 — UFRJ.pdf
    ├── rascunho_relatorio_etl_dw.md
    ├── rascunho_modelo_estrela.md
    └── plano_de_testes.md
```

---

## 🏗️ Arquitetura do Data Warehouse

### Modelo Dimensional (Star Schema)

**Dimensões:**
| Tabela | Descrição |
|:---|:---|
| `dw.dim_tempo` | Hierarquia temporal (dia, semana, mês, trimestre, ano) — pré-populada de 2020 a 2030 |
| `dw.dim_patio` | Os 6 pátios compartilhados com empresa dona |
| `dw.dim_empresa` | As 6 locadoras do consórcio |
| `dw.dim_grupo_veiculo` | Categorias comerciais (Compacto, SUV, Luxo, etc.) |
| `dw.dim_veiculo` | Frota individual com placa, marca, modelo e mecanização |
| `dw.dim_cliente` | Clientes PF/PJ com cidade de origem |

**Fatos:**
| Tabela | Granularidade | Uso Principal |
|:---|:---|:---|
| `dw.fato_locacao` | 1 linha por locação | Relatórios B, D e Cadeia de Markov |
| `dw.fato_reserva` | 1 linha por reserva | Relatório C (demanda futura) |
| `dw.fato_patio_snapshot` | 1 linha por veículo × pátio × dia | Relatório A (controle de pátio) |

### Cadeia de Markov — Resultados Esperados

A análise preditiva calcula para onde os veículos tendem a se concentrar no longo prazo:

| Pátio | Distribuição de Equilíbrio |
|:---|:---:|
| Barra Shopping | **28.67%** |
| Aeroporto Galeão | **22.22%** |
| Aeroporto Santos Dumont | **15.05%** |
| Rio Sul | **14.93%** |
| Nova América | **9.56%** |
| Rodoviária Novo Rio | **9.56%** |

> **Interpretação:** A Barra Shopping atrai quase 30% da frota, enquanto Rodoviária e Nova América ficam com menos de 10%. A gerência de logística deve programar redistribuição preventiva de veículos.

---

## 📄 Documentação Completa

Os relatórios em PDF na pasta `docs/` contêm:
- **Folha de Rosto** com identificação do grupo.
- **Relatório ETL e DW** com a estratégia de staging, regras de transformação por grupo e análise de Markov.
- **Modelo Dimensional Estrela** com justificativa de cada dimensão, granularidade das fatos e diagrama do schema.
