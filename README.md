# COESP/ICMBio - Modelagem dos Alvos de Conservação do PRIM-LTLD
Só um repositório provisório pra compartilhar os últimos scripts que usamos :)

# Species Distribution Modeling Workflow

![R](https://img.shields.io/badge/R-4.6-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Status-Active-success)

## 📋 Visão Geral

Só um repositório provisório para compartilhar os scripts e algumas instruções usadas para modelar a distribuição e gerar os mapas de adequabilidade de habitat dos alvos de conservação de fauna do PRIM-LTLD e demais projetos da COESP 🙂.

## 📋 Estrutura dos dados nesse repositório

Dentro da pasta raiz desse repositório, você vai encontrar os três scripts do R que estão sendo usados no proceso de modelagem da distribuição dos alvos de conservação do PRIM. Cada um dos scripts disponíveis representa uma etapa diferente do processo de criação dos rasters finais das espécies do PRIM:

* 📜 **1_retirar_espécies_de geral.R** é o script responsável por fazer o *match* entre a planilha com os nomes das espécies a serem modeladas e a planilha geral de ocorrências e fazer o *subset* somente com as entradas de interesse. O output principal contendo as informações dessas espécies é a planilha xxx.
* 📜 **2_classes_mapbiomas.R** é o script responsável por retirar as classes do Mapbiomas de acordo com as coordenadas de cada registro das espécies selecionadas no arquivo construido na etapa anterior. O produto principal é agora a planilha XX, contendo as informações do Mapbiomas.
* 📜 **3_Protocolo_geral.R** é o script principal, contendo toda a parte de definição dos protocolos e loop das modelagens.

- Os scripts devem ser rodados nessa ordem (01, 02 e 03).

## Como usar?

## 1. 📑 Obter os Dados Básicos

- Baixe os arquivos necessários da pasta [Modelagem_PRIM](https://drive.google.com/drive/folders/1yb-a1Cl_mMCsTnTHJz_hS0JsqDgqcQvD?usp=drive_link) no Google Drive:

*📁 **HydroRIVERS_v10_sa** contém os shapes dos rios.

*📁 **ottobacias1_7** contém os arquivos espaciais das bacias hidrográficas Ottocodificadas de 1 à 7

*🖼️ **mapbiomas.tif** é o raster com as informações de uso de solo do MapBiomas, coleção 10.

*🖼️ **PCA_ambVar_96.tif** e **PCA1km_ImportAlta_Basin.tif** sãos os rasters das PCAs (para os  protocolos com espécies terrestres e aquáticas, respectivamente).

*📊 **cod.csv** são os códigos das cores de cada classe do solo do MapBiomas.

*📊 **salve-exportacao-ocorrencias-fichas-26-03-2026-10-34-17.csv** é a planilha exportada do SALVE com todas as ocorrências gerais das espécies de interesse.

*📊 **especies_salve _occ2.xlsx** é a lista de espécies que deverão ser modeladas. Note que apesar de estar incluída no na pasta Modelagem_PRIM, essa lista precisa ser atualizada de acordo com o grupo a ser trabalhado.

##  Estrutura dos dados nesse repositório

Cada um dos três scripts disponíveis representa uma etapa diferente do processo de criação dos SDMs dos alvos de conservação do PRIM:

* 📜 **1_retirar_espécies_de geral.R** é o script responsável por fazer o match entre a planilha com os nomes das espécies a serem modeladas e a planilha geral de ocorrências e retirar somente as entradas de interesse. O output principal contendo as informações dessas espécies é a planilha xxx.
* 📜 **2_classes_mapbiomas.R** é o script responsável por retirar as classes do Mapbiomas de acordo com as coordenadas de cada registro das espécies selecionadas no arquivo construido na etapa anterior. O produto principal é agora a planilha XX, contendo as informações do Mapbiomas.
* 📜 **3_Protocolo_geral.R** é o script principal, contendo toda a parte de definição dos protocolos e loop das modelagens.

- Os scripts devem ser rodados nessa ordem (01, 02 e 03).

## 🗺️ 2. Fazer o *input* dos dados no seu computador

Extraia todos os arquivos da pasta Modelagem_PRIM, bem como os scripts desse repositório, para o seu diretório principal. É recomendado que a estrutura do seu diretório seja semelhante à definida nos scripts, tanto para rodar todos os códigos sem problemas, quanto para facilitar a localização dos arquivos de entrada e saída e a colaboração entre os envolvidos no projeto, caso seja necessário.

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
* É recomendado que a pasta de arquivos temporários do terra seja alterada para a raíz do diretório do seu projeto.

#### 🚀 Rodando os scripts
- Os scripts devem ser executados na ordem de numeração (01, 02 e 03). Como cada planilha de resultado gerada em cada etapa deve ser usada para alimentar o script da etapa posterior, recomenda-se que os nomes originais dos arquivos de saída sejam mantidos padronizados. O loop principal está

####  🗃️ Outputs

Os resultados dos modelos são criados automaticamente com a execução do *loop* na pasta **output_modelagem_unificada_SALVE**, localizada na raiz do diretório principal, com a seguinte configuração:

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
A pasta **📁 kernel_menos_5_pontos** contém os rasters dos alvos que foram rodados com o protocolo para espécies com menos que 5 pontos de ocorrência. Todas as espécies possuem quatro rasters, representando três cenários distintos e um raster final combinando todos os cenários, além do shape de ocorrências. 

As pastas **📁 terrestres** e **📁 aquaticas** têm basicamente a mesma estrutura interna, e contêm os rasters e tabelas dos alvos que foram rodados com os protocolos para espécies com até 20 pontos de ocorrência (ESM, Ensemble of Small Models) ou com mais de 20 pontos de ocorrência (SDM, Species Distribution Models).

Os arquivos **📊 especies_filtro_nao_encontradas_na_occ2.xlsx** e **📊 log_execucao_modelagem.csv** listam as espécies que não deram *match* entre a planilha de alvos de interesse e a planilha de ocorrências, e o sumário de execução do *loop* dos modelos (incluindo sucessos/falhas), respectivamente

#### ⚙️ Requerimentos

- R (de preferência o 4.6)
- terra
- sf
- flexsdm

## Histórico das Versões

- Consulte o [CHANGELOG](CHANGELOG.md) para conferir as principais atualizações do fluxo de trabalho e dos códigos usados no projeto.

#### 📚 Citações
- Ver o manuscrito "Adequabilidade Ambiental das Espécies Fauna Ameaçada".
