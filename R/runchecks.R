#' Run package check
#'
#' This runs a check of a given package by downloading it, running goodpractice, and checking other aspects of it.
#'
#' @param pkg The package name (a string)
#' @return a list containing a goodpractice object (goodpractice_result) and a data.frame of other information (package_info)
#' @export
#' @examples
#' goodness <- run_package_check('hisse')
#' print(goodness$goodpractice_result)
run_package_check <- function(pkg) {
  download_info <- download.packages(pkg, destdir=tempdir(), type="source")
  untar(download_info[1,2], exdir=tempdir())
  goodpractice_result <- goodpractice::goodpractice(file.path(tempdir(), download_info[1,1]))
  return(list(goodpractice_result=goodpractice_result, package_info=data.frame()))
}
