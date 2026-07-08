# Especificação de Requisitos — Módulo SPI Controlador (MPPT)

> **Projeto:** Controlador MPPT — Submódulo de Comunicação SPI  
> **Data da última revisão:** 2026-07-02  

---

## 1. Visão Geral

O módulo SPI Controlador fornece uma interface serial síncrona de propósito geral para o sistema de rastreamento do ponto de máxima potência (MPPT). Ele suporta os **quatro modos SPI** (Modos 0–3), selecionáveis via parâmetros `CPOL` e `CPHA`, com transmissão iniciando pelo bit mais significativo (**MSB first**), seleção de periférico ativa em nível baixo com **CS único** e divisor de clock configurável pelo parâmetro `CLK_DIV`. A largura de palavra é parametrizável via `DATA_WIDTH`, com valor padrão de 12 bits. Os sinais de dados adotam a nomenclatura moderna: `SDO` (Serial Data Out) e `SDI` (Serial Data In).

| Atributo              | Valor                                                  |
|-----------------------|--------------------------------------------------------|
| Protocolo             | SPI                                                    |
| Modos SPI suportados  | Modos 0, 1, 2 e 3 (CPOL ∈ {0,1}, CPHA ∈ {0,1})       |
| Ordem dos bits        | MSB first                                              |
| Nomenclatura de dados | SDO (Serial Data Out), SDI (Serial Data In)            |
| Seleção de periférico | CS único, ativo baixo                                  |
| Divisor de clock      | Configurável via `CLK_DIV`                             |
| Parâmetros principais | `DATA_WIDTH` (padrão: 12), `CPOL`, `CPHA`, `CLK_DIV`  |
| Destino de aplicação  | Sistema MPPT                                           |

---

## 2. Requisitos Funcionais

| ID | Requisito |
|----|-----------|
| 1  | O módulo **deve** suportar todos os quatro modos SPI: Modo 0 (CPOL=0, CPHA=0), Modo 1 (CPOL=0, CPHA=1), Modo 2 (CPOL=1, CPHA=0) e Modo 3 (CPOL=1, CPHA=1), selecionáveis pelos parâmetros `CPOL` e `CPHA`. |
| 2  | O módulo **deve** gerar o clock SPI (`SCLK`) com polaridade em repouso definida por `CPOL` e fase de amostragem definida por `CPHA`. |
| 3  | O módulo **deve** transmitir e receber dados com o bit mais significativo (MSB) primeiro. |
| 4  | O módulo **deve** gerenciar um único sinal de seleção de periférico (`CS_N`), ativo em nível baixo. |
| 5  | O módulo **deve** assegurar que `CS_N` seja desativado (alto) enquanto nenhuma transação estiver em andamento. |
| 6  | O módulo **deve** aceitar dados paralelos de entrada (`SDO_DATA`) e apresentar dados paralelos de saída (`SDI_DATA`) após cada transação concluída. |
| 7  | O módulo **deve** sinalizar o término de uma transação por meio do sinal `DONE` por exatamente um ciclo de clock do sistema. |
| 8  | O módulo **deve** aceitar um novo comando de transmissão (`START`) somente quando o sinal `BUSY` estiver inativo. |
| 9  | O módulo **deve** implementar um divisor de clock inteiro configurável pelo parâmetro `CLK_DIV`, de modo que `f_SCLK = f_CLK / (2 × CLK_DIV)`. |
| 10 | A largura dos dados **deve** ser controlada pelo parâmetro `DATA_WIDTH`, com valor padrão de 12 bits. |
| 11 | O módulo **deve** suportar operação full-duplex: transmissão (`SDO`) e recepção (`SDI`) simultâneas em cada transação. |

---

## 3. Requisitos de Temporização

