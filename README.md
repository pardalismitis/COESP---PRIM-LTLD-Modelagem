# COESP/ICMBio - Modelagem dos Alvos de Conservação do PRIM-LTLD

![R](https://img.shields.io/badge/R-4.6-blue)
![PRIM](https://img.shields.io/badge/Project-PRIM--LTLD-green)
![COESP](https://img.shields.io/badge/Team-COESP-success)
![Status](https://img.shields.io/badge/Status-Active-orange)

## 📋 Visão Geral

Este repositório contém os scripts e instruções utilizados para modelagem da distribuição geográfica e construção dos mapas de adequabilidade de habitat dos alvos de conservação de fauna do PRIM-LTLD 🙂.

## 🖼️ Fluxograma do Workflow

```text
📊 Listas de Espécies
           ↓
🧭 Determinação do Protocolo
           ↓
🌊 Aquático / 🌿 Terrestre
           ↓
📍 Ocorrências + 🌎 Variáveis Ambientais
           ↓
📜 ESM / SDM / Kernel
           ↓
🏆 Mapa Final de adequabilidade
```

## 📑 Conteúdo

- [📂 Estrutura do Repositório](#-estrutura-do-repositório)
- [🚀 Como Executar o Workflow](#-como-executar-o-workflow)
- [🗺️ Outputs Gerados](#️-outputs-gerados)
- [📦 Dependências](#-dependências)
- [📝 Histórico de Versões](#-histórico-de-versões)
- [📚 Referências](#-referências)


## 📁 Estrutura do repositório

Dentro da pasta **📁 Scripts/** no diretório inicial, você vai encontrar duas subpastas principais, contendo a versão atualmente recomendada do workflow **(Scripts/Versão Atual/📜)**, e as versões históricas preservadas para reprodutibilidade **(Scripts/Versões Arquivadas/📦)**. Dentro estarão os três scripts do R que estão sendo usados no processo de modelagem da distribuição dos alvos de conservação de fauna:

```text
📁 Scripts/
├── 📁 Versão Atual/
├── 📁 Versões Arquivadas/
    ├── 📁 Versão 1.0.X/
    ├── 📁 Versão 1.0.Y/
    ├── ...
├── 📝 CHANGELOG.md
└── 📖 README.md
```

* A pasta da versão atual contém os três scripts principais em R que estão sendo utilizados no processo de modelagem da distribuição geográfica dos alvos de conservação da fauna:

```text
📁 Scripts/
├── 📁 Versão Atual/
    ├── 📜 1_retirar_especies_de geral_v1.0.Z.R
    ├── 📜 2_classes_mapbiomas_v1.0.Z.R    
    └── 📜 3_protocolo_geral_v1.0.Z.R
```
* Cada um desses scripts disponíveis representa uma etapa diferente do processo de criação dos rasters finais das espécies:  


| Script | Função |
|--------|---------|
| `📜 1_retirar_especies_de geral.R` | Faz o *match* entre a planilha com os nomes das espécies a serem modeladas e a planilha geral de ocorrências e o *subset* somente com as entradas de interesse. O output principal contendo as informações dessas espécies é o arquivo 📊 subplanilha_especies_occ.xlsx. |
| `📜 2_classes_mapbiomas.R` | Retira as classes do MapBiomas de acordo com as coordenadas de cada registro das espécies selecionadas no arquivo construído na etapa anterior. O produto principal é o arquivo 📊 subplanilha_especies_occ_com_mapbiomas.xlsx. |
| `📜 3_protocolo_geral.R` | É o script principal, contendo toda a parte de definição dos protocolos e loop das modelagens. |


## 🚀 Como executar o workflow


### 📥 1. Obtenha os Dados de Entrada

* Baixe os arquivos necessários da pasta [Modelagem_PRIM](https://drive.google.com/drive/folders/1yb-a1Cl_mMCsTnTHJz_hS0JsqDgqcQvD?usp=drive_link) no Google Drive:

* 📁 **HydroRIVERS_v10_sa** contém o shape das linhas dos cursos dos rios.

* 📁 **ottobacias1_7** contêm os arquivos espaciais das bacias hidrográficas Ottocodificadas de 1 a 7.

* 🖼️ **mapbiomas.tif** é o raster com as informações de uso de solo do MapBiomas, coleção 10.

* 🖼️ **PCA_ambVar_96.tif** e **PCA1km_ImportAlta_Basin.tif** são os rasters das PCAs (para os  protocolos com espécies terrestres e aquáticas, respectivamente).

* 📊 **cod.csv** são os códigos das cores de cada classe do solo do MapBiomas.

* 📊 **salve-exportacao-ocorrencias-fichas-26-03-2026-10-34-17.csv** é a planilha exportada do SALVE com todas as ocorrências gerais das espécies de interesse.

* 📊 **especies_salve _occ2.xlsx** é a lista de espécies que deverão ser modeladas. Note que apesar de estar incluída no na pasta Modelagem_PRIM, essa lista precisa ser atualizada de acordo com o grupo a ser trabalhado.


### 💾 2. Organize os Arquivos Localmente

* Extraia todos os arquivos da pasta Modelagem_PRIM, bem como os scripts desse repositório, para o seu diretório principal. É recomendado que a estrutura da sua pasta raiz seja semelhante à definida nos scripts, tanto para rodar todos os códigos sem problemas, quanto para facilitar a localização dos arquivos de entrada e saída e a colaboração entre os envolvidos no projeto, caso seja necessário.

Exemplo:
```text
📁 Pasta raiz/
├── 📁 especies/
    ├── 📊 especies_salve _occ2.xlsx
    └── 📊 subplanilha_especies_occ2_com_mapbiomas.xlsx
├── 📁 HydroRIVERS_v10_sa/
    └── 🌐 HydroRIVERS_v10_sa.shp
├── 📁 ottobacias1_7/
    ├── 🌐 geoft_bho_ach_otto_nivel_01.gpkg
    ...
    └── 🌐geoft_bho_ach_otto_nivel_07.gpkg
├── 📁 temp_terra/*
├── 🖼️ mapbiomas.tif
├── 🖼️ PCA_ambVar_96.tif
├── 🖼️ PCA1km_ImportAlta_Basin.tif
├── 📊 cod.csv
├── 📜 retirar_espécies_de geral.R
├── 📜 classes_mapbiomas.R
├── 📜 Protocolo_geral.R
└── 📁 Output_modelagem_unificada_SALVE/
```
* É recomendado que a pasta de arquivos temporários do *terra* seja alterada para a raíz do diretório do seu projeto.


### ⚙️ 3. Executar os Scripts

* Os scripts devem ser rodados na ordem de numeração (01, 02 e 03). Como cada planilha de resultado gerada em cada etapa deve ser usada para alimentar o script da etapa posterior, recomenda-se que os nomes originais dos arquivos de saída sejam mantidos padronizados. No final do script 3, há um código extra para rodar espécies individualmente em caso de testes.


##  🗺️ Outputs Gerados


* Os resultados dos modelos são criados automaticamente com a execução do *loop* na pasta **output_modelagem_unificada_SALVE**, localizada na raiz do diretório principal, com a seguinte configuração:

```text
📁 Pasta raiz/
├── 📁 ...
├── 📁 output_modelagem_unificada_SALVE
    ├── 📁 kernel_menos_5_pontos/
        ├── 🖼️ espécie_1_cenario1.tif
        ├── 🖼️ espécie_1_cenario2.tif
        ├── 🖼️ espécie_1_cenario3.tif
        ├── 🖼️ espécie_1.tif
        ├── 🌐 espécie_1_occurrences.gpkg
        ├── ...
    ├── 📁 terrestres/
        ├── 📁 msdm_ESM/
            ├── 🖼️ espécie_2_ESM.tif
            ├── ...
        ├── 📁 msdm_SDM/
            ├── 🖼️ espécie_3_SDM.tif
            ├── ...
        ├── 📁 tabelas_ESM/
            ├── 📊 espécie_2_ESM.csv
            ├── ...
        └── 📁 tabelas_SDM/
            ├── 📊 espécie_3_SDM.csv
            ├── ...
    ├── 📁 aquaticas/
        ├── ...
    ├── 📊 especies_filtro_nao_encontradas_na_occ2.xlsx
    └── 📊 log_execucao_modelagem.csv
```
* A pasta **📁 kernel_menos_5_pontos** contém os rasters dos alvos que foram rodados com o protocolo para espécies com menos que 5 pontos de ocorrência. Todas as espécies possuem quatro rasters, representando três cenários distintos e um raster final combinando todos os cenários, além do shape de ocorrências. 

* As pastas **📁 terrestres** e **📁 aquaticas** têm basicamente a mesma estrutura interna, e contêm os rasters e tabelas dos alvos que foram rodados com os protocolos para espécies com até 20 pontos de ocorrência (ESM, *Ensemble of Small Models*) ou com mais de 20 pontos de ocorrência (SDM, *Species Distribution Models*).

* Os arquivos **📊 especies_filtro_nao_encontradas_na_occ2.xlsx** e **📊 log_execucao_modelagem.csv** listam as espécies que não deram *match* entre a planilha de alvos de interesse e a planilha de ocorrências, e o sumário de execução do *loop* dos modelos (incluindo sucessos/falhas), respectivamente.


## 📦 Dependências

- R (de preferência o 4.6)
- terra
- sf
- flexsdm


## 📝 Histórico de Versões

* Consulte o [CHANGELOG](CHANGELOG.md) para conferir as principais atualizações do fluxo de trabalho e dos códigos usados no projeto.


### 📚 Referências
* Ver o manuscrito "Adequabilidade Ambiental das Espécies Fauna Ameaçada".
