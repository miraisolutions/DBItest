run_tests <- function(ctx, tests, skip, run_only, test_suite) {
  "!DEBUG run_tests(`test_suite`)"

  if (is.null(ctx)) {
    stop("Need to call make_context() to use the test_...() functions.", call. = FALSE)
  }
  if (!inherits(ctx, "DBItest_context")) {
    stop("ctx must be a DBItest_context object created by make_context().", call. = FALSE)
  }

  test_context <- paste0(
    "DBItest", if (!is.null(ctx$name)) paste0("[", ctx$name, "]"),
    ": ", test_suite
  )
  context(test_context)

  tests <- tests[!vapply(tests, is.null, logical(1L))]
  tests <- get_run_only_tests(tests, run_only)

  if (is.null(skip)) {
    skip <- ctx$default_skip
  }

  skipped <- get_skip_names(skip)
  skip_flag <- names(tests) %in% skipped

  ok <- vapply(
    seq_along(tests),
    function(test_idx) {
      test_name <- names(tests)[[test_idx]]
      if (skip_flag[[test_idx]]) {
        FALSE
      } else {
        test_fun <- patch_test_fun(tests[[test_idx]], paste0(test_context, ": ", test_name))
        fmls <- formals(test_fun)

        args <- list()
        if ("ctx" %in% names(fmls)) {
          args <- c(args, list(ctx = ctx))
        }

        if ("con" %in% names(fmls)) {
          con <- local_connection(ctx)
          args <- c(args, list(con = con))
        }

        if ("closed_con" %in% names(fmls)) {
          closed_con <- local_closed_connection(ctx)
          args <- c(args, list(closed_con = closed_con))
        }

        if ("invalid_con" %in% names(fmls)) {
          invalid_con <- local_invalid_connection(ctx)
          args <- c(args, list(invalid_con = invalid_con))
        }

        if ("table_name" %in% names(fmls)) {
          if (rlang::is_missing(fmls$table_name)) {
            table_name <- random_table_name()
          } else {
            table_name <- fmls$table_name
          }
          local_remove_test_table(con, table_name)
          args <- c(args, list(table_name = table_name))
        }

        rlang::exec(test_fun, !!!args)
      }
    },
    logical(1L)
  )

  if (any(skip_flag)) {
    test_that(paste0(test_context, ": skipped tests"), {
      skip(paste0("by request: ", paste(names(tests)[skip_flag], collapse = ", ")))
    })
  }

  # to isolate test topics
  gc()

  ok
}

get_skip_names <- function(skip) {
  if (length(skip) == 0L) {
    return(character())
  }
  names_all <- names(spec_all)
  names_all <- names_all[names_all != ""]
  skip_flags_all <- lapply(paste0("(?:^(?:", skip, ")$)"), grepl, names_all, perl = TRUE)
  skip_used <- vapply(skip_flags_all, any, logical(1L))
  if (!all(skip_used)) {
    warning("Unused skip expressions: ", paste(skip[!skip_used], collapse = ", "),
      call. = FALSE
    )
  }

  skip_flag_all <- Reduce(`|`, skip_flags_all)
  skip_tests <- names_all[skip_flag_all]

  skip_tests
}

get_run_only_tests <- function(tests, run_only) {
  names_all <- names(tests)
  names_all <- names_all[names_all != ""]
  if (is.null(run_only)) {
    return(tests)
  }

  run_only_flags_all <- lapply(paste0("(?:^(?:", run_only, ")$)"), grepl, names_all, perl = TRUE)
  run_only_flag_all <- Reduce(`|`, run_only_flags_all)
  run_only_tests <- names_all[run_only_flag_all]

  tests[run_only_tests]
}

patch_test_fun <- function(test_fun, desc) {
  body_of_test_fun <- wrap_all_statements_with_expect_no_warning(body(test_fun))

  rlang::new_function(
    formals(test_fun),
    rlang::expr(
      test_that(!!desc, !!body_of_test_fun)
    )
  )
}

wrap_all_statements_with_expect_no_warning <- function(block) {
  stopifnot(identical(block[[1]], quote(`{`)))
  block[-1] <- lapply(block[-1], function(x) expr(expect_warning(!!x, NA)))
  block
}
