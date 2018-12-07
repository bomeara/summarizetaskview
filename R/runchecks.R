#' Run package check
#'
#' This runs a check of a given package by downloading it, running goodpractice, and checking other aspects of it.
#'
#' @param pkg The package name (a string)
#' @return a list containing a goodpractice object (goodpractice_result), a data.frame of other information from crandb (package_info), and output from cran_donloads of daily downloads since 2013
#' @export
#' @examples
#' goodness <- run_package_check('hisse')
#' print(goodness$goodpractice_result)
run_package_check <- function(pkg) {
  download_info <- download.packages(pkg, destdir=tempdir(), type="source")
  untar(download_info[1,2], exdir=tempdir())
  unlink(file.path(tempdir(), download_info[1,1], "inst", "doc"), recursive=TRUE) # to prevent interactive dialog when this gets overwritten
  goodpractice_result <- goodpractice::goodpractice(file.path(tempdir(), download_info[1,1]))
  crandb_info <- crandb::package(pkg, version="all")
  downloads <- cranlogs::cran_downloads(pkg, from="2013-01-01", to=Sys.Date()-1)
  return(list(goodpractice_result=goodpractice_result, package_info=crandb_info, downloads=downloads))
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
  return((Filter(function(x) x$name == view, available.views())[[1]])$packagelist$name)
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


#' Summarize goodness of a package
#'
#' Gives useful information about downloads, updates, best practices, and more
#' @param pkgcheck output from run_package_check
#' @return A data.frame with information
#' @export
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
    stringsAsFactors=FALSE
  )
  rownames(goodness_result) <- NULL
  return(goodness_result)
}
