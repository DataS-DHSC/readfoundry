% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/FoundryReader.R
\name{FoundryReader}
\alias{FoundryReader}
\title{R6 Class wrapping the Foundry API}
\description{
Wrapper for the Foundry API which allows SparkSQL to be run against datasets.
}
\examples{

## ------------------------------------------------
## Method `FoundryReader$get_log_name`
## ------------------------------------------------

# change log threshold to INFO
fapi <- readfoundry::FoundryReader$new(Sys.getenv("BEARER"))
futile.logger::flog.threshold(
  futile.logger::INFO,
  name = fapi$get_log_name()
)

}
\section{Methods}{
\subsection{Public methods}{
\itemize{
\item \href{#method-FoundryReader-new}{\code{FoundryReader$new()}}
\item \href{#method-FoundryReader-run_query}{\code{FoundryReader$run_query()}}
\item \href{#method-FoundryReader-parse_query_json}{\code{FoundryReader$parse_query_json()}}
\item \href{#method-FoundryReader-get_dataset}{\code{FoundryReader$get_dataset()}}
\item \href{#method-FoundryReader-collect}{\code{FoundryReader$collect()}}
\item \href{#method-FoundryReader-get_metrics}{\code{FoundryReader$get_metrics()}}
\item \href{#method-FoundryReader-get_last_error}{\code{FoundryReader$get_last_error()}}
\item \href{#method-FoundryReader-get_log_name}{\code{FoundryReader$get_log_name()}}
\item \href{#method-FoundryReader-finalize}{\code{FoundryReader$finalize()}}
\item \href{#method-FoundryReader-clone}{\code{FoundryReader$clone()}}
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-FoundryReader-new"></a>}}
\if{latex}{\out{\hypertarget{method-FoundryReader-new}{}}}
\subsection{Method \code{new()}}{
Create a new FoundryReader object.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{FoundryReader$new(token, log_name = "dhsc_data_store.FoundryReader")}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{token}}{(\code{character()})\cr
BEARER token for connection.}

\item{\code{log_name}}{(\code{character()})\cr
name of log to write to.}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
A new \code{FoundryReader} object.
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-FoundryReader-run_query"></a>}}
\if{latex}{\out{\hypertarget{method-FoundryReader-run_query}{}}}
\subsection{Method \code{run_query()}}{
Run a SparkSQL query through the Foundry API.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{FoundryReader$run_query(sql_query, parse_json = TRUE)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{sql_query}}{(\code{character()})\cr
SparkSQL query to run.}

\item{\code{parse_json}}{(\code{logical()})\cr
If the server returns a json should we parse into a tibble}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
Either a tibble or json of the query results.
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-FoundryReader-parse_query_json"></a>}}
\if{latex}{\out{\hypertarget{method-FoundryReader-parse_query_json}{}}}
\subsection{Method \code{parse_query_json()}}{
Parse a returned query JSON into a tibble.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{FoundryReader$parse_query_json(query_json)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{query_json}}{(\code{character()})\cr
Query JSON to parse.}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
A tibble of the query results.
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-FoundryReader-get_dataset"></a>}}
\if{latex}{\out{\hypertarget{method-FoundryReader-get_dataset}{}}}
\subsection{Method \code{get_dataset()}}{
Get an in memory version of a dataset (first 10 rows only).
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{FoundryReader$get_dataset(dataset_path)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{dataset_path}}{(\code{character()})\cr
full Foundry path to dataset of the type "/path/to/dataset".}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
A \code{dplyr} remote source table.
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-FoundryReader-collect"></a>}}
\if{latex}{\out{\hypertarget{method-FoundryReader-collect}{}}}
\subsection{Method \code{collect()}}{
Retrieves data into a local tibble from the Foundry API.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{FoundryReader$collect(sql_df)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{sql_df}}{a lazy SQL data frame \cr
The transformed output of \code{FoundryReader::get_dataset(dataset_path)}.}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
A tibble of the retrieved data.
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-FoundryReader-get_metrics"></a>}}
\if{latex}{\out{\hypertarget{method-FoundryReader-get_metrics}{}}}
\subsection{Method \code{get_metrics()}}{
Get tibble of metrics along with summary statistics.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{FoundryReader$get_metrics(dataset_path)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{dataset_path}}{(\code{character()})\cr
full Foundry path to dataset of the type "/path/to/dataset".}
}
\if{html}{\out{</div>}}
}
\subsection{Returns}{
A tibble of metrics and their statistics.
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-FoundryReader-get_last_error"></a>}}
\if{latex}{\out{\hypertarget{method-FoundryReader-get_last_error}{}}}
\subsection{Method \code{get_last_error()}}{
Get the last error response returned from the server.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{FoundryReader$get_last_error()}\if{html}{\out{</div>}}
}

\subsection{Returns}{
A list of status, content, and full response from the server.
}
}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-FoundryReader-get_log_name"></a>}}
\if{latex}{\out{\hypertarget{method-FoundryReader-get_log_name}{}}}
\subsection{Method \code{get_log_name()}}{
Get the name of the \code{futile.logger} log being used by the reader.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{FoundryReader$get_log_name()}\if{html}{\out{</div>}}
}

\subsection{Returns}{
name of log.
}
\subsection{Examples}{
\if{html}{\out{<div class="r example copy">}}
\preformatted{# change log threshold to INFO
fapi <- readfoundry::FoundryReader$new(Sys.getenv("BEARER"))
futile.logger::flog.threshold(
  futile.logger::INFO,
  name = fapi$get_log_name()
)

}
\if{html}{\out{</div>}}

}

}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-FoundryReader-finalize"></a>}}
\if{latex}{\out{\hypertarget{method-FoundryReader-finalize}{}}}
\subsection{Method \code{finalize()}}{
Clean up the in memory database.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{FoundryReader$finalize()}\if{html}{\out{</div>}}
}

}
\if{html}{\out{<hr>}}
\if{html}{\out{<a id="method-FoundryReader-clone"></a>}}
\if{latex}{\out{\hypertarget{method-FoundryReader-clone}{}}}
\subsection{Method \code{clone()}}{
The objects of this class are cloneable with this method.
\subsection{Usage}{
\if{html}{\out{<div class="r">}}\preformatted{FoundryReader$clone(deep = FALSE)}\if{html}{\out{</div>}}
}

\subsection{Arguments}{
\if{html}{\out{<div class="arguments">}}
\describe{
\item{\code{deep}}{Whether to make a deep clone.}
}
\if{html}{\out{</div>}}
}
}
}
