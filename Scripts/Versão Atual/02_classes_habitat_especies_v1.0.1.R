# Carregar pacotes

if (!require(pacman)) install.packages("pacman")
pacman::p_load(dplyr, readxl, openxlsx, stringr)

# =========================================================

# DIRETÓRIO

# =========================================================

base_dir <- "C:/Users/crist/OneDrive/Desktop/protocolo_matheus/modelos_salve"

# =========================================================

# ARQUIVOS

# =========================================================

planilha_entrada <- file.path(base_dir, "subplanilha_especies_occ2.xlsx")

saida_csv  <- file.path(base_dir, "subplanilha_especies_occ2_com_mapbiomas.csv")
saida_xlsx <- file.path(base_dir, "subplanilha_especies_occ2_com_mapbiomas.xlsx")

# =========================================================

# FUNÇÕES AUXILIARES

# =========================================================

normalizar_nome_coluna <- function(x) {
  x <- make.names(x)
  x <- gsub("\\.+", "_", x)
  tolower(x)
}

achar_coluna <- function(df, candidatos, rotulo) {
  nomes_orig <- names(df)
  nomes_norm <- normalizar_nome_coluna(nomes_orig)
  cand_norm  <- normalizar_nome_coluna(candidatos)
  
  idx <- match(cand_norm, nomes_norm, nomatch = 0)
  idx <- idx[idx > 0]
  
  if (length(idx) == 0) {
    stop(
      paste0(
        "Não encontrei a coluna de ", rotulo,
        ". Colunas disponíveis: ",
        paste(nomes_orig, collapse = ", ")
      )
    )
  }
  
  nomes_orig[idx[1]]
}

ler_planilha <- function(arquivo) {
  
  ext <- tolower(tools::file_ext(arquivo))
  
  if (ext == "csv") {
    
    tentativas <- list(
      function() read.csv(arquivo, sep = ";", stringsAsFactors = FALSE, fileEncoding = "UTF-8"),
      function() read.csv(arquivo, sep = ",", stringsAsFactors = FALSE, fileEncoding = "UTF-8"),
      function() read.csv(arquivo, sep = ";", stringsAsFactors = FALSE, fileEncoding = "latin1"),
      function() read.csv(arquivo, sep = ",", stringsAsFactors = FALSE, fileEncoding = "latin1")
    )
    
    for (f in tentativas) {
      x <- tryCatch(f(), error = function(e) NULL)
      if (!is.null(x) && ncol(x) > 1) return(x)
    }
    
    stop("Não foi possível ler o CSV.")
    
  }
  
  if (ext %in% c("xlsx", "xls")) {
    return(as.data.frame(read_excel(arquivo)))
  }
  
  stop("Formato não suportado.")
}

# =========================================================

# LER PLANILHA

# =========================================================

dados <- ler_planilha(planilha_entrada)

# =========================================================

# IDENTIFICAR COLUNA HABITAT

# =========================================================

col_habitat <- achar_coluna(
  dados,
  c("habitat"),
  "habitat"
)

# =========================================================

# TABELA DE CORRESPONDÊNCIA

# =========================================================

correspondencia <- data.frame(
  habitat = c(
    "",
    "13. Outros",
    "9. Outros",
    "Desconhecido",
    "13. Desconhecido",
    
    "7. Rios, córregos, corredeiras e cachoeiras permanentes",
    "6. Rios, córregos sazonais, intermitentes ou irregulares",
    "4. Lagos/Lagoas",
    "Ambientes de Água Doce",
    
    "Ambientes Marinhos",
    
    "15. Cavernas",
    
    "1.2 Brejos/Poças Temporários",
    
    "2. Igapo",
    
    "1. Campinarana (Campina)",
    
    "2. Estepe (Campos do Sul do Brasil)",
    
    "4. Floresta Estacional Semidecidual (Floresta Tropical Subcaducifólia)",
    "3. Floresta Estacional Decidual (Floresta Tropical Caducifólia)",
    "6.2 Floresta Ombrófila Densa Aluvial",
    "6. Floresta Ombrófila Densa (Floresta Pluvial Tropical)",
    "Amazônia",
    
    "Ambientes Terrestres"
    
  ),
  
  classe_mapbiomas = c(
    NA,
    NA,
    NA,
    NA,
    NA,
    
    33,
    33,
    33,
    33,
    
    33,
    
    29,
    
    11,
    
    6,
    
    49,
    
    12,
    
    3,
    3,
    6,
    3,
    3,
    
    NA
    
  ),
  
  fonte_habitat = c(
    NA,
    NA,
    NA,
    NA,
    NA,
    
    "mapbiomas",
    "mapbiomas",
    "mapbiomas",
    "mapbiomas",
    
    "mapbiomas",
    
    "caverna",   # <- Cavernas
    
    "mapbiomas",
    "mapbiomas",
    "mapbiomas",
    "mapbiomas",
    
    "mapbiomas",
    "mapbiomas",
    "mapbiomas",
    "mapbiomas",
    "mapbiomas",
    
    NA
  ),
  
  stringsAsFactors = FALSE
)

# =========================================================

# TABELA DE CÓDIGOS MAPBIOMAS

# =========================================================

cod <- data.frame(
  code = c(
    1,3,4,5,6,49,10,11,12,32,29,50,14,15,18,19,39,20,
    62,41,36,46,47,35,48,9,21,22,23,24,30,75,25,26,
    33,31,27
  ),
  
  label = c(
    "Forest",
    "Forest Formation",
    "Savanna Formation",
    "Mangrove",
    "Floodable Forest",
    "Wooded Sandbank Vegetation",
    "Herbaceous and Shrubby Vegetation",
    "Wetland",
    "Grassland",
    "Hypersaline Tidal Flat",
    "Rocky Outcrop",
    "Herbaceous Sandbank Vegetation",
    "Farming",
    "Pasture",
    "Agriculture",
    "Temporary Crop",
    "Soybean",
    "Sugar cane",
    "Cotton (beta)",
    "Other Temporary Crops",
    "Perennial Crop",
    "Coffee",
    "Citrus",
    "Palm Oil",
    "Other Perennial Crops",
    "Forest Plantation",
    "Mosaic of Uses",
    "Non vegetated area",
    "Beach, Dune and Sand Spot",
    "Urban Area",
    "Mining",
    "Photovoltaic Power Plant (beta)",
    "Other non Vegetated Areas",
    "Water",
    "River, Lake and Ocean",
    "Aquaculture",
    "Not Observed"
  ),
  
  stringsAsFactors = FALSE
)

# =========================================================

# FAZER CORRESPONDÊNCIA

# =========================================================

dados_out <- dados %>%
  left_join(
    correspondencia,
    by = setNames("habitat", col_habitat)
  ) %>%
  left_join(
    cod,
    by = c("classe_mapbiomas" = "code")
  ) %>%
  rename(habitat_mapbiomas = label)

# =========================================================

# ORGANIZAR COLUNAS

# =========================================================

dados_out <- dados_out %>%
  select(
    everything(),
    classe_mapbiomas,
    habitat_mapbiomas
  )

# =========================================================

# SALVAR

# =========================================================

write.csv(
  dados_out,
  saida_csv,
  row.names = FALSE,
  na = ""
)

openxlsx::write.xlsx(
  dados_out,
  saida_xlsx,
  overwrite = TRUE
)

cat("Concluído.\n")
cat("Registros processados:", nrow(dados_out), "\n")
cat("CSV salvo em:", saida_csv, "\n")
cat("XLSX salvo em:", saida_xlsx, "\n")
