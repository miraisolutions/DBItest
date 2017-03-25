#' spec_connection_disconnect
#' @usage NULL
#' @format NULL
#' @keywords NULL
spec_connection_disconnect <- list(
  disconnect_formals = function(ctx) {
    # <establish formals of described functions>
    expect_equal(names(formals(dbDisconnect)), c("conn", "..."))
  },

  #' @return
  can_disconnect = function(ctx) {
    con <- connect(ctx)
    #' `dbDisconnect()` returns `TRUE`, invisibly.
    expect_invisible_true(dbDisconnect(con))
  },

  #' @section Specification:
  cannot_disconnect_twice = function(ctx) {
    expect_warning(gc(), NA)
    connect(ctx)
    #' A warning is issued on garbage collection when a connection has been
    #' released without calling `dbDisconnect()`.
    expect_warning(gc())
  },

  cannot_disconnect_twice = function(ctx) {
    con <- connect(ctx)
    dbDisconnect(con)
    #' A warning is issued immediately when calling `dbDisconnect()` on an
    #' already disconnected connection.
    expect_warning(dbDisconnect(con))
  },

  NULL
)