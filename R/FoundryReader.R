
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
      #' @return A tibble of the query results.
      run_query = function(sql_query) {

        futile.logger::flog.info(
          "Executing SQL: %s",
          sql_query,
          name = private$.log_name
        )

        # get raw results
        result <- private$.run_query(sql_query)

        if (is.null(result)) return(NULL)

        # leave any unknown column types as character
        col_codes <- result$metadata$columnTypes %>%
          dplyr::mutate(
            col_code = dplyr::case_when(
              type == "STRING" ~"c",
              type == "DOUBLE" ~"d",
              type == "DATE" ~"D",
              type == "LONG" ~"i",
              TRUE ~"c"
            )
          ) %>%
          .$col_code %>%
          paste(collapse = "")

        if (result$metadata$rowCount > 0) {
          df <- result$rows %>%
            dplyr::as_tibble() %>%
            magrittr::set_colnames(result$metadata$columns)

        } else {
          futile.logger::flog.warn(
            "Query returned no rows, returning empty tibble",
            name = private$.log_name
          )

          # create empty version of table
          df <- sapply(result$metadata$columns, function(x) character()) %>%
            dplyr::as_tibble()
        }

        # return a dataframe version of data, with an empty but correctly
        # formatted tibble if no data returned
        return(
          df %>%
            readr::type_convert(col_types = col_codes)
        )
      },

      #' @description
      #' Get an in memory version of a dataset (first 10 rows only).
      #' @param dataset_path (`character()`)\cr
      #' full Foundry path to dataset of the type "/path/to/dataset".
      #' @return A `dplyr` remote source table.
      get_dataset = function(dataset_path) {
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
              private$.dataset_path
            )

          dplyr::copy_to(
            private$.con_memdb,
            self$run_query(sql_query),
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
      #' @param db_query a lazy dataframe \cr
      #' The transformed output of `FoundryReader::get_dataset(dataset_path)`.
      #' @return A tibble of the retrieved data.
      collect = function(db_query) {
        # Correct for differences between RSQLite and SparkSQL SQL
        # remove newlines
        # surrounded dataset path in double quotes
        # remove back ticks around variable names
        sql_query <- dbplyr::sql_render(db_query) %>%
          stringr::str_replace_all("\n", " ") %>%
          stringr::str_replace_all("FROM `(.+?)`", "FROM \"\\1\"") %>%
          stringr::str_replace_all("`", "")

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
      .url = "https://ppds.palantirfoundry.co.uk/foundry-sql-server/api/queries",

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

        result <- list()

        if (private$.parse_response()) {
          # drop first character that is an "S"
          result <-
            httr::content(
              private$.response,
              as = "text",
              encoding = "UTF-8"
            ) %>%
            stringr::str_sub(2) %>%
            jsonlite::fromJSON()
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