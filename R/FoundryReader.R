
#' @title R6 Class wrapping the Foundry API
#'
#' @description
#' Wrapper for the Foundry API which allows SparkSQL to be run against datasets.
#' @export
FoundryReader <-
  R6::R6Class(
    "FoundryReader",
    public = list(

      #' @description
      #' Create a new FoundryReader object.
      #' @param token (`character()`)\cr
      #' BEARER token for connection.
      #' @param log_name (`character()`)\cr
      #' name of log to write to.
      #' @return A new `FoundryReader` object.
      initialize = function(token, log_name = "dhsc_data_store.FoundryReader") {
        stopifnot(
          "`token` must be a character string" = is.character(token)
        )

        stopifnot(
          "`log_name` must be a character string" = is.character(log_name)
        )
        private$.token <- paste("Bearer", token)
        private$.log_name <- log_name

        # default to only showing warnings and above
        futile.logger::flog.threshold(
          futile.logger::WARN,
          name = log_name
        )
      },

      #' @description
      #' Run a SparkSQL query through the Foundry API.
      #' @param sql_query (`character()`)\cr
      #' SparkSQL query to run.
      #' @param parse_json (`logical()`)\cr
      #' If the server returns a json should we parse into a tibble
      #' @return Either a tibble or json of the query results.
      run_query = function(sql_query, parse_json = TRUE) {
        stopifnot(
          "`sql_query` must be a character string" = is.character(sql_query)
        )

        futile.logger::flog.info(
          "Executing SQL: %s",
          sql_query,
          name = private$.log_name
        )

        # get raw results
        result <- private$.run_query(sql_query)

        if (is.null(result)) return(NULL)

        return_data <- result$data

        if (result$control_byte == "s") {
          if (result$data$metadata$rowCount == 0) {
            futile.logger::flog.warn(
              "Query returned no rows", name = private$.log_name
            )
          }

          if (parse_json) {
            return_data <- self$parse_query_json(return_data)
          }
        } else if (result$control_byte == "a") {
          if (nrow(return_data) == 0) {
            futile.logger::flog.warn(
              "Query returned no rows", name = private$.log_name
            )
          }
        }

        return(return_data)
      },

      #' @description
      #' Parse a returned query JSON into a tibble.
      #' @param query_json (`character()`)\cr
      #' Query JSON to parse.
      #' @return A tibble of the query results.
      parse_query_json = function(query_json) {

        # leave any unknown column types as character
        col_codes <- query_json$metadata$columnTypes %>%
          dplyr::mutate(
            col_code = dplyr::case_when(
              type == "STRING" ~"c",
              type == "DOUBLE" ~"d",
              type == "DATE" ~"D",
              type == "LONG" ~"i",
              type == "INTEGER" ~"i",
              TRUE ~"c"
            )
          ) %>%
          .$col_code %>%
          paste(collapse = "")

        if (query_json$metadata$rowCount > 0) {
          df <- query_json$rows %>%
            magrittr::set_colnames(query_json$metadata$columns) %>%
            dplyr::as_tibble()
        } else {
          # create empty version of table
          df <- sapply(query_json$metadata$columns, function(x) character()) %>%
            dplyr::as_tibble()
        }

        # return a data frame version of data, with an empty but correctly
        # formatted tibble if no data returned
        return(
          df %>%
            dplyr::mutate(dplyr::across(dplyr::everything(), as.character)) %>%
            readr::type_convert(col_types = col_codes)
        )
      },

      #' @description
      #' Get an in memory version of a dataset (first 10 rows only).
      #' @param dataset_path (`character()`)\cr
      #' full Foundry path to dataset of the type "/path/to/dataset".
      #' @return A `dplyr` remote source table.
      get_dataset = function(dataset_path) {
        stopifnot(
          "`dataset_path` must be a character string" =
            is.character(dataset_path)
        )

        # create in memory RSQlite database if needed
        if (is.null(private$.con_memdb)) {
          private$.con_memdb <-
            DBI::dbConnect(
              RSQLite::SQLite(),
              ":memory:",
              create = TRUE
            )
        }

        # read first 10 lines of dataset and load into in memory database
        if (!(dataset_path %in% DBI::dbListTables(private$.con_memdb))) {
          sql_query <-
            sprintf(
              paste(
                "SELECT",
                "*",
                "FROM \"%s\"",
                "LIMIT 10"
              ),
              dataset_path
            )

          df <- self$run_query(sql_query)
          if (is.null(df)) return(NULL)

          dplyr::copy_to(
            private$.con_memdb,
            df,
            name = dataset_path
          )

        }

        # create a `dplyr` table based on dataset
        return(
          dplyr::tbl(
            private$.con_memdb,
            dataset_path
          )
        )
      },

      #' @description
      #' Retrieves data into a local tibble from the Foundry API.
      #' @param sql_df a lazy SQL data frame \cr
      #' The transformed output of `FoundryReader::get_dataset(dataset_path)`.
      #' @return A tibble of the retrieved data.
      collect = function(sql_df) {
        stopifnot(
         "`sql_df` must be a lazy SQL data frame" =
           "tbl_sql" %in% class(sql_df)
        )

        # Correct for differences between RSQLite and SparkSQL SQL
        # remove newlines
        # surrounded dataset path in double quotes
        # remove back ticks around variable names
        sql_query <- dbplyr::sql_render(sql_df) %>%
          stringr::str_replace_all("\n", " ")

        table_name <- stringr::str_extract(
          sql_query,
          "FROM `(.+?)`",
          group = 1
        )

        sql_query <- sql_query %>%
          stringr::str_replace_all(
            stringr::fixed(sprintf("`%s`.", table_name)),
            ""
          ) %>%
          stringr::str_replace_all("FROM `(.+?)`", "FROM \"\\1\"") %>%
          stringr::str_replace_all("`", "") %>%
          stringr::str_replace_all("''", "'")

        # execute SQL
        return(
          self$run_query(sql_query)
        )
      },

      #' @description
      #' Get tibble of metrics along with summary statistics.
      #' @param dataset_path (`character()`)\cr
      #' full Foundry path to dataset of the type "/path/to/dataset".
      #' @return A tibble of metrics and their statistics.
      get_metrics = function(dataset_path) {
        stopifnot(
          "`dataset_path` must be a character string" =
            is.character(dataset_path)
        )

        sql_query <-
          sprintf(
            paste(
              "SELECT",
              "metric_name, metric_description, location_type,",
              "COUNT(*) AS count_rows,",
              "MAX(date) AS max_date, MIN(date) AS min_date,",
              "APPROX_COUNT_DISTINCT(location_id) AS count_locations",
              "FROM \"%s\"",
              "GROUP BY metric_name, metric_description, location_type",
              "ORDER BY metric_name, metric_description, location_type"
            ),
            dataset_path
          )

        # execute SQL
        return(
          self$run_query(sql_query)
        )
      },

      #' @description
      #' Get the last error response returned from the server.
      #' @return A list of status, content, and full response from the server.
      get_last_error = function() {
        return(private$.last_error)
      },

      #' @description
      #' Get the name of the `futile.logger` log being used by the reader.
      #' @return name of log.
      #' @examples
      #' # change log threshold to INFO
      #' fapi <- readfoundry::FoundryReader$new(Sys.getenv("BEARER"))
      #' futile.logger::flog.threshold(
      #'   futile.logger::INFO,
      #'   name = fapi$get_log_name()
      #')
      #'
      get_log_name = function() {
        return(private$.log_name)
      },

      #' @description
      #' Clean up the in memory database.
      finalize = function() {
        if (!is.null(private$.con_memdb)) {
          DBI::dbDisconnect(private$.con_memdb)
        }
      }
    ),
    private = list(
      # base endpoint url of the api
      .url = "https://england.federateddataplatform.nhs.uk/foundry-sql-server/api/queries",

      # query id assigned by SQL server
      .query_id = NULL,

      # current server response
      .response = NULL,

      # BEARER token
      .token = NULL,

      # connection to in memory RSQLite database
      .con_memdb = NULL,

      # futile logger name
      .log_name = NULL,

      # last error returned by server
      .last_error = NULL,

      .parse_response = function() {
        if (httr::http_error(private$.response)) {
          # reset query_id
          private$.query_id <- NULL

          private$.last_error <- list(
            status = httr::http_status(private$.response),
            content = httr::content(private$.response),
            full_response = private$.response
          )

          futile.logger::flog.error(
            "Server returned message: %s",
            httr::http_status(private$.response)$message,
            name = private$.log_name
          )

          futile.logger::flog.error(
            "Call `FoundryReader$get_last_error()` to view details",
            name = private$.log_name
          )

          return(FALSE)
        }

        return(TRUE)
      },

      .execute_query = function(sql_query) {
        endpoint_url =
          sprintf(
            "%s/execute",
            private$.url
          )

        futile.logger::flog.info(
          "Querying: %s",
          endpoint_url,
          name = private$.log_name
        )

        private$.response <- httr::POST(
          url = endpoint_url,
          config = httr::add_headers(
            Authorization = private$.token,
            Accept = "application/json",
            `Content-Type` = "application/json"
          ),
          body = list(
            query = sql_query,
            dialect = "ANSI",
            serializationProtocol = "ARROW",
            fallbackBranchIds = NULL
          ),
          encode = "json"
        )

        private$.query_id <- NULL

        if (private$.parse_response()) {
          resp_content <- httr::content(
            private$.response,
            as = "parsed",
            type = "application/json"
          )

          private$.query_id <- resp_content$queryId
        }

        return(invisible(self))
      },

      .get_query_status = function() {

        if (is.null(private$.query_id)) return(invisible(self))

        endpoint_url =
          sprintf(
            "%s/%s/status",
            private$.url,
            private$.query_id
          )

        futile.logger::flog.info(
          "Querying: %s",
          endpoint_url,
          name = private$.log_name
        )

        private$.response <- httr::GET(
          url = endpoint_url,
          config = httr::add_headers(
            Authorization = private$.token,
            `Content-Type` = "application/json"
          )
        )

        if (private$.parse_response()) {
          resp_content <- httr::content(
            private$.response,
            as = "parsed",
            type = "application/json"
          )

          return(resp_content$status$type)
        } else {
          return("error")
        }
      },

      .get_query_results = function() {

        if (is.null(private$.query_id)) return(invisible(self))

        endpoint_url =
          sprintf(
            "%s/%s/results",
            private$.url,
            private$.query_id
          )

        futile.logger::flog.info(
          "Querying: %s",
          endpoint_url,
          name = private$.log_name
        )

        private$.response <- httr::GET(
          url = endpoint_url,
          config = httr::add_headers(
            Authorization = private$.token,
            Accept = "application/octet-stream"
          )
        )

        result <- NULL

        if (private$.parse_response()) {
          result <- list()

          # read initial byte of response to determine type
          result_raw <-
            httr::content(
              private$.response,
              as = "raw"
            )

          result$control_byte <- tolower(rawToChar(result_raw[[1]]))
          result_raw <- result_raw[2:length(result_raw)]

          # control codes
          # s = json; a = arrow; other = ?
          if (result$control_byte == "s") {
            result$data <- readBin(result_raw, character()) %>%
              jsonlite::fromJSON()
          } else if (result$control_byte == "a") {
            result$data <- arrow::read_ipc_stream(result_raw) %>%
              dplyr::as_tibble()
          } else {
            stop(sprintf("Unknown encoding %s", result$control_byte))
          }
        }

        return(result)
      },

      .run_query = function(sql_query) {

        private$.execute_query(sql_query)

        if (is.null(private$.query_id)) return(NULL)

        status <- private$.get_query_status()
        while(status == "running") {
          status <- private$.get_query_status()

          futile.logger::flog.info(
            "Query status is: %s",
            status,
            name = private$.log_name
          )
        }

        if(status != "ready") return(NULL)

        return(private$.get_query_results())
      }
    )
  )
