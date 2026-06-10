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

- Baixar os arquivos necessários da pasta [Modelagem_PRIM](https://drive.google.com/drive/folders/1yb-a1Cl_mMCsTnTHJz_hS0JsqDgqcQvD?usp=drive_link) no Google Drive:

*📁 **HydroRIVERS_v10_sa**

*📁 **ottobacias1_7**

*🖼️ **mapbiomas.tif**

*🖼️ **PCA_ambVar_96.tif** e **PCA1km_ImportAlta_Basin.tif**

*📉 **cod.csv**



  
Occurrence records

↓

Pseudoabsences

↓

Model calibration

↓


Ensemble prediction

↓

Suitability maps

## Species Distribution Modeling Workflow

#### 📋 Estrutura dos dados nesse repositório

```r
Pasta raíz/
├── 📁 espécies/
  ├── 📉
  ├── 📉
├── 📁 HydroRIVERS_v10_sa/
  ├── 🌐 HydroRIVERS_v10_sa.shp
├── 📁 ottobacias1_7/
  ├── 🌐 geoft_bho_ach_otto_nivel_01.gpkg
  ...
  ├── 🌐geoft_bho_ach_otto_nivel_07.gpkg
├── 📁 temp_terra/
├── 🖼️ mapbiomas.tif
├── 🖼️ PCA_ambVar_96.tif
├── 🖼️ PCA1km_ImportAlta_Basin.tif
├── 📉 cod.csv
├── 📜 retirar_espécies_de geral.R
├── 📜 classes_mapbiomas.R
├── 📜 Protocolo_geral.R
└── 📁 Ooutput_modelagem_unificada_SALVE/
```

Cada um dos três scripts disponíveis representa uma etapa diferente do processo de criação dos SDMs dos alvos de conservação do PRIM:
* 📜 **retirar_espécies_de geral.R** é o script responsável por fazer o match entre a planilha com os nomes das espécies a serem modeladas e a planilha geral de ocorrências e retirar somente as entradas de interesse. O output principal contendo as informações dessas espécies é a planilha xxx.
* 📜 **classes_mapbiomas.R** é o script responsável por retirar as classes do Mapbiomas de acordo com as coordenadas de cada registro das espécies selecionadas no arquivo construido na etapa anterior. O produto principal é agora a planilha XX, contendo as informações do Mapbiomas.
* 📜 **Protocolo_geral.R** é o script principal, contendo toda a parte de definição dos protocolos e loop das modelagens. 

#### 🗺️ Input dos dados no seu computador

É recomendado que a estrutura do seu diretório seja semelhante à definida nos scripts, tanto para rodar todos os códigos sem problemas, quanto para facilitar a localização dos arquivos de entrada e saída e a colaboração entre os envolvidos no projeto, caso seja necessário.

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
├── 📁 temp_terra/
├── 🖼️ mapbiomas.tif
├── 🖼️ PCA_ambVar_96.tif
├── 🖼️ PCA1km_ImportAlta_Basin.tif
├── 📉 cod.csv
├── 📜 retirar_espécies_de geral.R
├── 📜 classes_mapbiomas.R
├── 📜 Protocolo_geral.R
└── 📁 Ooutput_modelagem_unificada_SALVE/
```
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
