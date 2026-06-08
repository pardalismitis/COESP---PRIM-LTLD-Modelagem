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

#### 📋 Overview

#### 🗺️ Input data

#### ⚙️ Requirements

#### 🚀 Running the workflow

```r
library(terra)
library(sf)

rast <- rast("predictors.tif")
plot(rast)
```

```bash
git clone https://github.com/usuario/repositorio.git
```

#### 📊 Outputs

#### 📚 Citation

```text
project/
├── scripts/
├── data/
├── outputs/
└── README.md
```

project/

├── 📁 data/

├── 📁 scripts/

├── 📁 outputs/

├── 📁 docs/

└── 📄 README.md

📄 LICENSE

### Requirements

- R 4.6
- terra
- sf
- flexsdm

## Version history

See the [CHANGELOG](CHANGELOG.md) for major workflow updates.
