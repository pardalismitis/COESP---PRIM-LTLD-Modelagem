if (!require(pacman)) install.packages("pacman")
pacman::p_load(readxl, openxlsx, dplyr, stringr)

remove.packages("terra")

install.packages("terra")
terra::gdal()
sf::sf_extSoftVersion()
# =========================================================
# DIRETÓRIO
# =========================================================
#base_dir <- "F:/modelos_salve"
base_dir <- "C:/Users/nicho/OneDrive/Documentos/especies_modelagem_primltld_22052026"
setwd(base_dir)
# =========================================================
# ARQUIVOS
# =========================================================
planilha_geral <- file.path(
  base_dir,
  "salve-exportacao-ocorrencias-fichas-26-03-2026-10-34-17_geral.csv" #Planilha geral do Salve
)

planilha_filtro <- file.path(
  base_dir,
  "especies_salve _occ2.xlsx" # Planilha com o nome das espécies que vamos modelar
)

saida_csv <- file.path(
  base_dir,
  "subplanilha_especies_occ2.csv"
)

saida_xlsx <- file.path(
  base_dir,
  "subplanilha_especies_occ2.xlsx"
)

saida_nao_encontradas <- file.path(
  base_dir,
  "especies_occ2_nao_encontradas.xlsx"
)

saida_resumo <- file.path(
  base_dir,
  "resumo_match_occ2.xlsx"
)

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

padronizar_nome_especie <- function(x) {
  x <- as.character(x)
  x <- trimws(x)
  x <- stringr::str_squish(x)
  x <- gsub("_", " ", x)
  x <- iconv(x, from = "", to = "ASCII//TRANSLIT")
  x <- tolower(x)
  x <- trimws(x)
  x[x == ""] <- NA
  x
}

ler_csv_seguro <- function(arquivo) {
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
  
  stop("Não foi possível ler a planilha geral em csv.")
}

# =========================================================
# CHECAR ARQUIVOS
# =========================================================
if (!file.exists(planilha_geral)) {
  stop(paste("Não encontrei a planilha geral em:", planilha_geral))
}

if (!file.exists(planilha_filtro)) {
  stop(paste("Não encontrei a planilha filtro em:", planilha_filtro))
}

# =========================================================
# LER PLANILHAS
# =========================================================
dados_full <- ler_csv_seguro(planilha_geral)
filtro_spp <- as.data.frame(readxl::read_excel(planilha_filtro))

cat("Colunas da planilha geral:\n")
print(names(dados_full))

cat("Colunas da planilha filtro:\n")
print(names(filtro_spp))

# =========================================================
# IDENTIFICAR COLUNAS DE ESPÉCIE
# =========================================================
col_sp_dados <- achar_coluna(
  dados_full,
  c("species", "especies", "especie", "Nome_Cientifico", "nome_cientifico", "scientific_name"),
  "espécie na planilha geral"
)

col_sp_filtro <- achar_coluna(
  filtro_spp,
  c("species_alvo", "species", "especies", "especie", "Nome_Cientifico", "nome_cientifico", "scientific_name"),
  "espécie na planilha filtro"
)

cat("Coluna de espécie na planilha geral:", col_sp_dados, "\n")
cat("Coluna de espécie na planilha filtro:", col_sp_filtro, "\n")

# =========================================================
# PADRONIZAR NOMES
# =========================================================
dados_full$sp_original <- as.character(dados_full[[col_sp_dados]])
filtro_spp$sp_original <- as.character(filtro_spp[[col_sp_filtro]])

dados_full$sp_match <- padronizar_nome_especie(dados_full$sp_original)
filtro_spp$sp_match <- padronizar_nome_especie(filtro_spp$sp_original)

species_alvo <- sort(unique(na.omit(filtro_spp$sp_match)))

# =========================================================
# FILTRAR PLANILHA GERAL
# =========================================================

subplanilha <- dados_full %>%
  filter(!is.na(sp_match)) %>%
  filter(sp_match %in% species_alvo)

unique(subplanilha$especie)
# =========================================================
# RESUMO DE MATCH
# =========================================================
resumo_match <- subplanilha %>%
  count(sp_match, name = "n_registros") %>%
  arrange(desc(n_registros), sp_match)

nao_encontradas <- filtro_spp %>%
  filter(!is.na(sp_match)) %>%
  distinct(sp_original, sp_match) %>%
  filter(!sp_match %in% unique(dados_full$sp_match))

subplanilha_saida <- subplanilha %>%
  select(-sp_original, -sp_match)

# =========================================================
# SALVAR RESULTADOS
# =========================================================
write.csv(subplanilha_saida, saida_csv, row.names = FALSE, na = "")
openxlsx::write.xlsx(subplanilha_saida, saida_xlsx, overwrite = TRUE)
openxlsx::write.xlsx(nao_encontradas, saida_nao_encontradas, overwrite = TRUE)
openxlsx::write.xlsx(resumo_match, saida_resumo, overwrite = TRUE)

# =========================================================
# MENSAGENS
# =========================================================
cat("\nConcluído.\n")
cat("Número de espécies na planilha filtro:", length(species_alvo), "\n")
cat("Número de registros filtrados:", nrow(subplanilha_saida), "\n")
cat("Número de espécies do filtro não encontradas:", nrow(nao_encontradas), "\n")

if (nrow(nao_encontradas) > 0) {
  cat("\nEspécies não encontradas:\n")
  print(nao_encontradas)
}

cat("\nArquivos salvos em:\n")
cat(saida_csv, "\n")
cat(saida_xlsx, "\n")
cat(saida_nao_encontradas, "\n")
cat(saida_resumo, "\n")


