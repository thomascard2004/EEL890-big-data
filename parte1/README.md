# Projeto de Banco de Dados e Data Warehouse - Locadora de Veículos

## 👥 Equipe
* **Thiago Moutinho de Carvalho Maksoud** - DRE: 119048139 
* **Thomas Cardoso de Miranda** - DRE: 122050797 
* **Yan Lukas Willian Tavares** - DRE: 124341835 

---

## 📖 Contexto do Projeto
Este projeto simula a atuação do nosso grupo como uma empresa de consultoria de TIC. O cenário envolve seis empresas independentes de aluguel de automóveis que se associaram para compartilhar seus pátios de veículos. Os pátios compartilhados estão localizados no Aeroporto do Galeão, Santos Dumont, Rodoviária, Shopping Rio Sul, Nova América e Barra Shopping.

O objetivo da consultoria se divide em gerenciar o sistema transacional de UMA dessas empresas e construir uma solução de Data Warehouse (DW) integrado para a associação, visando a geração de Relatórios Gerenciais Globais e Dashboards unificados para tomada de decisão.

## 🎯 Escopo do Sistema
Para evitar que a tarefa fique exaustiva, o escopo de integração foi restrito ao sistema de negócio central das empresas. Os conceitos principais do universo de discurso envolvidos são apenas seis:
* Cliente 
* Veículos (frota) 
* Pátio 
* Reservas 
* Locações (aluguel) 
* Seguros

Foram deixados de fora os sistemas auxiliares como RH, Compras e Fornecedores.

---

## 🛠️ Parte 1: Projeto do Banco de Dados Transacional

A primeira etapa do projeto consiste no desenvolvimento do "Projeto do Banco de Dados" Relacional do sistema transacional para uma das empresas de locação. O modelo foi desenvolvido para atender aos requisitos de relatórios gerenciais e análises de movimentação de veículos entre os pátios.

### Domínios Modelados
O banco de dados modela os seguintes subsistemas:
1. **Cadastro de Clientes:** Pessoas físicas (PF) e jurídicas (PJ), incluindo detalhes de motoristas e CNH.
2. **Controle de Frota de Veículos:** Categorias/grupos de luxo, características, prontuários de revisão e fotos dos veículos.
3. **Sistema de Reserva:** Controle de disponibilidade de frota por data e controle de filas de reserva ou espera.
4. **Acompanhamento de Locação:** Pátios de saída e chegada, horários previstos e realizados, e estado do veículo.
5. **Sistema de Cobrança:** Inclusão de proteções adicionais e ajustes na cobrança final.
6. **Controle de Pátio:** Gestão de grandes estacionamentos e vagas para retirada e entrega.

### 📦 Entregáveis (Primeira Parte)
Os artefatos produzidos nesta etapa incluem:
* `documentacao.pdf`: Um texto com toda a descrição do Projeto do Banco de Dados Relacional, contendo os detalhes necessários para a justificação dos scripts SQL de Extração ETL. Contém também o Dicionário de Dados do Modelo, contendo as especificações detalhadas das Restrições de Integridade.
* `modelo_conceitual`: Uma figura representando o Modelo Conceitual (MER / MOO/UML).
* `modelo_logico`: O esquema diagramado do Modelo Lógico.
* `script_ddl.sql`: O script SQL/DDL completo do Modelo Físico, construído utilizando o padrão ANSI SQL a partir do SQL99 (SQL3).

---

## 📊 Parte 2: Data Warehouse e Análises (Futuro)

A solução de DW armazenará os dados históricos de forma integrada para viabilizar relatórios sobre:
* **Controle de pátio:** Quantitativo de veículos por "grupo" e "origem".
* **Controle das locações:** Quantitativo de veículos alugados, tempo de locação e disponibilidade futura.
* **Controle de reservas:** Demanda por grupo de veículo, pátio de retirada e análise por origem de clientes.
* **Veículos mais alugados:** Cruzamento de popularidade de grupos com a origem dos clientes.

### Previsão de Ocupação (Cadeia de Markov)
A única análise preditiva modelada será a **previsão de ocupação de pátio**, que será calculada utilizando Cadeias de Markov. Será criada uma matriz estocástica baseada nos percentuais de movimentação da frota (veículos que retornam ao mesmo pátio ou são entregues em pátios diferentes).

---

## 🚀 Como Executar o Script SQL
1. Clone este repositório: `git clone <URL_DO_REPOSITORIO>`
2. Abra seu SGBD preferido compatível com ANSI SQL (ex: PostgreSQL, MySQL).
3. Execute o arquivo `script_ddl.sql` para construir as tabelas físicas e as restrições de integridade da Parte 1.