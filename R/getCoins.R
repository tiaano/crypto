#' Get historic crypto currency market data
#'
#' Scrape the crypto currency historic market tables from
#' CoinMarketCap <https://coinmarketcap.com> and display
#' the results in a date frame. This can be used to conduct
#' analysis on the crypto financial markets or to attempt
#' to predict future market movements or trends.
#'
#' @note  If experiencing issues, explicitly set \code{cpu_cores=1} to turn off parallel processing.
#'
#' @param coin string Name, symbol or slug of crypto currency, default is all tokens
#' @param limit integer Return the top n records, default is all tokens
#' @param cpu_cores integer Uses n cores for processing, default uses all cores
#' @param ... No arguments, return all coins
#' @param start_date string Start date to retrieve data from, format 'yyyymmdd'
#' @param end_date string End date to retrieve data from, format 'yyyymmdd'
#'
#' @return Crypto currency historic OHLC market data in a dataframe:
#'   \item{slug}{Coin url slug}
#'   \item{symbol}{Coin symbol}
#'   \item{name}{Coin name}
#'   \item{date}{Market date}
#'   \item{ranknow}{Current Rank}
#'   \item{open}{Market open}
#'   \item{high}{Market high}
#'   \item{low}{Market low}
#'   \item{close}{Market close}
#'   \item{volume}{Volume 24 hours}
#'   \item{market}{USD Market cap}
#'   \item{close_ratio}{Close rate, min-maxed with the high and low values that day}
#'   \item{spread}{Volatility premium, high minus low for that day}
#'
#' This is the main function of the crypto package. If you want to retrieve
#' ALL coins then do not pass a argument to getCoins(), or pass the coin name.
#'
#' Please note that the doSNOW package is required to load the progress bar on
#' both linux and macOS systems as the doParallel package does not support it.
#'
#' @importFrom magrittr "%>%"
#' @importFrom foreach "%dopar%"
#' @importFrom foreach "%do%"
#' @importFrom utils "txtProgressBar"
#' @importFrom utils "setTxtProgressBar"
#' @importFrom utils "globalVariables"
#' @importFrom tidyr "replace_na"
#'
#' @import stats
#'
#' @examples
#' # retrieving market history for specific crypto currency
#'
#' coin <- "kin"
#' kin_coins <- listCoins(coin)
#'
#' \dontrun{
#'
#' # retrieving market history for ALL crypto currencies
#'
#' all_coins <- getCoins()
#'
#' # retrieving this years market history for ALL crypto currencies
#'
#' all_coins <- getCoins(start_date = '20180101')
#' }
#' @name getCoins
#'
#' @export
#'
getCoins <-
  function(coin = NULL, limit = NULL, cpu_cores = NULL, start_date = NULL, end_date = NULL) {
    ifelse(as.character(sys.call()[[1]]) == "getCoins",
      warning("DEPRECATED: Please use crypto_history() instead of getCoins().", call. = FALSE, immediate. = TRUE),
      shh <- ""
      )
    cat("Retrieves coin market history from CoinMarketCap. ")
    i <- "i"
    options(scipen = 999)
    sys_locale <- Sys.getlocale(category = "LC_TIME")
    replace_encoding(sys_locale)

    coins <- crypto_list(coin, start_date, end_date)
    if (!is.null(limit)) {
      coins <- coins[1:limit, ]
    }
    coinnames <-
      dplyr::data_frame(
        symbol = as.character(coins$symbol),
        name = as.character(coins$name),
        rank = coins$rank,
        slug = coins$slug
      )
    length <- as.numeric(length(coins$history_url))
    zrange <- 1:as.numeric(length(coins$history_url))
    if (is.null(cpu_cores)) {
      cpu_cores <- as.numeric(parallel::detectCores(all.tests = FALSE, logical = TRUE))
    }
    ptm <- proc.time()
    if (cpu_cores != 1) {
      cluster <- parallel::makeCluster(cpu_cores, type = "SOCK")
      doSNOW::registerDoSNOW(cluster)
    }

    pb <- txtProgressBar(max = length, style = 3)
    progress <- function(n)
      setTxtProgressBar(pb, n)
    opts <- list(progress = progress)
    attributes <- coins$history_url
    slug <- coins$slug
    message("   If this helps you become rich please consider donating",
      appendLF = TRUE
    )
    message("ERC-20: 0x375923Bf82F0b728d23A5704261a6e16341fd860",
      appendLF = TRUE
    )
    message("XRP: rK59semLsuJZEWftxBFhWuNE6uhznjz2bK", appendLF = TRUE)
    message("LTC: LWpiZMd2cEyqCdrZrs9TjsouTLWbFFxwCj", appendLF = TRUE)
    if (cpu_cores != 1) {
    results_data <- foreach::foreach(
      i = zrange,
      .errorhandling = c("remove"),
      .options.snow = opts,
      .packages = c("dplyr","plyr"),
      .combine = 'bind_rows',
      .verbose = FALSE
    ) %dopar% crypto::scraper(attributes[i], slug[i])
    close(pb)
    parallel::stopCluster(cluster)
    }
    if (cpu_cores == 1) {
      cat("Not parallel processing, so this will take a while.. please be patient.", fill = TRUE)
      results_data <- foreach::foreach(
        i = zrange,
        .errorhandling = c("remove"),
        .options.snow = opts,
        .packages = c("dplyr","plyr"),
        .combine = 'bind_rows',
        .verbose = FALSE
      ) %do% crypto::scraper(attributes[i], slug[i])
      close(pb)
    }

    print(proc.time() - ptm)
    if(length(results_data) == 0L) {
      stop("No data currently exists for this cryptocurrency that can be scraped.", call. = FALSE)
      }
    results <- merge(results_data, coinnames, by = "slug")
    marketdata <- results %>% as.data.frame()
    namecheck <- as.numeric(ncol(marketdata))
    ifelse(
      namecheck > 2,
      colnames(marketdata) <-
        c(
          "slug",
          "date",
          "open",
          "high",
          "low",
          "close",
          "volume",
          "market",
          "symbol",
          "name",
          "ranknow"
        ),
      NULL
    )
    marketdata <- marketdata[c(
      "slug",
      "symbol",
      "name",
      "date",
      "ranknow",
      "open",
      "high",
      "low",
      "close",
      "volume",
      "market"
    )]
    marketdata$date <-
      suppressWarnings(lubridate::mdy(unlist(marketdata$date)))
    cols <- c(5:11)
    ccols <- c(7:11)
    marketdata[, cols] <-
      apply(marketdata[, cols], 2, function(x)
        gsub(",", "", x))
    marketdata[, ccols] <-
      apply(marketdata[, ccols], 2, function(x)
        gsub("-", "0", x))
    marketdata$volume <- marketdata$volume %>% tidyr::replace_na(0) %>% as.numeric()
    marketdata$market <- marketdata$market %>% tidyr::replace_na(0) %>% as.numeric()
    marketdata[, cols] <-
      suppressWarnings(apply(marketdata[, cols], 2, function(x)
        as.numeric(x)))
    marketdata <- na.omit(marketdata)
    marketdata$close_ratio <-
      (marketdata$close - marketdata$low) / (marketdata$high - marketdata$low)
    marketdata$close_ratio <- round(marketdata$close_ratio, 4)
    marketdata$close_ratio <- marketdata$close_ratio %>% tidyr::replace_na(0) %>% as.numeric()
    marketdata$spread <- (marketdata$high - marketdata$low)
    marketdata$spread <- round(marketdata$spread, 2)
    results <- marketdata[order(marketdata$ranknow, marketdata$date, decreasing = FALSE), ]
    reset_encoding(sys_locale)
    return(results)
  }

#' @export
#' @rdname getCoins
crypto_history <- getCoins
