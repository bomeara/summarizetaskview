#' Run package check
#'
#' This runs a check of a given package by downloading it, running goodpractice, and checking other aspects of it.
#'
#' @param pkg The package name (a string)
#' @return a list containing a goodpractice object (goodpractice_result), a data.frame from packagemetrics packagemetrics_result), a data.frame of other information from crandb (package_info), and output from cran_donloads of daily downloads since 2013
#' @export
#' @examples
#' goodness <- run_package_check('hisse')
#' print(goodness$goodpractice_result)
run_package_check <- function(pkg) {
  goodpractice_result <- NULL
  packagemetrics_result <- NULL
  crandb_info <- NULL
  downloads <- NULL
  try(download_info <- download.packages(pkg, destdir=tempdir(), type="source"))
  try(untar(download_info[1,2], exdir=tempdir()))
  try(unlink(file.path(tempdir(), download_info[1,1], "inst", "doc"), recursive=TRUE)) # to prevent interactive dialog when this gets overwritten
  try(goodpractice_result <- goodpractice::goodpractice(file.path(tempdir(), download_info[1,1])))
  try(packagemetrics_result <- packagemetrics::package_list_metrics(pkg))
  try(crandb_info <- crandb::package(pkg, version="all"))
  try(downloads <- cranlogs::cran_downloads(pkg, from="2013-01-01", to=Sys.Date()-1))
  try(unlink(file.path(tempdir(), download_info[1,1])))
  return(list(goodpractice_result=goodpractice_result, packagemetrics_result=packagemetrics_result, package_info=crandb_info, downloads=downloads))
}

#' Plot downloads and package updates
#'
#' This will plot downloads, a smoothed line of downloads through time, and vertical lines showing package updates on CRAN
#'
#' @param pkgcheck output from run_package_check
#' @return A ggplot2 object
#' @export
plot_package_check <- function(pkgcheck) {
  my_plot <- ggplot2::ggplot(pkgcheck$downloads, ggplot2::aes(x=date, y=count)) +
    ggplot2::ggtitle(pkgcheck$package_info$name) +
    ggplot2::geom_point(alpha=0.2) +
    ggplot2::geom_smooth() + ggplot2::scale_y_continuous(trans='log10') + ggplot2::geom_vline(xintercept=lubridate::as_date(unlist(pkgcheck$package_info$timeline)), color="red") + ggplot2::xlim(min(lubridate::as_date(unlist(pkgcheck$package_info$timeline)), pkgcheck$downloads$date), Sys.Date())
    my_plot
    return(my_plot)
}

#' Get names of all packages from a view
#'
#' Uses very elegant code by Jonathan Chang: https://jonathanchang.org/blog/what-r-package-for-phylogenetics-is-the-most-popular/
#'
#' @param view View name to get packages from
#' @return vector of packages
#' @export
get_all_packages_in_view <- function(view) {
  return((Filter(function(x) x$name == view, ctv::available.views())[[1]])$packagelist$name)
}

#' Check a vector of packages
#'
#' This will run the checks for all the packages in the vector. You can run in parallel if you set ncores to greater than one and have an operating system that can support this. When this is done, you can use sapply(<list of packages>, summarize_goodness) to get summaries for all.
#'
#' @param pkgs a vector of packages
#' @param ncores how many cores to use
#' @return a list of of package checks, one per package
#' @examples
#' all_packages <- get_all_packages_in_view("Phylogenetics")
#' fewer_packages <- all_packages[1:3]
#' all_checks <- check_all_packages(fewer_packages)
#' organized_results <- t(sapply(all_checks, summarize_goodness))
#' print(organized_results)
#' @export
check_all_packages <- function(pkgs, ncores=1) {
  return(parallel::mclapply(pkgs, run_package_check, mc.cores=ncores))
}

#' Runs tests for all packages in a task view and stores inside this package
#'
#' @param view View name to get packages from
#' @param ncores Number of cores to use
#' @return nothing, though a data file has been saved
#' @export
cache_all_from_view <- function(view="Phylogenetics", ncores=parallel::detectCores()) {
  all_packages <- check_all_packages(get_all_packages_in_view(view), ncores=ncores)
  devtools::use_data(all_packages, overwrite=TRUE)
}

#' Quality information for phyogenetics packages
#'
#' A dataset of outputs of run_package_check for every package in the Phylogenetics task view
#'
#' @format A list containing lists of quality information
"all_packages"

#' Summarize goodness of a package
#'
#' Gives useful information about downloads, updates, best practices, and more
#' @param pkgcheck output from run_package_check
#' @return A data.frame with information
#' @export
#' @examples
#'  t(sapply(all_packages, summarize_goodness))
summarize_goodness <- function(pkgcheck) {
  results_vector <- goodpractice::results(pkgcheck$goodpractice_result)$result
  names(results_vector) <- goodpractice::results(pkgcheck$goodpractice_result)$check
  goodness_result <- data.frame(
    package = pkgcheck$package_info$name,
    last_update = as.character(max(lubridate::as_date(unlist(pkgcheck$package_info$timeline)))),
    years_since_last_update = round(as.numeric((Sys.Date() - max(lubridate::as_date(unlist(pkgcheck$package_info$timeline)))))/365,2),
    years_since_first_release = round(as.numeric((Sys.Date() - min(lubridate::as_date(unlist(pkgcheck$package_info$timeline)))))/365,2),
    number_of_CRAN_releases = length(pkgcheck$package_info$timeline),
    has_coverage = !is.na(results_vector["covr"]),
    has_url = results_vector["description_url"],
    has_bug_reporting = results_vector["description_bugreports"],
    downloads_last_year = sum(tail(pkgcheck$downloads$count, 365)),
    has_vignette_build = pkgcheck$packagemetrics_result$has_vignette_build,
    percent_maximum_ideal_complexity = ifelse(class(pkgcheck$goodpractice_result$cyclocomp)=="try-error", NA, max(10*pkgcheck$goodpractice_result$cyclocomp$cyclocomp)), #assumes 10 is ideal, so if 13, then that is 30% over, so 130% max ideal complexity
    days_since_last_issue_closed = pkgcheck$packagemetrics_result$last_issue_closed*30, #since they use /30: https://github.com/ropenscilabs/packagemetrics/blob/00846df741fbcc672bfde2371b0877186283d5f9/R/scrape_github_url.R#L112
    days_since_last_commit = pkgcheck$packagemetrics_result$last_commit*30,
    stringsAsFactors=FALSE
  )
  rownames(goodness_result) <- NULL
  return(goodness_result)
}
