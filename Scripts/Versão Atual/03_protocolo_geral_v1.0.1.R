# =========================================================
# PROTOCOLO UNIFICADO DE MODELAGEM - SALVE
# - Usa a planilha salve-exportacao-ocorrencias-fichas-26-03-2026-10-34-17 como ocorrências
# - Usa especies_salve _occ2 como filtro geral das espécies
# - Espécies com >= min_pontos_flexsdm: flexsdm/ESM/SDM
# - Espécies com <  min_pontos_flexsdm: HAB/kernel
# - Se o protocolo primário falhar, tenta fallback quando possível
# - Se tudo falhar, registra o erro e continua para a próxima espécie
# =========================================================

rm(list = ls())
gc()

system.file("proj", package = "sf")
sf::sf_proj_info("path")

Sys.unsetenv("PROJ_LIB")
Sys.unsetenv("PROJ_DATA")

Sys.setenv(
  PROJ_LIB = "C:/Users/nicho/AppData/Local/R/win-library/4.6/sf/proj"
)

# -----------------------------
# PACOTES
# -----------------------------
if (!require(pacman)) install.packages("pacman")
pacman::p_load(
  flexsdm, terra, sf, dplyr, readxl, openxlsx, stringr,
  ggplot2, viridis, patchwork, tidyr, Cairo, grid, gridExtra,
  igraph, doParallel, beepr
)

options(scipen = 999)
options(dplyr.summarise.inform = FALSE)
sf::sf_use_s2(FALSE)

# =========================================================
# CONFIGURAÇÕES PRINCIPAIS
# =========================================================
base_dir <- "C:/Users/crist/OneDrive/Desktop/protocolo_matheus/rodar_protocolo"
setwd(base_dir)

# ---------------------------------------------------------
# PLANILHAS DO SEU PROJETO
# ---------------------------------------------------------
# Nomes reais das suas planilhas, sem a extensão.
# O script procura automaticamente .csv, .xls ou .xlsx dentro de base_dir.
nome_planilha_ocorrencias <- "subplanilha_especies_occ2_com_mapbiomas"
# nome_planilha_ocorrencias <- "salve-exportacao-ocorrencias-fichas-26-03-2026-10-34-17"
nome_planilha_filtro <- "especies_salve_occ2"

# Caminhos manuais opcionais.
# Deixe como NA_character_ para o script localizar pelos nomes acima.
# Use o caminho completo apenas se quiser forçar um arquivo específico.
# Exemplo:
# path_ocorrencias_manual <- "F:/modelos_salve/salve-exportacao-ocorrencias-fichas-26-03-2026-10-34-17.csv"
# path_filtro_especies_manual <- "F:/modelos_salve/especies_salve _occ2.xlsx"
#path_ocorrencias_manual <- NA_character_
#path_filtro_especies_manual <- NA_character_
path_ocorrencias_manual <- "C:/Users/crist/OneDrive/Desktop/protocolo_matheus/rodar_protocolo/subplanilha_especies_occ2_com_mapbiomas.xlsx"

path_filtro_especies_manual <- "C:/Users/crist/OneDrive/Desktop/protocolo_matheus/rodar_protocolo/especies_salve_occ2.xlsx"
# ---------------------------------------------------------
# REGRA DE DECISÃO ENTRE OS PROTOCOLOS
# ---------------------------------------------------------
# >= 5 pontos: protocolo flexsdm, com ESM ou SDM.
# <  5 pontos: protocolo HAB/kernel.
# Se quiser que espécies com exatamente 5 pontos também usem HAB/kernel,
# mude para min_pontos_flexsdm <- 6.
min_pontos_flexsdm <- 5

# Se o protocolo flexsdm falhar em uma espécie com >=5 pontos,
# o script tenta automaticamente o protocolo HAB/kernel como fallback.
permitir_fallback <- TRUE

# ---------------------------------------------------------
# FILTROS OPCIONAIS
# ---------------------------------------------------------
# Recomendo deixar FALSE se a sua planilha occ2 já é a planilha filtrada.
# Se TRUE, o script aplicará filtro por bioma e categoria_validada quando
# essas colunas existirem.
aplicar_filtro_bioma_categoria <- FALSE

biomas_alvo <- c("Pantanal", "Pampa", "Caatinga")
categorias_alvo <- c(
  "Em Perigo (EN)",
  "Vulnerável (VU)",
  "Criticamente em Perigo (CR)",
  "Criticamente em Perigo (CR) (PE)"
)

# Distância usada no filtro geográfico do protocolo flexsdm.
distancia <- 10

# ---------------------------------------------------------
# SAÍDAS
# ---------------------------------------------------------
output_dir <- file.path(base_dir, "output_modelagem_unificada_SALVE")
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

output_kernel <- file.path(output_dir, "kernel_menos_5_pontos")
dir.create(output_kernel, recursive = TRUE, showWarnings = FALSE)

temp_dir <- file.path(base_dir, "temp_terra")
dir.create(temp_dir, recursive = TRUE, showWarnings = FALSE)
terraOptions(memfrac = 0.8, tempdir = temp_dir)

# =========================================================
# FUNÇÕES AUXILIARES GERAIS
# =========================================================
normalizar_nome_coluna <- function(x) {
  x <- make.names(x)
  x <- gsub("\\.+", "_", x)
  tolower(x)
}

achar_coluna <- function(df, candidatos, rotulo, obrigatoria = TRUE) {
  nomes_orig <- names(df)
  nomes_norm <- normalizar_nome_coluna(nomes_orig)
  cand_norm  <- normalizar_nome_coluna(candidatos)
  idx <- match(cand_norm, nomes_norm, nomatch = 0)
  idx <- idx[idx > 0]
  if (length(idx) == 0) {
    if (obrigatoria) {
      stop(
        paste0(
          "Não encontrei a coluna de ", rotulo, ". Colunas disponíveis: ",
          paste(nomes_orig, collapse = ", ")
        )
      )
    } else {
      return(NA_character_)
    }
  }
  nomes_orig[idx[1]]
}

padronizar_nome_especie <- function(x) {
  x <- as.character(x)
  x <- stringr::str_squish(x)
  x <- trimws(x)
  x[x == ""] <- NA_character_
  x
}

parse_num_br <- function(x) {
  # Lê números tanto no padrão 10.5 quanto 10,5.
  # Também remove espaços e aspas que às vezes vêm de CSV exportado.
  x <- as.character(x)
  x <- trimws(x)
  x <- gsub('"', '', x, fixed = TRUE)
  x <- gsub("'", '', x, fixed = TRUE)
  x <- gsub("\\s+", "", x)
  x <- gsub(",", ".", x, fixed = TRUE)
  suppressWarnings(as.numeric(x))
}

# Chave de comparação entre planilhas.
# Serve para evitar que diferenças como maiúsculas/minúsculas, acentos,
# espaços duplos ou nomes com underline impeçam a correspondência das espécies.
normalizar_chave_especie <- function(x) {
  x <- padronizar_nome_especie(x)
  x <- gsub("_", " ", x)
  x <- gsub("\\s+", " ", x)
  x <- trimws(x)
  x <- iconv(x, from = "", to = "ASCII//TRANSLIT")
  x <- tolower(x)
  x[x == ""] <- NA_character_
  x
}

