if (!require(pacman)) install.packages("pacman")
pacman::p_load(terra, dplyr, readxl, openxlsx, stringr)

Sys.unsetenv("PROJ_LIB")
Sys.unsetenv("PROJ_DATA")
system.file("proj", package = "terra")
Sys.setenv(
  PROJ_LIB = "C:/Seu library do R/Local/R/win-library/4.6/terra/proj"
)

# =========================================================
# DIRETÓRIO
# =========================================================
base_dir <- "C:/Seu diretório"
setwd(base_dir)
# =========================================================
# ARQUIVOS
# =========================================================
# use aqui a planilha que você quer classificar
planilha_entrada <- file.path(base_dir, "subplanilha_especies_occ2.xlsx")

# raster do MapBiomas
raster_mapbiomas <- file.path(base_dir, "mapbiomas.tif")

# tabela de códigos do MapBiomas
tabela_codigos <- file.path(base_dir, "cod.csv")

# saídas
saida_csv <- file.path(base_dir, "subplanilha_especies_occ2_com_mapbiomas.csv")
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
  cand_norm <- normalizar_nome_coluna(candidatos)
  
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
    
    stop("Não foi possível ler a planilha CSV.")
  }
  
  if (ext %in% c("xlsx", "xls")) {
    return(as.data.frame(readxl::read_excel(arquivo)))
  }
  
  stop("Formato não suportado. Use csv, xlsx ou xls.")
}

ler_cod <- function(arquivo) {
  tentativas <- list(
    function() read.csv(arquivo, sep = ",", stringsAsFactors = FALSE, fileEncoding = "UTF-8"),
    function() read.csv(arquivo, sep = ";", stringsAsFactors = FALSE, fileEncoding = "UTF-8"),
    function() read.csv(arquivo, sep = ",", stringsAsFactors = FALSE, fileEncoding = "latin1"),
    function() read.csv(arquivo, sep = ";", stringsAsFactors = FALSE, fileEncoding = "latin1")
  )
  
  for (f in tentativas) {
    x <- tryCatch(f(), error = function(e) NULL)
    if (!is.null(x) && ncol(x) > 1) {
      names(x) <- trimws(names(x))
      names(x) <- gsub("\ufeff", "", names(x))
      names(x) <- tolower(names(x))
      return(x)
    }
  }
  
  stop("Não foi possível ler o arquivo cod.csv.")
}

# =========================================================
# CHECAR ARQUIVOS
# =========================================================
if (!file.exists(planilha_entrada)) stop(paste("Não encontrei:", planilha_entrada))
if (!file.exists(raster_mapbiomas)) stop(paste("Não encontrei:", raster_mapbiomas))
if (!file.exists(tabela_codigos)) stop(paste("Não encontrei:", tabela_codigos))

# =========================================================
# LER DADOS
# =========================================================
dados <- ler_planilha(planilha_entrada)
mapa <- terra::rast(raster_mapbiomas)
cod <- ler_cod(tabela_codigos)

# =========================================================
# IDENTIFICAR COLUNAS
# =========================================================
col_sp <- achar_coluna(
  dados,
  c("species", "especies", "especie", "Nome_Cientifico", "nome_cientifico", "scientific_name"),
  "espécie"
)

col_lat <- achar_coluna(
  dados,
  c("Latitude", "latitude", "lat"),
  "latitude"
)

col_lon <- achar_coluna(
  dados,
  c("Longitude", "longitude", "lon", "long"),
  "longitude"
)

# =========================================================
# CONVERTER COORDENADAS
# =========================================================
dados[[col_lat]] <- suppressWarnings(as.numeric(gsub(",", ".", as.character(dados[[col_lat]]))))
dados[[col_lon]] <- suppressWarnings(as.numeric(gsub(",", ".", as.character(dados[[col_lon]]))))

dados <- dados %>%
  filter(!is.na(.data[[col_lat]]), !is.na(.data[[col_lon]]))

if (nrow(dados) == 0) {
  stop("Nenhuma linha com coordenadas válidas foi encontrada.")
}

# =========================================================
# CRIAR PONTOS E EXTRAIR CLASSE DO MAPBIOMAS
# =========================================================
pts <- terra::vect(
  dados,
  geom = c(col_lon, col_lat),
  crs = "EPSG:4326"
)

crs(pts)
if (!terra::same.crs(pts, mapa)) {
  pts <- terra::project(pts, terra::crs(mapa))
}

valores <- terra::extract(mapa, pts, method = "simple", ID = FALSE)

if (ncol(valores) == 0) {
  stop("Não foi possível extrair valores do raster do MapBiomas.")
}

dados_out <- dados
dados_out$classe_mapbiomas <- as.numeric(valores[[1]])

# =========================================================
# CRUZAR COM cod.csv
# =========================================================
if (!all(c("code", "label") %in% names(cod))) {
  stop(
    paste0(
      "O cod.csv precisa ter colunas 'code' e 'label'. Colunas encontradas: ",
      paste(names(cod), collapse = ", ")
    )
  )
}

cod <- cod %>%
  transmute(
    code = suppressWarnings(as.numeric(code)),
    label = as.character(label)
  )

dados_out <- dados_out %>%
  left_join(cod, by = c("classe_mapbiomas" = "code")) %>%
  rename(habitat_mapbiomas = label)

# =========================================================
# ORGANIZAR COLUNAS
# =========================================================
dados_out <- dados_out %>%
  select(
    all_of(col_sp),
    all_of(col_lat),
    all_of(col_lon),
    classe_mapbiomas,
    habitat_mapbiomas,
    everything()
  )

# =========================================================
# SALVAR
# =========================================================
write.csv(dados_out, saida_csv, row.names = FALSE, na = "")
openxlsx::write.xlsx(dados_out, saida_xlsx, overwrite = TRUE)

cat("Concluído.\n")
cat("Registros processados:", nrow(dados_out), "\n")
cat("CSV salvo em:", saida_csv, "\n")
cat("XLSX salvo em:", saida_xlsx, "\n")

