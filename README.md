# Gather-Covid

A package to download and pre-process covid-19 Brazil's data from brasil.io.

```{r}
  library(gather.covid)
```

# Installing

```{r}
  remotes::install_github("predict-icmc/gather-data")
```

## Dependencies 

This package relies on `tidyverse` and `data.table` packages

## Usage

We can choose one of three arguments for **type** in the function `pegaCorona`

- caso_full: return a tibble with the cases in all Brazilian cities since day 0;
- cart: return public notary's office's registered deaths
- last_cases: return last balance of cases released, with cities' latitude and longitude

## Examples
```{r}

  df <- pegaCorona(tipo = "caso_full")

  df %>% filter(city == "Curitiba") %>% ggplot() + geom_line(aes(x = tempo, y = last_available_confirmed))
```

```{r}
  library(leaflet)
  df <- pegaCorona(tipo = "last_cases")

  pal <- colorBin("viridis", df[["last_available_confirmed"]], 8, pretty = T)

  df %>% leaflet() %>% 
    addTiles(attribution = 'Dados extraídos do site <a href="http://brasil.io/">brasil.io</a>') %>%
    setView(lng =  -47.9292, lat = -15.7801, zoom = 4) %>% 
    addCircleMarkers(~longitude, ~latitude, color = pal(df[["new_confirmed"]]))
```

