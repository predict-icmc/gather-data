
# Criacao de arquivo de dados otimizado para o dashboard

#' função que lê diretamente o gzip do servidor do brasil.io e retorna o respectivo csv
downCorona <- function(file_url) {
  con <- gzcon(url(file_url))
  txt <- readLines(con)
  return(read.csv(textConnection(txt)))
}

#' pegaCorona(tipo = c("caso_full", "cart", "last_cases"), baixar = TRUE, salvar = FALSE))
#' funcao que pega o arquivo de casos do brasil.io, faz um pequeno tratamento e retorna-o
#' retornos permitidos:
#' caso_full: retorna a contagem de casos de todos os municipios desde o dia 0
#' cart: obitos em cartório
#' last_cases: ultimo balanço divulgado, com latitude e longitude
#' salvar: salva os arquivos no formato feather (para mais informações consulte https://github.com/wesm/feather)
#' para informacoes sobre o dataset, veja https://github.com/turicas/covid19-br/blob/master/api.md
#' @export
pegaCorona <- function(tipo = c("caso_full", "cart", "last_cases"), baixar = TRUE, salvar = FALSE) {
  if (!baixar && !salvar) {
    if (tipo == "cart") {
      return(feather::read_feather("ob-cartorio.feather"))
    } else if (tipo == "caso_full") {
      return(feather::read_feather("full-covid.feather"))
    } else if (tipo == "last_cases") {
      return(feather::read_feather("latlong-covid.feather"))
    }
  }

  # if(tipo == "vacina") return(downCorona("https://data.brasil.io/dataset/covid19/microdados_vacinacao.csv.gz"))

  if (baixar) {
    print("Fazendo o download....")
    if (tipo != "cart") {
      dados <- downCorona("https://data.brasil.io/dataset/covid19/caso_full.csv.gz")
    } else if (tipo == "cart") {
      cart <- downCorona("https://data.brasil.io/dataset/covid19/obito_cartorio.csv.gz")
    }
  }
  # caso já tenha o arquivo na pasta
  else {
    dados <- read.csv(file = "caso_full.csv", header = TRUE)
  }

  print("Download concluido. Transformando os dados")


  if (tipo == "cart") {
    return(cart)
  } else if (tipo == "caso_full") {
    dados$tempo <- as.numeric(as.Date(dados$date) - min(as.Date(dados$date)))
    dados$date <- as.Date(dados$date)
    return(dados)
  }

  if (salvar) {
    if (tipo == "cart") {
      return(feather::write_feather(cart, sprintf("ob-cartorio.feather")))
    } else if (tipo == "caso_full") {
      return(feather::write_feather(dados, sprintf("full-covid.feather")))
    }
  }

  else {
    # acrescentando latitude e longitude nos ultimos casos

    f <- system.file("extdata", "latitude-longitude-cidades.csv", package = "gather.covid", mustWork = T)
    latlong_cidade <- read.csv(f, sep = ";", header = TRUE)
    latlong_cidade$city <- latlong_cidade$municipio
    latlong_cidade$state <- latlong_cidade$uf

    f <- system.file("extdata", "latitude-longitude-estados.csv", package = "gather.covid", mustWork = T)
    latlong_estado <- read.csv(f, sep = ";", header = TRUE)
    latlong_estado$state <- latlong_estado$uf
    latlong_estado$place_type <- "state"

    dados <- dplyr::filter(dados, is_last == "True")

    dados2 <- merge(dados, latlong_cidade, by = c("state", "city"), all.x = TRUE, all.y = FALSE)
    dados <- merge(dados2, latlong_estado, by = c("state", "place_type"), all.x = TRUE, all.y = FALSE)

    dados <- dplyr::mutate(dados,
      latitude = ifelse(place_type == "city", latitude.x, latitude.y),
      longitude = ifelse(place_type == "city", longitude.x, longitude.y)
    )

    dados <- dplyr::select(dados, -c("uf.x", "uf.y", "latitude.x", "longitude.x", "latitude.y", "longitude.y"))

    dados <- tidyr::drop_na(dados, latitude, longitude)

    if (tipo == "last_cases" && salvar) {
      return(feather::write_feather(dados, sprintf("latlong-covid.feather")))
    }
    return(dados)
  }
}

#' baixar_seade()
#' retorna dados do seade de letos e casos por DRS
#' @export
baixar_seade <- function() {
  # Lendo a base de dados do SEADE com os casos em SP
  casos <- read.csv("https://raw.githubusercontent.com/seade-R/dados-covid-sp/master/data/dados_covid_sp.csv", sep = ";")
  leitos <- read.csv("https://raw.githubusercontent.com/seade-R/dados-covid-sp/master/data/plano_sp_leitos_internacoes_serie_nova_variacao_semanal.csv", sep = ";")

  # incluindo os codigos das DRS na base de leitos
  leitos <- dplyr::mutate(leitos, cod_drs = extract_numeric(nome_drs))


  # ajustando manualmente os codigos das DRS
  leitos$cod_drs[c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17)] <- c(10, 7, 8, 13, 16, 12, 3, 4, 5, 11, 2, 9, 1, 14, 15, 6, 17)

  casos_drs <- casos %>%
    dplyr::arrange(desc(datahora)) %>%
    dplyr::group_by(cod_drs, datahora) %>%
    dplyr::summarise(
      total_novos_casos = sum(casos_novos),
      total_novos_obitos = sum(obitos_novos)
    ) %>%
    dplyr::mutate(
      mm7d_casos = data.table::frollmean(total_novos_casos, 7),
      mm7d_obitos = data.table::frollmean(total_novos_obitos, 7)
    ) %>%
    dplyr::left_join(leitos, by = c("datahora", "cod_drs"))

  casos_drs$datahora <- casos_drs$datahora %>% lubridate::as_date()

  # trocando as virgulas por pontos
  casos_drs$ocupacao_leitos <- as.numeric(gsub(",", ".", gsub("\\.", "", casos_drs$ocupacao_leitos)))


  casos_drs
}
