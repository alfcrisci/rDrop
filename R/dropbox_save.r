#' Function to save an object from R into Dropbox (not working)
#'
#' This function currently does not work.
#' @param cred Specifies an object of class ROAuth with Dropobox specific credentials.
#' @param list List of objects from the current R environment that needs to be saved into dropbox
#' @param file Required filename. No extenstion needs to be supplied. If you provide one, it will be stripped and replace with rda.
#' @param envir optional. Defaults to parent environment.
#' @param precheck internal use. Checks to make sure all objects are in the parent environment.
#' @param curl If using in a loop, call getCurlHandle() first and pass
#'  the returned value in here (avoids unnecessary footprint)
#' @param verbose default is FALSE. Set to true to receive full outcome.
#' @param ... optional additional curl options (debugging tools mostly)
#' @export
#' @return JSON object
#' @examples \dontrun{
#' dropbox_save(cred, robject, file='filename')
#' dropbox_save(cred, file = "testRData", .objs = list(a = 1:3, b = letters[1:10]))
#' a = dropbox_get(cred, "testRData.rdata", binary = TRUE)
#' val = unserialize(rawConnection(a))
#'}
dropbox_save <-
 function(cred, list = character(), 
          file = stop("'file' must be specified"), envir = parent.frame(), 
          precheck = TRUE, verbose = FALSE, curl = getCurlHandle(), 
          ..., .objs = NULL)
{
    if (!is(cred, "DropboxCredentials") || missing(cred)) 
        stop("Invalid or missing Dropbox credentials. ?dropbox_auth for more information.")


    if(missing(.objs)) {
        names <- as.character(substitute(list(...)))[-1L]
        list <- c(list, names)
        if (precheck) {
          ok <- unlist(lapply(list, exists, envir = envir))
          if (!all(ok)) {
            n <- sum(!ok)
            stop(sprintf(ngettext(n, "object %s not found", "objects %s not found"), 
                         paste(sQuote(list[!ok]), collapse = ", ")), domain = NA)
          }
        }
        .objs = structure(lapply(list, get, envir),
                           names = list)
     }

    
    if (is.character(file) && !nzchar(file))  
        stop("'file' must be non-empty string")


    filename <- if(!is(file, "AsIs"))
                    paste(str_trim(str_extract(file, "[^.]*")), ".rdata", 
                           sep = "")
                else
                    file
 
     url <- sprintf("https://api-content.dropbox.com/1/files_put/dropbox/%s", filename)

    con <- rawConnection(raw(), "w")
    serialize(.objs, con)
#    serialize(list(a = 1:10, b = letters), con)
    
    z <- rawConnectionValue(con)
    on.exit(close(con))    
    input <- RCurl:::uploadFunctionHandler(z, TRUE)
    
    drop_save <- fromJSON(OAuthRequest(cred, url, , "PUT", upload = TRUE, 
        readfunction = input, infilesize = length(z), verbose = FALSE, 
        httpheader = c(`Content-Type` = "application/octet-stream")))

    if (verbose) {
      if (is.list(drop_save)) {
            cat("File succcessfully drop_saved to", drop_save$path, 
                "on", drop_save$modified)
      }
    }
    
    drop_save
}
# API documentation: GET:
#   https://www.dropbox.com/developers/reference/api#files-GET   
