# Projeto de Banco de Dados e Data Warehouse - Locadora de Veículos

## 👥 Equipe
* [cite_start]**Thiago Moutinho de Carvalho Maksoud** - DRE: 119048139 [cite: 50, 215]
* [cite_start]**Thomas Cardoso de Miranda** - DRE: 122050797 [cite: 50, 215]
* [cite_start]**Yan Lukas Willian Tavares** - DRE: 124341835 [cite: 50, 215]
*(Adicione ou remova membros conforme necessário)*

---

## 📖 Contexto do Projeto
[cite_start]Este projeto simula a atuação do nosso grupo como uma empresa de consultoria de TIC[cite: 12, 178]. [cite_start]O cenário envolve seis empresas independentes de aluguel de automóveis que se associaram para compartilhar seus pátios de veículos[cite: 3, 175]. [cite_start]Os pátios compartilhados estão localizados no Aeroporto do Galeão, Santos Dumont, Rodoviária, Shopping Rio Sul, Nova América e Barra Shopping[cite: 4, 176].

[cite_start]O objetivo da consultoria se divide em gerenciar o sistema transacional de UMA dessas empresas e construir uma solução de Data Warehouse (DW) integrado para a associação, visando a geração de Relatórios Gerenciais Globais e Dashboards unificados para tomada de decisão[cite: 12, 178].

## 🎯 Escopo do Sistema
[cite_start]Para evitar que a tarefa fique exaustiva, o escopo de integração foi restrito ao sistema de negócio central das empresas[cite: 13, 179]. Os conceitos principais do universo de discurso envolvidos são apenas cinco:
* [cite_start]Cliente [cite: 14, 180]
* [cite_start]Veículos (frota) [cite: 14, 180]
* [cite_start]Pátio [cite: 14, 180]
* [cite_start]Reservas [cite: 14, 180]
* [cite_start]Locações (aluguel) [cite: 14, 180]

[cite_start]Foram deixados de fora os sistemas auxiliares como RH, Compras e Fornecedores[cite: 13, 179].

---

## 🛠️ Parte 1: Projeto do Banco de Dados Transacional

[cite_start]A primeira etapa do projeto consiste no desenvolvimento do "Projeto do Banco de Dados" Relacional do sistema transacional para uma das empresas de locação[cite: 40, 205]. [cite_start]O modelo foi desenvolvido para atender aos requisitos de relatórios gerenciais e análises de movimentação de veículos entre os pátios[cite: 36, 202].

### Domínios Modelados
[cite_start]O banco de dados modela os seguintes subsistemas[cite: 41, 206]:
1. [cite_start]**Cadastro de Clientes:** Pessoas físicas (PF) e jurídicas (PJ), incluindo detalhes de motoristas e CNH[cite: 28, 29, 194, 195].
2. [cite_start]**Controle de Frota de Veículos:** Categorias/grupos de luxo, características, prontuários de revisão e fotos dos veículos[cite: 25, 27, 191, 193].
3. [cite_start]**Sistema de Reserva:** Controle de disponibilidade de frota por data e controle de filas de reserva ou espera[cite: 31, 32, 197, 198].
4. [cite_start]**Acompanhamento de Locação:** Pátios de saída e chegada, horários previstos e realizados, e estado do veículo[cite: 33, 199].
5. [cite_start]**Sistema de Cobrança:** Inclusão de proteções adicionais e ajustes na cobrança final[cite: 34, 200].
6. [cite_start]**Controle de Pátio:** Gestão de grandes estacionamentos e vagas para retirada e entrega[cite: 6, 8, 176].

### 📦 Entregáveis (Primeira Parte)
Os artefatos produzidos nesta etapa incluem:
* [cite_start]`documentacao.pdf`: Um texto com toda a descrição do Projeto do Banco de Dados Relacional, contendo os detalhes necessários para a justificação dos scripts SQL de Extração ETL[cite: 43, 208].
* [cite_start]`dicionario_dados`: Dicionário de Dados do Modelo, contendo as especificações detalhadas das Restrições de Integridade[cite: 44, 209].
* [cite_start]`modelo_conceitual`: Uma figura representando o Modelo Conceitual (MER / MOO/UML)[cite: 45, 210].
* [cite_start]`modelo_logico`: O esquema diagramado do Modelo Lógico[cite: 46, 211].
* [cite_start]`script_ddl.sql`: O script SQL/DDL completo do Modelo Físico, construído utilizando o padrão ANSI SQL a partir do SQL99 (SQL3)[cite: 47, 212].

---

## 📊 Parte 2: Data Warehouse e Análises (Futuro)

[cite_start]A solução de DW armazenará os dados históricos de forma integrada para viabilizar relatórios sobre[cite: 11, 177]:
* [cite_start]**Controle de pátio:** Quantitativo de veículos por "grupo" e "origem"[cite: 16, 181].
* [cite_start]**Controle das locações:** Quantitativo de veículos alugados, tempo de locação e disponibilidade futura[cite: 19, 184].
* [cite_start]**Controle de reservas:** Demanda por grupo de veículo, pátio de retirada e análise por origem de clientes[cite: 20, 185].
* [cite_start]**Veículos mais alugados:** Cruzamento de popularidade de grupos com a origem dos clientes[cite: 21, 186].

### Previsão de Ocupação (Cadeia de Markov)
[cite_start]A única análise preditiva modelada será a **previsão de ocupação de pátio**, que será calculada utilizando Cadeias de Markov[cite: 22, 187]. [cite_start]Será criada uma matriz estocástica baseada nos percentuais de movimentação da frota (veículos que retornam ao mesmo pátio ou são entregues em pátios diferentes)[cite: 23, 188].

---

## 🚀 Como Executar o Script SQL
1. Clone este repositório: `git clone <URL_DO_REPOSITORIO>`
2. Abra seu SGBD preferido compatível com ANSI SQL (ex: PostgreSQL, MySQL).
3. Execute o arquivo `script_ddl.sql` para construir as tabelas físicas e as restrições de integridade da Parte 1.

[cite_start]*Aviso: TODOS os arquivos (PDF e scripts SQL) devem conter um "cabeçalho" (folha de rosto) com a identificação clara do grupo (nomes e DRE), sob pena de não serem considerados na avaliação*[cite: 52, 53, 217, 218].
