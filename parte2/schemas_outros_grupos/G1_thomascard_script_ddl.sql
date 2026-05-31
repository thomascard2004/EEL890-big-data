-- Thomas Cardoso de Miranda DRE 122050797
-- Thiago Moutinho de Carvalho Maksoud DRE 119048139
-- Yan Lukas Willian Tavares DRE 124341835

-- 1. Criação da Tabela de Pátios
CREATE TABLE Patio (
    ID_Patio INT PRIMARY KEY,
    Nome_Localizacao VARCHAR(100) NOT NULL,
    Capacidade_Vagas INT NOT NULL,
    Empresa_Dona VARCHAR(100) NOT NULL
);

-- 2. Criação da Tabela de Grupos/Categorias de Veículos
CREATE TABLE Grupo_Veiculo (
    ID_Grupo INT PRIMARY KEY,
    Nome_Categoria VARCHAR(50) NOT NULL,
    Classe_Luxo VARCHAR(50) NOT NULL,
    Valor_Diaria DECIMAL(10, 2) NOT NULL
);

-- 3. Criação da Tabela de Veículos (Frota)
CREATE TABLE Veiculo (
    ID_Veiculo INT PRIMARY KEY,
    ID_Grupo INT NOT NULL,
    Placa VARCHAR(10) UNIQUE NOT NULL,
    Chassi VARCHAR(50) UNIQUE NOT NULL,
    Marca VARCHAR(50) NOT NULL,
    Modelo VARCHAR(50) NOT NULL,
    Cor VARCHAR(30) NOT NULL,
    Ar_Condicionado BOOLEAN NOT NULL,
    Mecanizacao VARCHAR(20) NOT NULL,
    Cadeirinha_Crianca BOOLEAN DEFAULT FALSE,
    Bebe_Conforto BOOLEAN DEFAULT FALSE,
    Dimensoes VARCHAR(100),
    Status_Disponibilidade VARCHAR(20) DEFAULT 'Disponível',
    FOREIGN KEY (ID_Grupo) REFERENCES Grupo_Veiculo(ID_Grupo)
);

-- 4. Criação da Tabela de Prontuário do Veículo
CREATE TABLE Prontuario_Veiculo (
    ID_Prontuario INT PRIMARY KEY,
    ID_Veiculo INT NOT NULL,
    Data_Registro DATE NOT NULL,
    Pressao_Pneus VARCHAR(50),
    Nivel_Oleo VARCHAR(50),
    Estado_Conservacao TEXT,
    Descricao_Revisoes TEXT,
    FOREIGN KEY (ID_Veiculo) REFERENCES Veiculo(ID_Veiculo)
);

-- 5. Criação da Tabela de Fotos do Veículo
CREATE TABLE Foto_Veiculo (
    ID_Foto INT PRIMARY KEY,
    ID_Veiculo INT NOT NULL,
    URL_Foto VARCHAR(255) NOT NULL,
    Tipo_Foto VARCHAR(50),
    FOREIGN KEY (ID_Veiculo) REFERENCES Veiculo(ID_Veiculo)
);

-- 6. Criação da Tabela de Clientes
CREATE TABLE Cliente (
    ID_Cliente INT PRIMARY KEY,
    Tipo_Cliente CHAR(2) NOT NULL,
    Nome_Razao_Social VARCHAR(150) NOT NULL,
    CPF_CNPJ VARCHAR(20) UNIQUE NOT NULL,
    Endereco_Completo TEXT,
    Dados_Cobranca TEXT
);

-- 7. Criação da Tabela de Motoristas (Condutores)
CREATE TABLE Motorista (
    ID_Motorista INT PRIMARY KEY,
    ID_Cliente INT NOT NULL,
    Nome_Condutor VARCHAR(150) NOT NULL,
    Numero_CNH VARCHAR(20) UNIQUE NOT NULL,
    Categoria_Habilitacao VARCHAR(5) NOT NULL,
    Data_Expiracao_CNH DATE NOT NULL,
    FOREIGN KEY (ID_Cliente) REFERENCES Cliente(ID_Cliente)
);

-- 8. Criação da Tabela de Reservas
CREATE TABLE Reserva (
    ID_Reserva INT PRIMARY KEY,
    ID_Cliente INT NOT NULL,
    ID_Grupo INT,
    ID_Veiculo_Especifico INT,
    ID_Patio_Retirada INT NOT NULL,
    Data_Hora_Solicitacao TIMESTAMP NOT NULL,
    Data_Hora_Retirada_Prevista TIMESTAMP NOT NULL,
    Data_Hora_Devolucao_Prevista TIMESTAMP NOT NULL,
    Status_Reserva VARCHAR(20) DEFAULT 'Confirmada',
    FOREIGN KEY (ID_Cliente) REFERENCES Cliente(ID_Cliente),
    FOREIGN KEY (ID_Grupo) REFERENCES Grupo_Veiculo(ID_Grupo),
    FOREIGN KEY (ID_Veiculo_Especifico) REFERENCES Veiculo(ID_Veiculo),
    FOREIGN KEY (ID_Patio_Retirada) REFERENCES Patio(ID_Patio)
);

-- 9. Catálogo de Seguros
CREATE TABLE Seguro_Protecao (
    ID_Seguro INT PRIMARY KEY,
    Descricao VARCHAR(100) NOT NULL,
    Valor_Diario DECIMAL(10, 2) NOT NULL
);

-- 10. Criação da Tabela de Locação
CREATE TABLE Locacao (
    ID_Locacao INT PRIMARY KEY,
    ID_Reserva INT,
    ID_Motorista INT NOT NULL,
    ID_Veiculo INT NOT NULL,
    ID_Patio_Saida INT NOT NULL,
    ID_Patio_Chegada_Prevista INT NOT NULL,
    ID_Patio_Chegada_Realizada INT,
    Data_Hora_Retirada TIMESTAMP NOT NULL,
    Data_Hora_Devolucao_Prevista TIMESTAMP NOT NULL,
    Data_Hora_Devolucao_Realizada TIMESTAMP,
    Estado_Veiculo_Entrega TEXT,
    Estado_Veiculo_Devolucao TEXT,
    Valor_Inicial DECIMAL(10, 2),
    Valor_Final DECIMAL(10, 2),
    FOREIGN KEY (ID_Reserva) REFERENCES Reserva(ID_Reserva),
    FOREIGN KEY (ID_Motorista) REFERENCES Motorista(ID_Motorista),
    FOREIGN KEY (ID_Veiculo) REFERENCES Veiculo(ID_Veiculo),
    FOREIGN KEY (ID_Patio_Saida) REFERENCES Patio(ID_Patio),
    FOREIGN KEY (ID_Patio_Chegada_Prevista) REFERENCES Patio(ID_Patio),
    FOREIGN KEY (ID_Patio_Chegada_Realizada) REFERENCES Patio(ID_Patio)
);

-- 11. Tabela Associativa Locacao_Seguro
CREATE TABLE Locacao_Seguro (
    ID_Locacao INT NOT NULL,
    ID_Seguro INT NOT NULL,
    PRIMARY KEY (ID_Locacao, ID_Seguro),
    FOREIGN KEY (ID_Locacao) REFERENCES Locacao(ID_Locacao),
    FOREIGN KEY (ID_Seguro) REFERENCES Seguro_Protecao(ID_Seguro)
);