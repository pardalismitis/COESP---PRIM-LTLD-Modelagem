# COESP---PRIM-LTLD-Modelagem
Só um repositório provisório pra compartilhar os últimos scripts que usamos :)

# Species Distribution Modeling Workflow

![R](https://img.shields.io/badge/R-4.6-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Status-Active-success)

## 📋 Visão Geral
Só um repositório provisório para compartilharmos os últimos scripts que usamos :)

Scripts e instruções usados para modelar a distribuição e gerar os mapas de adequabilidade de habitat dos alvos de conservação de fauna do PRIM-LTLD e demais projetos da COESP/ICMBio.

# Workflow

## Dados Básicos

- Baixar os arquivos necessários da pasta [Modelagem_PRIM](https://drive.google.com/drive/folders/1yb-a1Cl_mMCsTnTHJz_hS0JsqDgqcQvD?usp=drive_link) no Google Drive:

*📁 **HydroRIVERS_v10_sa** contém os shapes dos rios.

*📁 **ottobacias1_7** contém os arquivos espaciais das bacias hidrográficas Ottocodificadas de 1 à 7

*🖼️ **mapbiomas.tif** é o raster com as informações de uso de solo do MapBiomas, coleção 10.

*🖼️ **PCA_ambVar_96.tif** e **PCA1km_ImportAlta_Basin.tif** sãos os rasters das PCAs (para o  protocolo de espécies terrestres e aquáticas, respectivamente).

*📉 **cod.csv** são os códigos das cores de cada classe do solo do MapBiomas.

*📉 **salve-exportacao-ocorrencias-fichas-26-03-2026-10-34-17.csv** é a planilha exportada do SALVE com todas as ocorrências gerais das espécies de interesse.

*📉 **especies_salve _occ2.xlsx** é a lista de espécies que deverão ser modeladas. Note que apesar de estar incluída no na pasta Modelagem_PRIM, essa lista precisa ser atualizada de acordo com o grupo a ser trabalhado.

## 📋 Estrutura dos dados nesse repositório

Cada um dos três scripts disponíveis representa uma etapa diferente do processo de criação dos SDMs dos alvos de conservação do PRIM:

* 📜 **1_retirar_espécies_de geral.R** é o script responsável por fazer o match entre a planilha com os nomes das espécies a serem modeladas e a planilha geral de ocorrências e retirar somente as entradas de interesse. O output principal contendo as informações dessas espécies é a planilha xxx.
* 📜 **2_classes_mapbiomas.R** é o script responsável por retirar as classes do Mapbiomas de acordo com as coordenadas de cada registro das espécies selecionadas no arquivo construido na etapa anterior. O produto principal é agora a planilha XX, contendo as informações do Mapbiomas.
* 📜 **3_Protocolo_geral.R** é o script principal, contendo toda a parte de definição dos protocolos e loop das modelagens.

- Os scripts devem ser rodados nessa ordem (01, 02 e 03).

## 🗺️ Input dos dados no seu computador

É recomendado que a estrutura do seu diretório seja semelhante à definida nos scripts, tanto para rodar todos os códigos sem problemas, quanto para facilitar a localização dos arquivos de entrada e saída e a colaboração entre os envolvidos no projeto, caso seja necessário.

Exemplo:
```text
Pasta raíz/
├── 📁 espécies/
  ├── 📉 especies_salve _occ2.xlsx
  ├── 📉 subplanilha_especies_occ2_com_mapbiomas.xlsx
├── 📁 HydroRIVERS_v10_sa/
  ├── 🌐 HydroRIVERS_v10_sa.shp
├── 📁 ottobacias1_7/
  ├── 🌐 geoft_bho_ach_otto_nivel_01.gpkg
  ...
  ├── 🌐geoft_bho_ach_otto_nivel_07.gpkg
├── 📁 temp_terra/*
├── 🖼️ mapbiomas.tif
├── 🖼️ PCA_ambVar_96.tif
├── 🖼️ PCA1km_ImportAlta_Basin.tif
├── 📉 cod.csv
├── 📜 retirar_espécies_de geral.R
├── 📜 classes_mapbiomas.R
├── 📜 Protocolo_geral.R
└── 📁 Ooutput_modelagem_unificada_SALVE/
```
* É recomendado que a pasta de arquivos temporários do terra seja alterada para a raíz do diretório do seu projeto.

## Species Distribution Modeling Workflow
Occurrence records

↓

Pseudoabsences

↓

Model calibration

↓


Ensemble prediction

↓

Suitability maps


#### 📊 Outputs

Os resultados dos modelos são criados na pasta **output_modelagem_unificada_SALVE**, localizada na raiz do diretório.

#### 🚀 Rodando os scripts

```text
├── 📁 data/
├── 📁 scripts/
├── 📁 outputs/
├── 📁 docs/
└── 📄 README.md
```

#### ⚙️ Requerimentos

- R (de preferência 4.6
- terra
- sf
- flexsdm


#### 📚 Citações


## Histórico das Versões

Consulte o [CHANGELOG](CHANGELOG.md) para obter as principais atualizações do fluxo de trabalho.
