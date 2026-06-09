# COESP---PRIM-LTLD-Modelagem
Só um repositório provisório pra compartilhar os últimos scripts que usamos :)

# Species Distribution Modeling Workflow

![R](https://img.shields.io/badge/R-4.6-blue)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Status-Active-success)

Scripts used to model species distributions and generate habitat suitability maps.

# Workflow

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

#### 📋 Visão Geral

#### 🗺️ Input dos dados
```text
project/
├── scripts/
├── data/
├── outputs/
└── README.md

├── 📁 data/
├── 📁 scripts/
├── 📁 outputs/
├── 📁 docs/
└── 📄 README.md
```
#### ⚙️ Requirementos

- R (de preferência 4.6
- terra
- sf
- flexsdm

#### 🚀 Running the workflow

```text
├── 📁 data/
├── 📁 scripts/
├── 📁 outputs/
├── 📁 docs/
└── 📄 README.md
```


#### 📊 Outputs

Os resultados dos modelos são criados na pasta **output_modelagem_unificada_SALVE**, localizada na raiz do diretório.

#### 📚 Citações


## Histórico das Versões

Consulte o [CHANGELOG](CHANGELOG.md) para obter as principais atualizações do fluxo de trabalho.