| ID | Requisito | Parâmetro de referência |
|----|-----------|------------------------|
| 12 | O sinal `CS_N` **deve** ser ativado (baixo) ao menos **1 período de `SCLK`** antes da primeira borda ativa de `SCLK`. | Setup CS → SCLK ≥ 1 T_sclk |
| 13 | O sinal `CS_N` **deve** permanecer ativo (baixo) até ao menos **1 período de `SCLK`** após a última borda de `SCLK`. | Hold SCLK → CS ≥ 1 T_sclk |
| 14 | Para modos CPHA=0, os dados em `SDO` **devem** ser estáveis antes da borda de amostragem de `SCLK` com setup time de ao menos **0,5 T_sclk**. | t_su(SDO) ≥ 0,5 T_sclk |
| 15 | Para modos CPHA=1, os dados em `SDO` **devem** ser atualizados na borda de propagação e estabilizados antes da borda de amostragem seguinte. | t_su(SDO) ≥ 0,5 T_sclk |
| 16 | Os dados em `SDI` **devem** ser amostrados internamente na borda de `SCLK` definida por `CPHA` (subida se CPHA=0, descida se CPHA=1, invertido quando CPOL=1). | Captura na borda ativa de SCLK |
| 17 | O sinal `DONE` **deve** ser asserted por exatamente **1 ciclo de clock do sistema** ao final da transação, após a desativação de `CS_N`. | Duração DONE = 1 T_clk |
| 18 | Após reset assíncrono (`RST_N` = 0), todos os sinais de saída **devem** atingir estado inativo em no máximo **1 ciclo de clock do sistema**. | t_reset ≤ 1 T_clk |
| 19 | O período mínimo entre duas transações consecutivas (`CS_N` reativado) **deve** ser de ao menos **2 períodos de `SCLK`**. | t_idle ≥ 2 T_sclk |

---

## 4. Interface

| Nome do Sinal | Direção | Largura (bits) | Tipo     | Descrição |
|---------------|---------|:--------------:|----------|-----------|
| `CLK`         | ENT     | 1              | Clock    | Clock do sistema. `SCLK` é derivado deste via `CLK_DIV`. |
| `RST_N`       | ENT     | 1              | Reset    | Reset assíncrono, ativo em nível baixo. |
| `START`       | ENT     | 1              | Controle | Pulso de um ciclo para iniciar uma transação SPI. |
| `SDO_DATA`    | ENT     | `DATA_WIDTH`   | Dados    | Palavra paralela a ser transmitida ao periférico via `SDO` (MSB first). |
| `SDI_DATA`    | SAÍ     | `DATA_WIDTH`   | Dados    | Palavra paralela recebida do periférico via `SDI` após a transação. |
| `BUSY`        | SAÍ     | 1              | Status   | Alto enquanto uma transação estiver em andamento. |
| `DONE`        | SAÍ     | 1              | Status   | Alto por 1 ciclo de `CLK` ao término da transação. |
| `SCLK`        | SAÍ     | 1              | SPI      | Clock serial para o periférico; polaridade conforme `CPOL`. |
| `SDO`         | SAÍ     | 1              | SPI      | Serial Data Out — dados seriais transmitidos ao periférico. |
| `SDI`         | ENT     | 1              | SPI      | Serial Data In — dados seriais recebidos do periférico. |
| `CS_N`        | SAÍ     | 1              | SPI      | Seleção de periférico único, ativo em nível baixo. |

> **Legenda de direção:** ENT = Entrada no módulo · SAÍ = Saída do módulo

---

## 5. Parâmetros

| Parâmetro    | Tipo    | Valor padrão | Intervalo válido | Descrição |
|--------------|---------|:------------:|:----------------:|-----------|
| `DATA_WIDTH` | Inteiro | `12`         | ≥ 1              | Largura da palavra de dados em bits. Define a duração da transação em `DATA_WIDTH` períodos de `SCLK`. |
| `CPOL`       | Bit     | `0`          | {0, 1}           | Polaridade do clock em repouso. `0` = `SCLK` inativo em nível baixo; `1` = `SCLK` inativo em nível alto. |
| `CPHA`       | Bit     | `0`          | {0, 1}           | Fase do clock. `0` = amostragem na primeira borda; `1` = amostragem na segunda borda de `SCLK`. |
| `CLK_DIV`    | Inteiro | `1`          | ≥ 1              | Divisor de clock inteiro. Frequência gerada: `f_SCLK = f_CLK / (2 × CLK_DIV)`. Valor `1` produz a frequência máxima. |