nome_arquivo_sp <- function(x) {
  x <- iconv(x, from = "", to = "ASCII//TRANSLIT")
  x <- gsub("[^A-Za-z0-9]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  x
}

find_first_file <- function(pattern, path = base_dir, recursive = TRUE, ignore.case = TRUE) {
  if (is.na(path) || !dir.exists(path)) return(NA_character_)
  arqs <- list.files(
    path = path, pattern = pattern, full.names = TRUE,
    recursive = recursive, ignore.case = ignore.case
  )
  arqs <- arqs[file.exists(arqs)]
  if (length(arqs) == 0) return(NA_character_)
  arqs[1]
}

find_first_dir <- function(pattern, path = base_dir, recursive = TRUE, ignore.case = TRUE) {
  if (is.na(path) || !dir.exists(path)) return(NA_character_)
  dirs <- list.dirs(path = path, recursive = recursive, full.names = TRUE)
  dirs <- dirs[grepl(pattern, basename(dirs), ignore.case = ignore.case)]
  if (length(dirs) == 0) return(NA_character_)
  dirs[1]
}

find_all_files <- function(path, pattern = "\\.tif$", recursive = TRUE, ignore.case = TRUE) {
  if (is.na(path) || !dir.exists(path)) return(character(0))
  arqs <- list.files(
    path = path, pattern = pattern, full.names = TRUE,
    recursive = recursive, ignore.case = ignore.case
  )
  arqs[file.exists(arqs)]
}

filter_compatible_rasters <- function(files) {
  files <- files[file.exists(files)]
  if (length(files) == 0) return(character(0))
  if (length(files) == 1) return(files)
  r0 <- rast(files[1])
  ext0 <- ext(r0)
  res0 <- res(r0)
  nrow0 <- nrow(r0)
  ncol0 <- ncol(r0)
  ok <- vapply(files, function(f) {
    r <- tryCatch(rast(f), error = function(e) NULL)
    if (is.null(r)) return(FALSE)
    same_ext <- isTRUE(all.equal(ext(r), ext0))
    same_res <- isTRUE(all.equal(res(r), res0))
    same_dim <- identical(nrow(r), nrow0) && identical(ncol(r), ncol0)
    same_crs <- tryCatch(terra::same.crs(r, r0), error = function(e) identical(crs(r), crs(r0)))
    same_ext && same_res && same_dim && same_crs
  }, logical(1))
  files[ok]
}

ler_planilha <- function(caminho) {
  if (is.na(caminho) || !file.exists(caminho)) stop("Arquivo não encontrado: ", caminho)
  
  if (grepl("\\.csv$", caminho, ignore.case = TRUE)) {
    # Tenta separadores comuns: ;, vírgula e tabulação.
    x1 <- try(read.csv(caminho, sep = ";", stringsAsFactors = FALSE, check.names = FALSE), silent = TRUE)
    if (!inherits(x1, "try-error") && ncol(x1) > 1) return(x1)
    
    x2 <- try(read.csv(caminho, sep = ",", stringsAsFactors = FALSE, check.names = FALSE), silent = TRUE)
    if (!inherits(x2, "try-error") && ncol(x2) > 1) return(x2)
    
    x3 <- read.delim(caminho, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE)
    return(x3)
  }
  
  as.data.frame(readxl::read_excel(caminho), check.names = FALSE)
}


# Verifica se uma planilha tem as colunas mínimas de ocorrência.
# Isso evita o erro de ler a planilha filtro como se fosse a planilha occ2.
eh_planilha_ocorrencias <- function(caminho) {
  tab <- tryCatch(ler_planilha(caminho), error = function(e) NULL)
  if (is.null(tab) || nrow(tab) == 0 || ncol(tab) < 3) return(FALSE)
  
  nomes <- normalizar_nome_coluna(names(tab))
  tem_sp  <- any(nomes %in% normalizar_nome_coluna(c("especie", "nome_cientifico", "nome_cientifico_", "species", "sp_name")))
  tem_lat <- any(nomes %in% normalizar_nome_coluna(c("latitude", "lat", "y")))
  tem_lon <- any(nomes %in% normalizar_nome_coluna(c("longitude", "long", "lon", "x")))
  
  tem_sp && tem_lat && tem_lon
}

listar_candidatos_planilhas <- function(path = base_dir) {
  arqs <- list.files(
    path = path,
    pattern = "\\.(csv|xls|xlsx)$",
    full.names = TRUE,
    recursive = TRUE,
    ignore.case = TRUE
  )
  arqs[file.exists(arqs)]
}

find_occurrence_file <- function(path = base_dir) {
  arqs <- listar_candidatos_planilhas(path)
  if (length(arqs) == 0) return(NA_character_)
  
  # Dá prioridade a nomes prováveis, mas valida o cabeçalho antes de aceitar.
  prioridade <- arqs[grepl("occ2|ocorr|salve-exportacao|subplanilha", basename(arqs), ignore.case = TRUE)]
  arqs <- unique(c(prioridade, arqs))
  
  for (f in arqs) {
    if (eh_planilha_ocorrencias(f)) return(f)
  }
  
  NA_character_
}

mostrar_diagnostico_planilhas <- function(path = base_dir, max_files = 30) {
  arqs <- listar_candidatos_planilhas(path)
  if (length(arqs) == 0) {
    cat("\nNenhuma planilha .csv/.xls/.xlsx encontrada em: ", path, "\n", sep = "")
    return(invisible(NULL))
  }
  
  cat("\nPlanilhas candidatas encontradas e respectivos cabeçalhos:\n")
  arqs <- arqs[seq_len(min(length(arqs), max_files))]
  for (f in arqs) {
    cab <- tryCatch({
      tmp <- ler_planilha(f)
      paste(names(tmp), collapse = ", ")
    }, error = function(e) paste("ERRO AO LER:", e$message))
    cat("- ", f, "\n  Colunas: ", cab, "\n", sep = "")
  }
}

ler_cod <- function(path) {
  if (is.na(path) || !file.exists(path)) stop("Arquivo cod.csv não encontrado.")
  cod1 <- try(read.delim(path, sep = ";", stringsAsFactors = FALSE), silent = TRUE)
  if (inherits(cod1, "try-error") || is.null(cod1) || ncol(cod1) == 0) {
    cod1 <- read.csv(path, stringsAsFactors = FALSE)
  }
  names(cod1) <- normalizar_nome_coluna(names(cod1))
  if (!all(c("label", "code") %in% names(cod1))) {
    stop("O arquivo cod.csv precisa ter colunas equivalentes a 'label' e 'code'.")
  }
  cod1$label <- tolower(trimws(as.character(cod1$label)))
  cod1$code  <- suppressWarnings(as.numeric(cod1$code))
  cod1
}

# Logger global
log_exec <- data.frame(
  especie = character(),
  n_registros = integer(),
  grupo = character(),
  protocolo_primario = character(),
  protocolo_executado = character(),
  status = character(),
  erro = character(),
  stringsAsFactors = FALSE
)

registrar_log <- function(especie, n_registros, grupo, protocolo_primario, protocolo_executado, status, erro = "") {
  log_exec <<- dplyr::bind_rows(
    log_exec,
    data.frame(
      especie = especie,
      n_registros = as.integer(n_registros),
      grupo = grupo,
      protocolo_primario = protocolo_primario,
      protocolo_executado = protocolo_executado,
      status = status,
      erro = as.character(erro),
      stringsAsFactors = FALSE
    )
  )
  write.csv(log_exec, file.path(output_dir, "log_execucao_modelagem.csv"), row.names = FALSE)
}

safe_fit <- function(nome, expr) {
  tryCatch(
    expr,
    error = function(e) {
      message("Modelo ", nome, " falhou: ", conditionMessage(e))
      NULL
    }
  )
}

safe_predict <- function(nome, modelo, pred, area = NULL) {
  if (is.null(modelo)) return(NULL)
  tryCatch(
    {
      if (is.null(area)) {
        sdm_predict(models = modelo, pred = pred, con_thr = TRUE)
      } else {
        sdm_predict(models = modelo, pred = pred, con_thr = TRUE, predict_area = area)
      }
    },
    error = function(e) {
      message("Predição ", nome, " falhou: ", conditionMessage(e))
      NULL
    }
  )
}

# =========================================================
# LOCALIZAÇÃO AUTOMÁTICA DOS ARQUIVOS
# =========================================================
hydro_dir <- find_first_dir("^HydroRIVERS_v10_sa")
if (is.na(hydro_dir)) hydro_dir <- base_dir

otto_dir <- find_first_dir("^ottobacias1_71$")
if (is.na(otto_dir)) otto_dir <- find_first_dir("^ottobacias")
if (is.na(otto_dir)) otto_dir <- base_dir

pca_dir <- find_first_dir("^PCA_ambVar_96$")
if (is.na(pca_dir)) pca_dir <- find_first_dir("PCA_ambVar_96")
if (is.na(pca_dir)) pca_dir <- base_dir

path_rios <- find_first_file("HydroRIVERS.*\\.shp$", path = hydro_dir)
if (is.na(path_rios)) path_rios <- find_first_file("HydroRIVERS.*\\.shp$", path = base_dir)

path_bacias <- find_first_file("geoft_bho_ach_otto_nivel_02\\.gpkg$|otto.*nivel_02.*\\.gpkg$", path = otto_dir)
if (is.na(path_bacias)) path_bacias <- find_first_file("\\.gpkg$", path = otto_dir)

arqsBasin <- find_first_file("PCA.*Basin.*\\.tif$|ImportAlta.*Basin.*\\.tif$|Basin.*\\.tif$", path = hydro_dir)
if (is.na(arqsBasin)) arqsBasin <- find_first_file("PCA.*Basin.*\\.tif$|ImportAlta.*Basin.*\\.tif$|Basin.*\\.tif$", path = base_dir)

arq_pca_unico <- find_first_file("^PCA_ambVar_96.*\\.tif$", path = pca_dir)
if (is.na(arq_pca_unico)) arq_pca_unico <- find_first_file("^PCA_ambVar_96.*\\.tif$", path = base_dir)

if (!is.na(arq_pca_unico)) {
  arquivos <- arq_pca_unico
} else {
  arquivos <- find_all_files(path = pca_dir, pattern = "\\.tif$")
}

# Primeiro tenta localizar exatamente os nomes informados acima.
# A expressão \s* aceita tanto "especies_salve_occ2" quanto "especies_salve _occ2".
path_ocorrencias_exato <- find_first_file(
  "^salve-exportacao-ocorrencias-fichas-26-03-2026-10-34-17\\.(csv|xls|xlsx)$",
  path = base_dir
)

path_filtro_exato <- find_first_file(
  "^especies_salve\\s*_occ2\\.(csv|xls|xlsx)$",
  path = base_dir
)

path_ocorrencias <- if (!is.na(path_ocorrencias_manual) && file.exists(path_ocorrencias_manual) && eh_planilha_ocorrencias(path_ocorrencias_manual)) {
  path_ocorrencias_manual
} else if (!is.na(path_ocorrencias_exato) && eh_planilha_ocorrencias(path_ocorrencias_exato)) {
  path_ocorrencias_exato
} else {
  if (!is.na(path_ocorrencias_manual) && file.exists(path_ocorrencias_manual)) {
    warning(
      "O arquivo indicado em path_ocorrencias_manual existe, mas não parece ser uma planilha de ocorrências ",
      "com espécie, latitude e longitude. O script tentará localizar outra planilha válida. Arquivo ignorado: ",
      path_ocorrencias_manual
    )
  }
  find_occurrence_file(path = base_dir)
}

path_filtro_especies <- if (!is.na(path_filtro_especies_manual) && file.exists(path_filtro_especies_manual)) {
  path_filtro_especies_manual
} else if (!is.na(path_filtro_exato) && file.exists(path_filtro_exato)) {
  path_filtro_exato
} else {
  find_first_file(
    "especies_salve.*occ2.*\\.(csv|xls|xlsx)$|.*especies.*occ2.*\\.(csv|xls|xlsx)$",
    path = base_dir
  )
}

# O habitat para o protocolo HAB/kernel será lido preferencialmente da própria
# planilha occ2, pelas colunas classe_mapbiomas e habitat_mapbiomas.
path_habitat_planilha <- NA_character_
path_mapbiomas <- find_first_file("mapbiomas.*\\.tif$", path = base_dir)
path_cod <- find_first_file("cod\\.csv$", path = base_dir)

if (is.na(path_bacias)) stop("Não encontrei arquivo .gpkg das ottobacias.")
if (length(arquivos) == 0) stop("Não encontrei os arquivos .tif das variáveis terrestres PCA_ambVar_96.")
if (is.na(path_ocorrencias)) {
  mostrar_diagnostico_planilhas(base_dir)
  stop(
    "Não encontrei uma planilha de ocorrências válida. Ela precisa ter, no mínimo, colunas equivalentes a: especie, latitude e longitude. ",
    "A planilha com sp_original/sp_match é filtro de espécies/nomes, não ocorrência."
  )
}

message("Arquivo de ocorrências: ", path_ocorrencias)
message("Planilha filtro de espécies: ", ifelse(is.na(path_filtro_especies), "não encontrada; usando todas as espécies da occ2", path_filtro_especies))
message("Planilha auxiliar de habitat: não usada; habitat vem da própria occ2")
message("MapBiomas: ", ifelse(is.na(path_mapbiomas), "não encontrado; protocolo kernel pode falhar", path_mapbiomas))
message("cod.csv: ", ifelse(is.na(path_cod), "não encontrado; protocolo kernel pode falhar", path_cod))

# =========================================================
# LEITURA DOS DADOS ESPACIAIS
# =========================================================
# Terrestres
if (length(arquivos) == 1) {
  ambVar <- rast(arquivos)
} else {
  arquivos_ok <- filter_compatible_rasters(arquivos)
  if (length(arquivos_ok) == 0) stop("Nenhum raster terrestre compatível foi encontrado para montar ambVar.")
  if (length(arquivos_ok) < length(arquivos)) {
    cat("Rasters incompatíveis removidos de ambVar:\n")
    print(setdiff(arquivos, arquivos_ok))
  }
  ambVar <- rast(arquivos_ok)
}
namesVar <- names(ambVar)

ottobacias1_7 <- vect(path_bacias)
polys_kernel <- terra::makeValid(vect(path_bacias))
polys_kernel$id_poly <- seq_len(nrow(polys_kernel))

# Aquáticas, se existirem arquivos
#crs_target <- "EPSG:5641"
crs_target <- "EPSG:10857"
if (!is.na(path_rios) && !is.na(arqsBasin)) {
  rios_v <- vect(path_rios)
  bacias_sf_global <- sf::st_read(path_bacias, quiet = TRUE)
  bacias_v <- vect(bacias_sf_global)
  rios_v <- project(rios_v, crs_target)
  bacias_v <- project(bacias_v, crs_target)
  ambBasin <- rast(arqsBasin)
  namesBasin <- names(ambBasin)
} else {
  rios_v <- NULL
  bacias_v <- NULL
  ambBasin <- NULL
  namesBasin <- NULL
  if (is.na(arqsBasin)) warning("Raster Basin ausente. Espécies aquáticas serão puladas ou enviadas para fallback kernel, se possível.")
}

raster_caverna <- rast("caves_potencial_brasil_1km.tif")

# Kernel/habitat
kernel_disponivel <- !is.na(path_mapbiomas) && !is.na(path_cod)
if (kernel_disponivel) {
  hab <- rast(path_mapbiomas)
  master_lookup <- ler_cod(path_cod)
} else {
  hab <- NULL
  master_lookup <- NULL
}

# =========================================================
# LEITURA E PADRONIZAÇÃO DAS PLANILHAS
# =========================================================
dados_raw <- ler_planilha(path_ocorrencias)
names(dados_raw) <- normalizar_nome_coluna(names(dados_raw))

cat("\nPlanilha de ocorrências realmente usada:\n")
print(path_ocorrencias)
cat("\nColunas da planilha de ocorrências:\n")
print(names(dados_raw))

col_sp  <- achar_coluna(dados_raw, c("especie", "nome_cientifico", "nome_cientifico_", "species", "sp_name"), "espécie")
col_lon <- achar_coluna(dados_raw, c("longitude", "long", "lon", "x"), "longitude")
col_lat <- achar_coluna(dados_raw, c("latitude", "lat", "y"), "latitude")

# Para o protocolo kernel/habitat, preferir habitat_mapbiomas e classe_mapbiomas.
# A coluna habitat simples pode estar vazia na planilha SALVE.
col_hab <- achar_coluna(
  dados_raw,
  c("habitat_mapbiomas", "habitat_model", "classe_habitat", "habitat"),
  "habitat",
  obrigatoria = FALSE
)

col_classe_mapbiomas <- achar_coluna(
  dados_raw,
  c("classe_mapbiomas", "classe_map", "mapbiomas_code", "code_mapbiomas", "codigo_mapbiomas"),
  "classe_mapbiomas",
  obrigatoria = FALSE
)

if ("fonte_habitat" %in% names(dados_raw)) {
  col_fonte_habitat <- "fonte_habitat"
} else {
  col_fonte_habitat <- NA
}

# Padroniza colunas mínimas mantendo as demais
dados <- dados_raw %>%
  mutate(
    sp_name = padronizar_nome_especie(.data[[col_sp]]),
    lon = parse_num_br(.data[[col_lon]]),
    lat = parse_num_br(.data[[col_lat]]),
    
    habitat_model =
      if (!is.na(col_hab))
        as.character(.data[[col_hab]])
    else
      NA_character_,
    
    classe_mapbiomas_model =
      if (!is.na(col_classe_mapbiomas)) {
        parse_num_br(.data[[col_classe_mapbiomas]])
      } else {
        NA_real_
      },
    
    fonte_habitat_model =
      if (!is.na(col_fonte_habitat))
        as.character(.data[[col_fonte_habitat]])
    else
      "mapbiomas"
  ) %>%
  mutate(
    habitat_model = stringr::str_squish(habitat_model),
    habitat_model = ifelse(
      is.na(habitat_model) | habitat_model == "",
      NA_character_,
      habitat_model
    )
  ) %>%
  filter(!is.na(sp_name), !is.na(lon), !is.na(lat))

if (nrow(dados) == 0) {
  diagnostico_leitura <- data.frame(
    especie_raw = as.character(dados_raw[[col_sp]]),
    latitude_raw = as.character(dados_raw[[col_lat]]),
    longitude_raw = as.character(dados_raw[[col_lon]]),
    latitude_convertida = parse_num_br(dados_raw[[col_lat]]),
    longitude_convertida = parse_num_br(dados_raw[[col_lon]]),
    stringsAsFactors = FALSE
  )
  openxlsx::write.xlsx(
    diagnostico_leitura,
    file = file.path(output_dir, "diagnostico_leitura_occ2_lat_long.xlsx"),
    overwrite = TRUE
  )
  stop(
    "A occ2 foi lida, mas nenhuma linha ficou com especie + latitude + longitude válidas. ",
    "Foi salvo o diagnóstico em: ",
    file.path(output_dir, "diagnostico_leitura_occ2_lat_long.xlsx")
  )
}

# Lista de espécies-alvo.
# A planilha especies_salve_occ2 é usada apenas como filtro geral.
# O script decide automaticamente se cada espécie vai para HAB/kernel ou flexsdm.
#
# IMPORTANTE:
# Se a planilha filtro tiver sp_original e sp_match, o script usa AS DUAS colunas.
# Isso evita perder espécies quando sp_match estiver vazio, diferente do nome da occ2,
# ou quando os nomes estiverem com underline em uma planilha e espaço na outra.
dados <- dados %>% mutate(sp_key = normalizar_chave_especie(sp_name))

cat("\nAntes do filtro por especies_salve_occ2:\n")
cat("Linhas na occ2:", nrow(dados), "\n")
cat("Espécies únicas na occ2:", length(unique(dados$sp_name)), "\n")

if (!is.na(path_filtro_especies)) {
  especies_filtro <- ler_planilha(path_filtro_especies)
  names(especies_filtro) <- normalizar_nome_coluna(names(especies_filtro))
  
  # Sua planilha filtro tem cabeçalho: especie, origem.
  # A coluna origem NÃO é usada como nome de espécie; ela serve apenas como metadado.
  # O script usa preferencialmente a coluna especie.
  cols_candidatas_filtro <- c(
    "especie", "nome_cientifico", "nome_cientifico_",
    "species", "especies", "sp_name", "sp_match", "sp_original"
  )
  cols_presentes_filtro <- cols_candidatas_filtro[cols_candidatas_filtro %in% names(especies_filtro)]
  
  if (length(cols_presentes_filtro) == 0) {
    stop(
      "Não encontrei coluna de espécie na planilha filtro. Colunas disponíveis: ",
      paste(names(especies_filtro), collapse = ", ")
    )
  }
  
  cat("\nColunas usadas como filtro de espécies:\n")
  print(cols_presentes_filtro)
  
  lista_especies_raw <- unique(
    na.omit(
      padronizar_nome_especie(
        unlist(especies_filtro[cols_presentes_filtro], use.names = FALSE)
      )
    )
  )
  lista_especies_key <- unique(na.omit(normalizar_chave_especie(lista_especies_raw)))
  
  diag_filtro <- data.frame(
    nome_no_filtro = lista_especies_raw,
    chave_comparacao = normalizar_chave_especie(lista_especies_raw),
    stringsAsFactors = FALSE
  )
  
  cat("Espécies/nomeações únicas na planilha filtro:", length(lista_especies_key), "\n")
  
  chaves_occ2 <- sort(unique(na.omit(dados$sp_key)))
  chaves_intersecao <- intersect(chaves_occ2, lista_especies_key)
  
  cat("Espécies com correspondência entre filtro e occ2:", length(chaves_intersecao), "\n")
  
  if (length(chaves_intersecao) == 0) {
    cat("\nPrimeiras espécies da occ2:\n")
    print(head(sort(unique(dados$sp_name)), 30))
    
    cat("\nPrimeiros nomes da planilha filtro:\n")
    print(head(sort(lista_especies_raw), 30))
    
    openxlsx::write.xlsx(
      list(
        especies_occ2 = data.frame(sp_name = sort(unique(dados$sp_name)), sp_key = sort(unique(dados$sp_key))),
        especies_filtro = diag_filtro
      ),
      file = file.path(output_dir, "diagnostico_sem_match_occ2_vs_filtro.xlsx"),
      overwrite = TRUE
    )
    
    stop(
      "Nenhuma espécie da planilha filtro correspondeu à occ2. ",
      "Foi salvo um diagnóstico em: ",
      file.path(output_dir, "diagnostico_sem_match_occ2_vs_filtro.xlsx")
    )
  }
  
  dados <- dados %>% filter(sp_key %in% lista_especies_key)
  
  faltantes_key <- setdiff(lista_especies_key, unique(dados$sp_key))
  faltantes_filtro <- diag_filtro %>%
    filter(chave_comparacao %in% faltantes_key) %>%
    distinct()
  
  if (nrow(faltantes_filtro) > 0) {
    cat("\nAlguns nomes da planilha filtro não foram encontrados na occ2:\n")
    print(head(faltantes_filtro, 30))
    openxlsx::write.xlsx(
      faltantes_filtro,
      file = file.path(output_dir, "especies_filtro_nao_encontradas_na_occ2.xlsx"),
      overwrite = TRUE
    )
  }
  
  lista_especies <- sort(unique(dados$sp_name))
  
  cat("\nApós o filtro por especies_salve_occ2:\n")
  cat("Linhas mantidas:", nrow(dados), "\n")
  cat("Espécies mantidas:", length(lista_especies), "\n")
  
} else {
  lista_especies <- sort(unique(dados$sp_name))
}

# Filtros de bioma e categoria, se as colunas existirem
if (aplicar_filtro_bioma_categoria) {
  if ("bioma" %in% names(dados)) {
    dados <- dados %>%
      group_by(sp_name) %>%
      filter(any(bioma %in% biomas_alvo, na.rm = TRUE)) %>%
      ungroup()
  }
  if ("categoria_validada" %in% names(dados)) {
    dados <- dados %>% filter(categoria_validada %in% categorias_alvo)
  }
}

# Completa habitat a partir de species_5pts_atualizado.xlsx, se disponível
if (!is.na(path_habitat_planilha)) {
  hab_tab <- tryCatch(ler_planilha(path_habitat_planilha), error = function(e) NULL)
  if (!is.null(hab_tab)) {
    names(hab_tab) <- normalizar_nome_coluna(names(hab_tab))
    col_sp_h <- achar_coluna(hab_tab, c("especies", "especie", "nome_cientifico", "species", "sp_name"), "espécie", obrigatoria = FALSE)
    col_hab_h <- achar_coluna(hab_tab, c("habitat_mapbiomas", "habitat", "habitat_model", "classe_habitat"), "habitat", obrigatoria = FALSE)
    if (!is.na(col_sp_h) && !is.na(col_hab_h)) {
      habitat_por_sp <- hab_tab %>%
        mutate(sp_name = padronizar_nome_especie(.data[[col_sp_h]]), habitat_aux = as.character(.data[[col_hab_h]])) %>%
        filter(!is.na(sp_name), !is.na(habitat_aux), habitat_aux != "") %>%
        group_by(sp_name) %>%
        summarise(habitat_aux = paste(unique(habitat_aux), collapse = "/"), .groups = "drop")
      dados <- dados %>%
        left_join(habitat_por_sp, by = "sp_name") %>%
        mutate(habitat_model = ifelse(is.na(habitat_model) | habitat_model == "", habitat_aux, habitat_model)) %>%
        select(-habitat_aux)
    }
  }
}

# Colunas compatíveis com o script antigo
dados$Nome_Cientifico <- dados$sp_name
dados$Longitude <- dados$lon
dados$Latitude <- dados$lat

# Grupo: 1 = terrestre; 2 = aquática
familias_aquaticas <- c(
  "Pimelodidae", "Rivulidae", "Loricariidae", "Rhinobatidae",      
  "Narcinidae", "Spintherobolidae", "Delphinidae", "Hyalellidae",       
  "Chelidae", "Aeglidae", "Trichomycteridae", "Heptapteridae",     
  "Palaemonidae", "Callichthyidae", "Parastacidae", "Acestrorhamphidae", 
  "Auchenipteridae", "Potamotrygonidae", "Pseudothelphusidae"
)

if ("familia" %in% names(dados)) {
  dados$grupo <- ifelse(is.na(dados$familia), 1, ifelse(dados$familia %in% familias_aquaticas, 2, 1))
} else {
  dados$grupo <- 1
}

species <- sort(unique(dados$sp_name))
if (length(species) == 0) {
  stop(
    "Nenhuma espécie disponível após leitura e filtros. ",
    "Confira o arquivo diagnostico_sem_match_occ2_vs_filtro.xlsx ou especies_filtro_nao_encontradas_na_occ2.xlsx em: ",
    output_dir
  )
}

cat("Total de espécies para processar:", length(species), "\n")
print(
  dados %>%
    group_by(sp_name) %>%
    summarise(n = n(), grupo = dplyr::first(grupo), .groups = "drop") %>%
    arrange(n, sp_name)
)

# =========================================================
# FUNÇÕES DO PROTOCOLO KERNEL/HABITAT (<5 pontos ou fallback)
# =========================================================
map_habitat_to_codes <- function(habitat_string, lut) {
  if (is.na(habitat_string) || habitat_string == "") return(integer(0))
  parts <- strsplit(habitat_string, "/")[[1]]
  parts <- tolower(trimws(parts))
  parts <- parts[parts != ""]
  matched_codes <- c()
  for (part in parts) {
    idx <- grep(part, lut$label, fixed = TRUE)
    if (length(idx) > 0) matched_codes <- c(matched_codes, lut$code[idx])
  }
  unique(na.omit(matched_codes))
}

filtrar_mancha_conectada <- function(raster_binario, pontos_ocorrencia) {
  pts <- vect(pontos_ocorrencia, geom = c("lon", "lat"), crs = "EPSG:4326")
  pts <- project(pts, crs(raster_binario))
  patches_r <- patches(raster_binario, directions = 8, zeroAsNA = TRUE)
  patch_values <- terra::extract(patches_r, pts)[, 2]
  patch_values <- unique(na.omit(patch_values))
  if (length(patch_values) == 0) {
    warning("Nenhum patch encontrado nos pontos de ocorrência.")
    return(raster_binario * 0)
  }
  mascara <- patches_r %in% patch_values
  mascara <- ifel(is.na(mascara) | mascara == 0, 0, 1)
  raster_binario * mascara
}

calcular_thresholds <- function(kde_raster, occ_values, n_registros) {
  todos_valores <- na.omit(values(kde_raster))
  todos_valores <- as.numeric(todos_valores)
  if (length(todos_valores) == 0) {
    return(list(
      threshold_1 = NA_real_, descricao_1 = "Sem dados",
      threshold_2 = NA_real_, descricao_2 = "Sem dados",
      threshold_3 = NA_real_, descricao_3 = "Sem dados"
    ))
  }
  valores_ord <- sort(todos_valores, decreasing = TRUE)
  n_valores <- length(valores_ord)
  if (n_registros > 1 && length(occ_values) > 0) {
    threshold_base <- min(occ_values, na.rm = TRUE)
    desc_base <- paste0("Min. pts (", n_registros, ")")
  } else {
    n_10pc <- max(1, floor(n_valores * 0.1))
    threshold_base <- min(valores_ord[1:n_10pc], na.rm = TRUE)
    desc_base <- "Min. 10%"
  }
  n_25pc_min <- max(1, floor(n_valores * 0.25))
  threshold_25min <- min(valores_ord[1:n_25pc_min], na.rm = TRUE)
  desc_25min <- "Min. 25%"
  n_25pc_media <- max(1, floor(n_valores * 0.25))
  maiores_25pc_media <- valores_ord[1:n_25pc_media]
  media_25pc <- mean(maiores_25pc_media, na.rm = TRUE)
  sd_25pc <- sd(maiores_25pc_media, na.rm = TRUE)
  if (is.na(sd_25pc) || sd_25pc == 0) sd_25pc <- 1
  threshold_25media <- media_25pc - sd_25pc
  desc_25media <- "Média 25%-1DP"
  list(
    threshold_1 = threshold_base, descricao_1 = desc_base,
    threshold_2 = threshold_25min, descricao_2 = desc_25min,
    threshold_3 = threshold_25media, descricao_3 = desc_25media
  )
}

rasterize_or_zero <- function(x, template) {
  r0 <- rast(template)
  values(r0) <- 0
  if (is.null(x) || nrow(x) == 0) return(r0)
  rasterize(x, template, field = 1, background = 0)
}

kernel_ponderado <- function(df_occ, ott_sel, habitat_obj, valid_codes, r_ref,
                             tipo_habitat = "mapbiomas",
                             sigma_m = 3000,
                             pesos = c(1, 2, 3, 4, 5)) {
  
  r_base <- r_ref[[1]]
  crs_work <- crs(r_base)
  
  if (!same.crs(ott_sel, r_base))
    ott_sel <- project(ott_sel, crs_work)
  
  if (!same.crs(habitat_obj, r_base))
    habitat_obj <- project(habitat_obj, crs_work, method = "near")
  
  pts_occ <- vect(df_occ, geom = c("lon", "lat"), crs = "EPSG:4326")
  
  if (!same.crs(pts_occ, r_base))
    pts_occ <- project(pts_occ, crs_work)
  
  area_all <- aggregate(ott_sel)
  
  r_tmpl <- mask(
    crop(r_base, area_all),
    area_all,
    touches = TRUE
  )
  
  ott_main <- subset(ott_sel, ott_sel$grupo == "principal")
  ott_adj  <- subset(ott_sel, ott_sel$grupo == "adjacente")
  
  r_main <- rasterize_or_zero(ott_main, r_tmpl)
  r_adj  <- rasterize_or_zero(ott_adj,  r_tmpl)
  r_occ  <- rasterize_or_zero(pts_occ,  r_tmpl)
  
  # =====================================================
  # HABITAT
  # =====================================================
  
  hab_crop  <- crop(habitat_obj, r_tmpl)
  r_hab_raw <- resample(hab_crop, r_tmpl, method = "near")
  
  if (tipo_habitat == "caverna") {
    
    # Classes:
    # 1 = baixo
    # 2 = médio
    # 3 = alto
    # 4 = muito alto
    
    r_hab <- ifel(r_hab_raw %in% c(3, 4), 1, 0)
    
  } else {
    
    if (length(valid_codes) > 0) {
      
      r_hab <- ifel(
        r_hab_raw %in% valid_codes,
        1,
        0
      )
      
    } else {
      
      r_hab <- rast(r_tmpl)
      values(r_hab) <- 0
      
    }
  }
  
  r_hab <- ifel(is.na(r_hab), 0, r_hab)
  
  # =====================================================
  # PESOS
  # =====================================================
  
  W <- rast(r_tmpl)
  values(W) <- 0
  
  W <- ifel(r_adj  == 1 & r_hab == 0 & r_occ == 0, pesos[1], W)
  W <- ifel(r_main == 1 & r_hab == 0 & r_occ == 0, pesos[2], W)
  W <- ifel(r_adj  == 1 & r_hab == 1 & r_occ == 0, pesos[3], W)
  W <- ifel(r_main == 1 & r_hab == 1 & r_occ == 0, pesos[4], W)
  W <- ifel(r_occ == 1, pesos[5], W)
  
  pca_vals <- terra::extract(r_ref[[1]], pts_occ, ID = FALSE)[, 1]
  pca_vals <- na.omit(pca_vals)
  
  if (length(pca_vals) == 0)
    stop("Não foi possível extrair valores ambientais nos pontos da espécie.")
  
  mu <- mean(pca_vals, na.rm = TRUE)
  sigma <- sd(pca_vals, na.rm = TRUE)
  
  if (is.na(sigma) || sigma == 0)
    sigma <- 1
  
  pca_layer <- crop(r_ref[[1]], r_tmpl)
  pca_layer <- resample(pca_layer, r_tmpl)
  
  suitability <- app(
    pca_layer,
    fun = function(x) exp(-0.5 * ((x - mu) / sigma)^2)
  )
  
  suitability <- ifel(is.na(suitability), 0, suitability)
  
  W <- W * suitability
  
  r_mask <- rasterize(area_all, r_tmpl, field = 1, background = NA)
  
  W <- mask(W, r_mask)
  
  d_kernel <- ifelse(
    is.lonlat(crs_work),
    sigma_m / 111132,
    sigma_m
  )
  
  K <- focalMat(
    r_tmpl,
    d = d_kernel,
    type = "Gauss"
  )
  
  kde <- focal(
    W,
    w = K,
    fun = "sum",
    na.rm = TRUE
  )
  
  kde <- mask(kde, r_mask)
  
  min_val <- global(kde, "min", na.rm = TRUE)[1, 1]
  max_val <- global(kde, "max", na.rm = TRUE)[1, 1]
  
  if (is.na(min_val) || is.na(max_val))
    stop("KDE sem valores válidos.")
  
  if ((max_val - min_val) == 0) {
    kde <- kde * 0
  } else {
    kde <- (kde - min_val) / (max_val - min_val)
  }
  
  occ_values <- terra::extract(kde, pts_occ, ID = FALSE)[[1]]
  occ_values <- na.omit(occ_values)
  
  thresholds <- calcular_thresholds(
    kde,
    occ_values,
    nrow(df_occ)
  )
  
  raster_binario_1 <- ifel(kde >= thresholds$threshold_1, 1, 0)
  raster_binario_2 <- ifel(kde >= thresholds$threshold_2, 1, 0)
  raster_binario_3 <- ifel(kde >= thresholds$threshold_3, 1, 0)
  
  raster_binario_1 <- mask(raster_binario_1, r_mask)
  raster_binario_2 <- mask(raster_binario_2, r_mask)
  raster_binario_3 <- mask(raster_binario_3, r_mask)
  
  raster_binario_1 <- filtrar_mancha_conectada(raster_binario_1, df_occ)
  raster_binario_2 <- filtrar_mancha_conectada(raster_binario_2, df_occ)
  raster_binario_3 <- filtrar_mancha_conectada(raster_binario_3, df_occ)
  
  list(
    kde = kde,
    binario_1 = raster_binario_1,
    binario_2 = raster_binario_2,
    binario_3 = raster_binario_3,
    thresholds = thresholds,
    n_registros = nrow(df_occ)
  )
}

threshold_table <- data.frame(
  especie = character(), arquivo_base = character(), n_registros = numeric(),
  threshold_1 = numeric(), descricao_1 = character(),
  threshold_2 = numeric(), descricao_2 = character(),
  threshold_3 = numeric(), descricao_3 = character(),
  stringsAsFactors = FALSE
)

rodar_kernel_habitat <- function(sp.i, sp_name) {
  
  if (!kernel_disponivel)
    stop("Protocolo kernel indisponível: mapbiomas.tif e/ou cod.csv não encontrados.")
  
  sp_stub <- nome_arquivo_sp(sp_name)
  
  sp_data <- sp.i %>%
    transmute(
      sp_name = sp_name,
      lon = as.numeric(lon),
      lat = as.numeric(lat),
      habitat_model = as.character(habitat_model),
      
      classe_mapbiomas_model =
        if ("classe_mapbiomas_model" %in% names(sp.i)) {
          suppressWarnings(as.numeric(classe_mapbiomas_model))
        } else {
          NA_real_
        },
      
      fonte_habitat_model =
        if ("fonte_habitat_model" %in% names(sp.i)) {
          as.character(fonte_habitat_model)
        } else {
          "mapbiomas"
        }
    ) %>%
    filter(!is.na(lon), !is.na(lat))
  
  if (nrow(sp_data) == 0)
    stop("Sem coordenadas válidas para kernel.")
  
  cat(
    "Protocolo: kernel/habitat para ",
    sp_name,
    " | n = ",
    nrow(sp_data),
    "\n",
    sep = ""
  )
  
  pts <- vect(
    sp_data,
    geom = c("lon", "lat"),
    crs = "EPSG:4326"
  )
  
  pts_valid <- project(pts, crs(polys_kernel))
  
  output_pts <- file.path(
    output_kernel,
    paste0(sp_stub, "_occurrences.gpkg")
  )
  
  writeVector(
    pts_valid,
    output_pts,
    overwrite = TRUE
  )
  
  polys_tmp <- polys_kernel
  
  polys_hit <- polys_tmp[pts_valid, ]
  
  if (nrow(polys_hit) == 0)
    stop("Nenhum polígono encontrado para a espécie no kernel.")
  
  polys_tmp$grupo <- NA_character_
  
  id_main <- unique(polys_hit$id_poly)
  
  nb <- relate(
    polys_tmp,
    polys_hit,
    "intersects",
    pairs = TRUE
  )
  
  nb_ids <- if (nrow(nb) > 0)
    unique(nb[, 1])
  else
    integer(0)
  
  polys_tmp$grupo[
    polys_tmp$id_poly %in% id_main
  ] <- "principal"
  
  polys_tmp$grupo[
    polys_tmp$id_poly %in% nb_ids &
      !polys_tmp$id_poly %in% id_main
  ] <- "adjacente"
  
  all_ids <- sort(unique(c(id_main, nb_ids)))
  
  polys_sel <- polys_tmp[
    polys_tmp$id_poly %in% all_ids,
  ]
  
  habitat_strings <- unique(
    na.omit(sp_data$habitat_model)
  )
  
  # ----------------------------
  # Escolha automática do raster
  # ----------------------------
  fonte_hab <- unique(na.omit(sp.i$fonte_habitat_model))
  
  cat("\n")
  cat("fonte_hab = ", paste(fonte_hab, collapse = ", "), "\n")
  cat("\n")
  
  if(length(fonte_hab) == 0)
    fonte_hab <- "mapbiomas"
  
  if(fonte_hab[1] == "caverna"){
    
    habitat_raster <- raster_caverna
    
  } else {
    
    habitat_raster <- hab
    
  }
  
  fonte_hab <- unique(
    na.omit(sp_data$fonte_habitat_model)
  )
  
  if (length(fonte_hab) == 0)
    fonte_hab <- "mapbiomas"
  
  if (fonte_hab[1] == "caverna") {
    
    habitat_raster <- raster_caverna
    tipo_habitat <- "caverna"
    
    message(
      "Usando raster de potencialidade de cavernas para ",
      sp_name
    )
    
  } else {
    
    habitat_raster <- hab
    tipo_habitat <- "mapbiomas"
    
  }
  
  # ----------------------------
  # Códigos MapBiomas
  # ----------------------------
  
  hab_codes_num <- unique(
    na.omit(sp_data$classe_mapbiomas_model)
  )
  
  hab_codes_txt <- unique(
    unlist(
      lapply(
        habitat_strings,
        map_habitat_to_codes,
        lut = master_lookup
      )
    )
  )
  
  hab_codes_sp <- unique(
    na.omit(
      c(
        hab_codes_num,
        hab_codes_txt
      )
    )
  )
  
  if (tipo_habitat == "mapbiomas") {
    
    if (length(hab_codes_sp) == 0) {
      
      message(
        "Nenhum código de habitat/MapBiomas encontrado para ",
        sp_name,
        ". O kernel será calculado sem ponderação por habitat."
      )
      
    } else {
      
      message(
        "Códigos MapBiomas usados para ",
        sp_name,
        ": ",
        paste(hab_codes_sp, collapse = ", ")
      )
      
    }
    
  }
  
  resultado_modelo <- kernel_ponderado(
    df_occ = sp_data,
    ott_sel = polys_sel,
    habitat_obj = habitat_raster,
    valid_codes = hab_codes_sp,
    r_ref = ambVar,
    tipo_habitat = tipo_habitat
  )
  
  threshold_table <<- rbind(
    threshold_table,
    data.frame(
      especie = sp_name,
      arquivo_base = sp_stub,
      n_registros = resultado_modelo$n_registros,
      threshold_1 = resultado_modelo$thresholds$threshold_1,
      descricao_1 = resultado_modelo$thresholds$descricao_1,
      threshold_2 = resultado_modelo$thresholds$threshold_2,
      descricao_2 = resultado_modelo$thresholds$descricao_2,
      threshold_3 = resultado_modelo$thresholds$threshold_3,
      descricao_3 = resultado_modelo$thresholds$descricao_3,
      stringsAsFactors = FALSE
    )
  )
  
  write.csv(
    threshold_table,
    file.path(output_kernel, "threshold_values.csv"),
    row.names = FALSE
  )
  
  writeRaster(
    resultado_modelo$kde,
    file.path(output_kernel, paste0(sp_stub, "_kde.tif")),
    overwrite = TRUE
  )
  
  writeRaster(
    resultado_modelo$binario_1,
    file.path(output_kernel, paste0(sp_stub, "_bin_cenario1.tif")),
    overwrite = TRUE,
    datatype = "INT1U"
  )
  
  writeRaster(
    resultado_modelo$binario_2,
    file.path(output_kernel, paste0(sp_stub, "_bin_cenario2.tif")),
    overwrite = TRUE,
    datatype = "INT1U"
  )
  
  writeRaster(
    resultado_modelo$binario_3,
    file.path(output_kernel, paste0(sp_stub, "_bin_cenario3.tif")),
    overwrite = TRUE,
    datatype = "INT1U"
  )
  
  TRUE
}

# =========================================================
# FUNÇÕES DO PROTOCOLO FLEXSDM (>=5 pontos)
# =========================================================
preparar_coord_flex <- function(sp.i, grupo_sp) {
  coord <- data.frame(x = sp.i$lon, y = sp.i$lat)
  coord$id <- seq_len(nrow(coord))
  coord <- coord[!is.na(coord$x) & !is.na(coord$y), ]
  if (nrow(coord) == 0) stop("Sem coordenadas válidas.")
  nbins <- max(1, floor(sqrt(nrow(coord))))
  if (grupo_sp == 1) {
    if (nrow(coord) <= 10) {
      coord <- coord
    } else if (nrow(coord) <= 20) {
      coord <- occfilt_env(data = coord, x = "x", y = "y", id = "id", nbins = nbins, env_layer = ambVar)
    } else {
      coord <- occfilt_geo(coord, x = "x", y = "y", env_layer = ambVar, method = c("defined", d = distancia))
    }
  } else {
    if (nrow(coord) <= 10) {
      coord <- coord
    } else if (nrow(coord) <= 20) {
      coord <- occfilt_env(data = coord, x = "x", y = "y", id = "id", nbins = nbins, env_layer = ambVar)
    } else {
      coord <- occfilt_geo(coord, x = "x", y = "y", env_layer = ambVar, method = c("defined", d = distancia))
    }
  }
  coord$pr_ab <- 1
  coord
}

preparar_area_aquatica <- function(sp.i, coord) {
  if (is.null(ambBasin) || is.null(rios_v) || is.null(bacias_v)) {
    stop("Arquivos aquáticos ausentes: ambBasin, rios ou bacias.")
  }
  pontos_v <- vect(sp.i, geom = c("lon", "lat"), crs = "EPSG:4326")
  pontos_v <- project(pontos_v, crs_target)
  ambBasin_proj <- project(ambBasin, crs_target)
  rios_sf <- st_as_sf(rios_v)
  pontos_sf <- st_as_sf(pontos_v)
  bacias_sf <- st_as_sf(bacias_v)
  bacias_sf <- st_make_valid(bacias_sf)
  bacias_sel <- bacias_sf %>% st_filter(pontos_sf, .predicate = st_intersects)
  if (nrow(bacias_sel) == 0) stop("Nenhuma bacia intersectou os pontos aquáticos.")
  rios_crop <- rios_sf %>% st_filter(bacias_sel, .predicate = st_intersects)
  if (nrow(rios_crop) == 0) stop("Nenhum rio intersectou as bacias selecionadas.")
  rios_cropUn <- st_union(st_geometry(rios_crop))
  rios_cropUn <- vect(st_as_sf(rios_cropUn))
  riosBuf <- buffer(rios_cropUn, width = 5000)
  riosBuf$ID <- 1
  coord_v <- vect(coord, geom = c("x", "y"), crs = "EPSG:4326")
  coord_v_5641 <- project(coord_v, crs_target)
  coord_proj <- cbind(as.data.frame(coord_v_5641), crds(coord_v_5641))
  list(coord = coord_proj, riosBuf = riosBuf, amb = ambBasin_proj, bacias_sel = bacias_sel)
}

ajustar_sdm_generico <- function(coord, env_layer, env_names, ca, dir_tabelas, dir_msdm, sp_name, pseudo_width = "50000") {
  psa <- sample_pseudoabs(
    data = coord, x = "x", y = "y", n = sum(coord$pr_ab),
    method = c("geoenv_const", width = pseudo_width, env = crop(env_layer, ca)),
    rlayer = crop(env_layer, ca), calibarea = ca
  )
  sp.i_pa <- bind_rows(coord, psa)
  
  bg <- sample_background(
    data = coord,
    x = "x",
    y = "y",
    n = nrow(coord)*2,
    method = c("thickening"
    ),
    rlayer = crop(env_layer, ca),
    calibarea = ca
  )
  
  # EXTRAÇÃO AMBIENTAL DO BACKGROUND PARA MAXENT
  # =====================================================
  
  bg_env <- sdm_extract(
    data = bg,
    x = "x",
    y = "y",
    env_layer = env_layer,
    variables = env_names
  )
  #bg_env$part = sp.i_pa2$part
  
  sp.i_pa2 <- tryCatch({
    res <- part_sblock(data = sp.i_pa, x = "x", y = "y", env_layer = env_layer, pr_ab = "pr_ab")
    if (all(is.na(res))) stop("part_sblock retornou NA")
    res
  }, error = function(e) {
    message("Primeira tentativa de part_sblock falhou; tentando parâmetros ajustados...")
    res2 <- part_sblock(
      data = sp.i_pa, x = "x", y = "y", env_layer = env_layer, pr_ab = "pr_ab",
      n_part = 2, min_occ = 5, min_res_mult = 5, max_res_mult = 100
    )
    if (all(is.na(res2))) stop("Segunda tentativa de part_sblock também retornou NA")
    res2
  })
  
  sp.i_pa3 <- sdm_extract(data = sp.i_pa2$part, x = "x", y = "y", env_layer = env_layer, variables = env_names)
  
  # resolvendo bg
  part_cols <- grep("^\\.part", names(sp.i_pa3), value = TRUE)
  
  for (pc in part_cols) {
    bg_env[[pc]] <- sp.i_pa3[[pc]]
  }
  
  mglm <- safe_fit("glm", fit_glm(data = sp.i_pa3, response = "pr_ab", predictors = env_names, partition = ".part", thr = "max_sorensen"))
  mgbm <- tryCatch({
    fit_gbm(data = sp.i_pa3, response = "pr_ab", predictors = env_names, partition = ".part", thr = "max_sorensen")
  }, error = function(e) {
    message("GBM original falhou; tentando parâmetros ajustados: ", conditionMessage(e))
    tryCatch({
      fit_gbm(
        data = sp.i_pa3, response = "pr_ab", predictors = env_names, partition = ".part",
        thr = "max_sorensen", n_minobsinnode = 1, n_trees = 50, shrinkage = 0.1
      )
    }, error = function(e2) {
      message("GBM ajustado também falhou: ", conditionMessage(e2))
      NULL
    })
  })
  msvm <- safe_fit("svm", fit_svm(data = sp.i_pa3, response = "pr_ab", predictors = env_names, partition = ".part", thr = "max_sorensen"))
  mnet <- safe_fit("net", fit_net(data = sp.i_pa3, response = "pr_ab", predictors = env_names, partition = ".part", thr = "max_sorensen"))
  mmax <- safe_fit("max", fit_max(data = sp.i_pa3, response = "pr_ab", background = bg_env, predictors = env_names, partition = ".part", thr = "max_sorensen"))
  mgau <- safe_fit("gau", fit_gau(data = sp.i_pa3, response = "pr_ab", background = bg_env, predictors = env_names, partition = ".part", thr = "max_sorensen"))
  mgam <- safe_fit("gam", fit_gam(data = sp.i_pa3, response = "pr_ab", predictors = env_names, partition = ".part", thr = "max_sorensen", k = 3))
  modelos_sdm <- list(glm = mglm, gbm = mgbm, svm = msvm, net = mnet, max = mmax, gau = mgau, gam = mgam)
  modelos_sdm <- modelos_sdm[!sapply(modelos_sdm, is.null)]
  if (length(modelos_sdm) < 2) stop("Menos de 2 modelos válidos no SDM.")
  merge_df <- sdm_summarize(models = modelos_sdm)
  write.xlsx(merge_df, file = file.path(dir_tabelas, paste0(nome_arquivo_sp(sp_name), "_SDM.xlsx")), rowNames = FALSE)
  modelos_ensemble <- list(gbm = mgbm, svm = msvm, net = mnet, max = mmax, gau = mgau)
  modelos_ensemble <- modelos_ensemble[!sapply(modelos_ensemble, is.null)]
  if (length(modelos_ensemble) < 2) stop("Menos de 2 modelos válidos para ensemble SDM.")
  ens_m <- fit_ensemble(
    models = modelos_ensemble,
    ens_method = "meansup",
    thr = NULL,
    thr_model = "max_sorensen",
    metric = "SORENSEN"
  )
  ensemble <- sdm_predict(models = ens_m, pred = env_layer, thr = c("max_sorensen"), con_thr = TRUE)
  msdm_post_ensemble <- msdm_posteriori(
    records = sp.i_pa, x = "x", y = "y", pr_ab = "pr_ab",
    cont_suit = ensemble$meansup[[1]], method = "pres", thr = "lpt"
  )
  msdm_post_ensemble <- msdm_post_ensemble * 1
  writeRaster(
    msdm_post_ensemble,
    filename = file.path(dir_msdm, paste0(nome_arquivo_sp(sp_name), "_Ensemble.tif")),
    overwrite = TRUE,
    datatype = "FLT4S",
    NAflag = -9999
  )
  TRUE
}

ajustar_esm_generico <- function(coord, env_layer, env_names, ca, dir_tabelas, dir_msdm, sp_name, pseudo_width = "50000") {
  psa <- sample_pseudoabs(
    data = coord, x = "x", y = "y", n = sum(coord$pr_ab),
    method = c("geoenv_const", width = pseudo_width, env = crop(env_layer, ca)),
    rlayer = crop(env_layer, ca), calibarea = ca
  )
  sp.i_pa <- bind_rows(coord, psa)
  
  bg <- sample_background(
    data = coord,
    x = "x",
    y = "y",
    n = nrow(coord)*2,
    method = c("thickening"
    ),
    rlayer = crop(env_layer, ca),
    calibarea = ca
  )
  
  # EXTRAÇÃO AMBIENTAL DO BACKGROUND PARA MAXENT
  # =====================================================
  
  bg_env <- sdm_extract(
    data = bg,
    x = "x",
    y = "y",
    env_layer = env_layer,
    variables = env_names
  )
  
  sp.i_pa2 <- part_random(data = sp.i_pa, pr_ab = "pr_ab", method = c(method = "rep_kfold", folds = 2, replicates = 4))
  sp.i_pa3 <- sdm_extract(data = sp.i_pa2, x = "x", y = "y", env_layer = env_layer, variables = env_names)
  
  #ajustando bg
  part_cols <- grep("^\\.part", names(sp.i_pa3), value = TRUE)
  
  for (pc in part_cols) {
    bg_env[[pc]] <- sp.i_pa3[[pc]]
  }
  
  emax <- safe_fit("esm_max", esm_max(data = sp.i_pa3, response = "pr_ab", background = bg_env, predictors = env_names, partition = ".part", thr = "max_sorensen"))
  enet <- safe_fit("esm_net", esm_net(data = sp.i_pa3, response = "pr_ab", predictors = env_names, partition = ".part", thr = "max_sorensen"))
  egau <- safe_fit("esm_gau", esm_gau(data = sp.i_pa3, response = "pr_ab", background = bg_env, predictors = env_names, partition = ".part", thr = "max_sorensen"))
  egam <- safe_fit("esm_gam", esm_gam(data = sp.i_pa3, response = "pr_ab", predictors = env_names, partition = ".part", thr = "max_sorensen", k = 1))
  eglm <- safe_fit("esm_glm", esm_glm(data = sp.i_pa3, response = "pr_ab", predictors = env_names, partition = ".part", thr = "max_sorensen"))
  egbm <- safe_fit("esm_gbm", esm_gbm(data = sp.i_pa3, response = "pr_ab", predictors = env_names, partition = ".part", thr = "max_sorensen"))
  esvm <- safe_fit("esm_svm", esm_svm(data = sp.i_pa3, response = "pr_ab", predictors = env_names, partition = ".part", thr = "max_sorensen"))
  modelos_validos <- Filter(Negate(is.null), list(emax = emax, enet = enet, egau = egau, egbm = egbm, esvm = esvm, eglm = eglm, egam = egam))
  if (length(modelos_validos) == 0) stop("Nenhum modelo ESM válido.")
  merge_df <- sdm_summarize(models = modelos_validos)
  write.xlsx(merge_df, file = file.path(dir_tabelas, paste0(nome_arquivo_sp(sp_name), "_ESM.xlsx")), rowNames = FALSE)
  preds <- list(
    emax = safe_predict("emax", emax, env_layer, ca),
    enet = safe_predict("enet", enet, env_layer, ca),
    egau = safe_predict("egau", egau, env_layer, ca),
    egam = safe_predict("egam", egam, env_layer, ca),
    eglm = safe_predict("eglm", eglm, env_layer, ca),
    egbm = safe_predict("egbm", egbm, env_layer, ca),
    esvm = safe_predict("esvm", esvm, env_layer, ca)
  )
  preds <- Filter(Negate(is.null), preds)
  if (length(preds) == 0) stop("Nenhuma predição ESM válida.")
  preds <- lapply(preds, function(x) x[[1]])
  nomes_acima_media <- sub("^esm_", "e", merge_df$model[merge_df$SORENSEN_mean > mean(merge_df$SORENSEN_mean, na.rm = TRUE)])
  modelos_meansup <- preds[names(preds) %in% nomes_acima_media]
  if (length(modelos_meansup) == 0) {
    message("Nenhum modelo acima da média de SORENSEN; usando todos os modelos preditos válidos.")
    modelos_meansup <- preds
  }
  esm_ensemble <- mean(rast(modelos_meansup))
  msdm_post_ens <- msdm_posteriori(
    records = sp.i_pa, x = "x", y = "y", pr_ab = "pr_ab",
    cont_suit = esm_ensemble, method = "pres", thr = "max_sorensen"
  )
  msdm_post_ens <- msdm_post_ens * 1
  writeRaster(
    msdm_post_ens,
    filename = file.path(dir_msdm, paste0(nome_arquivo_sp(sp_name), "_ESM.tif")),
    overwrite = TRUE,
    datatype = "FLT4S",
    NAflag = -9999
  )
  TRUE
}

rodar_flexsdm <- function(sp.i, sp_name) {
  grupo_sp <- unique(na.omit(sp.i$grupo))
  if (length(grupo_sp) == 0) grupo_sp <- 1 else grupo_sp <- grupo_sp[1]
  grupo_txt <- ifelse(grupo_sp == 1, "terrestre", "aquatica")
  coord <- preparar_coord_flex(sp.i, grupo_sp)
  if (nrow(coord) < min_pontos_flexsdm) {
    stop("Após filtragem, restaram menos de ", min_pontos_flexsdm, " pontos para flexsdm.")
  }
  if (grupo_sp == 1) {
    if (nrow(coord) > 25) {
      cat("Protocolo: terrestre | muitos pontos | SDM para ", sp_name, "\n", sep = "")
      dir_tabelas <- file.path(output_dir, "terrestres", "tabelas_SDM")
      dir_msdm <- file.path(output_dir, "terrestres", "msdm_SDM")
      dir.create(dir_tabelas, recursive = TRUE, showWarnings = FALSE)
      dir.create(dir_msdm, recursive = TRUE, showWarnings = FALSE)
      ca <- calib_area(data = coord, x = "x", y = "y", method = c("bmcp", width = 600000), crs = crs(ambVar))
      ajustar_sdm_generico(coord, ambVar, namesVar, ca, dir_tabelas, dir_msdm, sp_name, pseudo_width = "50000")
    } else {
      cat("Protocolo: terrestre | poucos pontos | ESM para ", sp_name, "\n", sep = "")
      dir_tabelas <- file.path(output_dir, "terrestres", "tabelas_ESM")
      dir_msdm <- file.path(output_dir, "terrestres", "msdm_ESM")
      dir.create(dir_tabelas, recursive = TRUE, showWarnings = FALSE)
      dir.create(dir_msdm, recursive = TRUE, showWarnings = FALSE)
      pontos <- vect(data.frame(x = coord$x, y = coord$y), geom = c("x", "y"), crs = "EPSG:4326")
      pontos <- project(pontos, crs(ottobacias1_7))
      relacao <- relate(ottobacias1_7, pontos, "contains")
      ids_corretos <- which(apply(relacao, 1, any))
      if (length(ids_corretos) == 0) stop("Nenhum ponto encontrado em ottobacia terrestre.")
      bacia_sel <- ottobacias1_7[ids_corretos, ]
      if (!terra::same.crs(bacia_sel, ambVar)) bacia_sel <- project(bacia_sel, crs(ambVar))
      ca <- calib_area(data = coord, x = "x", y = "y", method = c("mask", bacia_sel, "wts_pk"), crs = crs(ambVar))
      ajustar_esm_generico(coord, ambVar, namesVar, ca, dir_tabelas, dir_msdm, sp_name, pseudo_width = "50000")
    }
  } else {
    aq <- preparar_area_aquatica(sp.i, coord)
    coord_aq <- aq$coord
    env_aq <- aq$amb
    if (nrow(coord_aq) > 25) {
      cat("Protocolo: aquática | muitos pontos | SDM para ", sp_name, "\n", sep = "")
      dir_tabelas <- file.path(output_dir, "aquaticas", "tabelas_SDM")
      dir_msdm <- file.path(output_dir, "aquaticas", "msdm_SDM")
      dir.create(dir_tabelas, recursive = TRUE, showWarnings = FALSE)
      dir.create(dir_msdm, recursive = TRUE, showWarnings = FALSE)
      ca <- calib_area(data = coord_aq, x = "x", y = "y", method = c("mask", aq$riosBuf, "ID"), crs = crs(env_aq))
      ajustar_sdm_generico(coord_aq, env_aq, namesBasin, ca, dir_tabelas, dir_msdm, sp_name, pseudo_width = "10000")
    } else {
      cat("Protocolo: aquática | poucos pontos | ESM para ", sp_name, "\n", sep = "")
      dir_tabelas <- file.path(output_dir, "aquaticas", "tabelas_ESM")
      dir_msdm <- file.path(output_dir, "aquaticas", "msdm_ESM")
      dir.create(dir_tabelas, recursive = TRUE, showWarnings = FALSE)
      dir.create(dir_msdm, recursive = TRUE, showWarnings = FALSE)
      ca <- calib_area(data = coord_aq, x = "x", y = "y", method = c("mask", aq$riosBuf, "ID"), crs = crs(env_aq))
      ajustar_esm_generico(coord_aq, env_aq, namesBasin, ca, dir_tabelas, dir_msdm, sp_name, pseudo_width = "10000")
    }
  }
  TRUE
}

# =========================================================
# LOOP PRINCIPAL UNIFICADO
# =========================================================
for (i in seq_along(species)) {
  sp_name <- species[i]
  sp.i <- dplyr::filter(dados, sp_name == !!sp_name)
  n_reg <- nrow(sp.i)
  grupo_sp <- unique(na.omit(sp.i$grupo))
  if (length(grupo_sp) == 0) grupo_sp <- 1 else grupo_sp <- grupo_sp[1]
  grupo_txt <- ifelse(grupo_sp == 1, "terrestre", "aquática")
  protocolo_primario <- ifelse(n_reg >= min_pontos_flexsdm, "flexsdm", "kernel_habitat")
  cat("\n==================================================\n")
  cat("Rodando espécie ", i, " de ", length(species), ": ", sp_name, "\n", sep = "")
  cat("Registros antes da filtragem: ", n_reg, "\n", sep = "")
  cat("Grupo: ", grupo_txt, " | Protocolo primário: ", protocolo_primario, "\n", sep = "")
  cat("==================================================\n")
  sucesso <- FALSE
  erros <- character(0)
  protocolo_executado <- NA_character_
  if (protocolo_primario == "flexsdm") {
    sucesso <- tryCatch({
      rodar_flexsdm(sp.i, sp_name)
      protocolo_executado <- "flexsdm"
      TRUE
    }, error = function(e) {
      erros <<- c(erros, paste0("flexsdm: ", conditionMessage(e)))
      FALSE
    })
    if (!sucesso && permitir_fallback) {
      message("Flexsdm falhou para ", sp_name, ". Tentando fallback kernel/habitat...")
      sucesso <- tryCatch({
        rodar_kernel_habitat(sp.i, sp_name)
        protocolo_executado <- "kernel_habitat_fallback"
        TRUE
      }, error = function(e) {
        erros <<- c(erros, paste0("kernel fallback: ", conditionMessage(e)))
        FALSE
      })
    }
  } else {
    sucesso <- tryCatch({
      rodar_kernel_habitat(sp.i, sp_name)
      protocolo_executado <- "kernel_habitat"
      TRUE
    }, error = function(e) {
      erros <<- c(erros, paste0("kernel_habitat: ", conditionMessage(e)))
      FALSE
    })
    # Para espécies com menos de min_pontos_flexsdm, o flexsdm não é tentado por padrão,
    # porque o próprio protocolo flexsdm exige número mínimo de pontos.
    if (!sucesso && permitir_fallback && n_reg >= min_pontos_flexsdm) {
      message("Kernel falhou para ", sp_name, ". Tentando fallback flexsdm...")
      sucesso <- tryCatch({
        rodar_flexsdm(sp.i, sp_name)
        protocolo_executado <- "flexsdm_fallback"
        TRUE
      }, error = function(e) {
        erros <<- c(erros, paste0("flexsdm fallback: ", conditionMessage(e)))
        FALSE
      })
    }
  }
  if (sucesso) {
    registrar_log(
      especie = sp_name,
      n_registros = n_reg,
      grupo = grupo_txt,
      protocolo_primario = protocolo_primario,
      protocolo_executado = protocolo_executado,
      status = "sucesso",
      erro = paste(erros, collapse = " | ")
    )
    cat("Finalizada espécie: ", sp_name, "\n", sep = "")
  } else {
    registrar_log(
      especie = sp_name,
      n_registros = n_reg,
      grupo = grupo_txt,
      protocolo_primario = protocolo_primario,
      protocolo_executado = ifelse(is.na(protocolo_executado), "nenhum", protocolo_executado),
      status = "falhou_pulada",
      erro = paste(erros, collapse = " | ")
    )
    message("Espécie pulada após falhas: ", sp_name)
    message("Erros: ", paste(erros, collapse = " | "))
  }
  gc()
}


