# ============================================================================
# Paper-grade Foster-Haltiwanger-Krizan (FHK) decomposition
# Corrected, defensive, base-R implementation for complex empirical panels.
#
# Standard endpoint identity:
#   Delta P = Within + Between + Cross + Entry + Exit
#
#   P_t     = sum_i s_it * p_it
#   Within  = sum_C s_i0 * (p_i1 - p_i0)
#   Between = sum_C (s_i1 - s_i0) * (p_i0 - P_0)
#   Cross   = sum_C (s_i1 - s_i0) * (p_i1 - p_i0)
#   Entry   = sum_E s_i1 * (p_i1 - P_0)
#   Exit    = -sum_X s_i0 * (p_i0 - P_0)
#
# Important interpretation:
# - Without external activity-window information, entry and exit mean SAMPLE
#   entry and SAMPLE exit between the two endpoints.
# - first_active_col / last_active_col can validate that observed turnover is
#   consistent with genuine business entry and exit.
# - Group decompositions normalize weights inside each group. Use
#   fhk_hierarchical() when both economy-wide and within-group results are
#   needed. Group-level components must not simply be added together.
#
# No external packages are required.
# ============================================================================


.fhk_assert_columns <- function(df, cols) {
  cols <- unique(cols[!is.na(cols) & nzchar(cols)])
  miss <- setdiff(cols, names(df))
  if (length(miss) > 0L) {
    stop("Missing columns: ", paste(miss, collapse = ", "), call. = FALSE)
  }
}


.fhk_assert_scalar_name <- function(x, label, allow_null = FALSE) {
  if (allow_null && is.null(x)) return(invisible(TRUE))
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    stop(label, " must be one non-empty column name.", call. = FALSE)
  }
  invisible(TRUE)
}


.fhk_assert_flag <- function(x, label) {
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    stop(label, " must be one non-missing TRUE/FALSE value.", call. = FALSE)
  }
  invisible(TRUE)
}


.fhk_validate_interface <- function(
    df,
    firm_col,
    time_col,
    prod_col,
    weight_col,
    group_cols,
    first_active_col,
    last_active_col,
    weight_is_share,
    renormalize_input_shares,
    require_t1_after_t0,
    fail_on_identity_error,
    tol) {

  if (!is.data.frame(df)) stop("df must be a data.frame or subclass.", call. = FALSE)
  if (anyDuplicated(names(df))) {
    stop("df contains duplicated column names; make names unique before analysis.", call. = FALSE)
  }

  .fhk_assert_scalar_name(firm_col, "firm_col")
  .fhk_assert_scalar_name(time_col, "time_col")
  .fhk_assert_scalar_name(prod_col, "prod_col")
  .fhk_assert_scalar_name(weight_col, "weight_col")
  .fhk_assert_scalar_name(first_active_col, "first_active_col", allow_null = TRUE)
  .fhk_assert_scalar_name(last_active_col, "last_active_col", allow_null = TRUE)

  if (!is.null(group_cols)) {
    if (!is.character(group_cols) || length(group_cols) == 0L ||
        anyNA(group_cols) || any(!nzchar(group_cols)) || anyDuplicated(group_cols)) {
      stop("group_cols must be NULL or unique, non-empty column names.", call. = FALSE)
    }
    reserved <- c(firm_col, time_col, prod_col, weight_col)
    if (length(intersect(group_cols, reserved)) > 0L) {
      stop("group_cols cannot reuse firm, time, productivity, or weight columns.", call. = FALSE)
    }
  }

  .fhk_assert_flag(weight_is_share, "weight_is_share")
  .fhk_assert_flag(renormalize_input_shares, "renormalize_input_shares")
  .fhk_assert_flag(require_t1_after_t0, "require_t1_after_t0")
  .fhk_assert_flag(fail_on_identity_error, "fail_on_identity_error")
  if (!is.numeric(tol) || length(tol) != 1L || is.na(tol) ||
      !is.finite(tol) || tol < 0) {
    stop("tol must be one finite, non-negative number.", call. = FALSE)
  }

  invisible(TRUE)
}


.fhk_period_label <- function(x) {
  if (length(x) != 1L || is.na(x)) return(NA_character_)
  as.character(x)
}


.fhk_same_period <- function(t0, t1) {
  identical(.fhk_period_label(t0), .fhk_period_label(t1))
}


.fhk_is_after <- function(later, earlier) {
  out <- tryCatch(later > earlier, error = function(e) NA)
  isTRUE(out)
}


.fhk_compare <- function(x, op, y, label) {
  out <- tryCatch(
    switch(op,
      ">" = x > y,
      ">=" = x >= y,
      "<" = x < y,
      "<=" = x <= y,
      stop("Unsupported comparison operator.", call. = FALSE)
    ),
    error = function(e) {
      stop(
        label, " cannot be compared with the requested periods. ",
        "Use compatible numeric, Date, POSIXct, or sortable character values.",
        call. = FALSE
      )
    }
  )
  if (!is.logical(out) || anyNA(out)) {
    stop(label, " contains values that cannot be ordered reliably.", call. = FALSE)
  }
  out
}


.fhk_require_numeric <- function(d, cols) {
  for (nm in unique(cols)) {
    x <- d[[nm]]
    if (is.factor(x) || !is.numeric(x)) {
      stop(
        "Column '", nm, "' must be genuinely numeric. Its class is: ",
        paste(class(x), collapse = "/"),
        ". Convert it explicitly and verify the values before decomposition; ",
        "as.numeric(factor) is not safe.",
        call. = FALSE
      )
    }
  }
}


.fhk_clean_required <- function(
    d,
    required_cols,
    numeric_cols,
    na_action = c("error", "drop"),
    context = "analysis data") {

  na_action <- match.arg(na_action)
  required_cols <- unique(required_cols)
  .fhk_assert_columns(d, required_cols)
  .fhk_require_numeric(d, numeric_cols)

  bad <- !stats::complete.cases(d[, required_cols, drop = FALSE])
  for (nm in required_cols) {
    if (is.numeric(d[[nm]])) bad <- bad | !is.finite(d[[nm]])
  }

  if (any(bad)) {
    nbad <- sum(bad)
    msg <- sprintf(
      "%d rows in %s contain missing or non-finite required values.",
      nbad, context
    )
    if (na_action == "error") stop(msg, call. = FALSE)
    warning(
      paste0(msg, " They were dropped. This can change weights and turnover classification."),
      call. = FALSE
    )
    d <- d[!bad, , drop = FALSE]
  }

  d
}


.fhk_check_ids <- function(d, firm_col) {
  id_chr <- trimws(as.character(d[[firm_col]]))
  if (any(!nzchar(id_chr))) {
    stop("Firm/unit identifiers cannot be blank strings.", call. = FALSE)
  }
}


.fhk_assert_unique_unit_period <- function(d, firm_col, time_col) {
  key_df <- d[, c(firm_col, time_col), drop = FALSE]
  dup <- duplicated(key_df) | duplicated(key_df, fromLast = TRUE)
  if (any(dup)) {
    ex <- unique(paste(
      as.character(d[[firm_col]][dup]),
      as.character(d[[time_col]][dup]),
      sep = " @ "
    ))
    stop(
      "Duplicate firm/unit-period observations detected before grouping. ",
      "Each analytical unit must occur at most once per period, including across groups. ",
      "Use a plant ID or a validated composite ID if a firm legitimately has multiple units. ",
      "Examples: ", paste(utils::head(ex, 5L), collapse = ", "),
      call. = FALSE
    )
  }
}


.fhk_apply_zero_weight_action <- function(
    d,
    weight_col,
    zero_weight_action = c("keep", "drop", "error")) {

  zero_weight_action <- match.arg(zero_weight_action)
  is_zero <- d[[weight_col]] == 0
  if (!any(is_zero)) return(d)

  nzero <- sum(is_zero)
  if (zero_weight_action == "error") {
    stop(nzero, " rows have zero weights.", call. = FALSE)
  }
  if (zero_weight_action == "drop") {
    warning(
      "Dropping ", nzero, " zero-weight rows. This can alter sample turnover classification.",
      call. = FALSE
    )
    return(d[!is_zero, , drop = FALSE])
  }
  d
}


.fhk_validate_activity_columns <- function(
    d,
    first_active_col = NULL,
    last_active_col = NULL) {

  if (!is.null(first_active_col) && !is.null(last_active_col)) {
    bad <- .fhk_compare(
      d[[first_active_col]], ">", d[[last_active_col]],
      paste0("Activity columns '", first_active_col, "' and '", last_active_col, "'")
    )
    if (any(bad)) {
      stop(
        sum(bad), " rows have first_active later than last_active.",
        call. = FALSE
      )
    }
  }
  invisible(TRUE)
}


.fhk_validate_group_changes <- function(
    d,
    firm_col,
    time_col,
    group_cols,
    t0,
    t1,
    group_change_action = c("error", "warn", "allow")) {

  group_change_action <- match.arg(group_change_action)
  if (is.null(group_cols) || length(group_cols) == 0L) return(0L)

  d0 <- d[d[[time_col]] %in% t0, , drop = FALSE]
  d1 <- d[d[[time_col]] %in% t1, , drop = FALSE]
  ids <- intersect(d0[[firm_col]], d1[[firm_col]])
  if (length(ids) == 0L) return(0L)

  i0 <- match(ids, d0[[firm_col]])
  i1 <- match(ids, d1[[firm_col]])
  changed <- rep(FALSE, length(ids))
  for (nm in group_cols) {
    changed <- changed |
      (as.character(d0[[nm]][i0]) != as.character(d1[[nm]][i1]))
  }
  nchanged <- sum(changed)
  if (nchanged == 0L) return(0L)

  msg <- paste0(
    nchanged, " continuing units change group between endpoints. ",
    "A within-group decomposition will treat each mover as an exit from the old group ",
    "and an entry into the new group. Harmonize industry codes or choose an explicit policy."
  )
  if (group_change_action == "error") stop(msg, call. = FALSE)
  if (group_change_action == "warn") warning(msg, call. = FALSE)
  nchanged
}


.fhk_validate_turnover <- function(
    d0,
    d1,
    firm_col,
    t0,
    t1,
    continuers,
    entrants,
    exiters,
    first_active_col = NULL,
    last_active_col = NULL,
    turnover_validation = c("error", "warn", "none")) {

  turnover_validation <- match.arg(turnover_validation)
  if (is.null(first_active_col) && is.null(last_active_col)) {
    return(list(
      basis = "sample_presence",
      validated = FALSE,
      n_mismatches = NA_integer_
    ))
  }

  mismatch_messages <- character()
  mismatch_n <- 0L

  if (!is.null(first_active_col)) {
    if (length(entrants) > 0L) {
      i1 <- match(entrants, d1[[firm_col]])
      first <- d1[[first_active_col]][i1]
      ok <- .fhk_compare(first, ">", t0, first_active_col) &
        .fhk_compare(first, "<=", t1, first_active_col)
      if (any(!ok)) {
        mismatch_n <- mismatch_n + sum(!ok)
        mismatch_messages <- c(
          mismatch_messages,
          paste0(sum(!ok), " sample entrants have first_active outside (t0, t1].")
        )
      }
    }
    if (length(continuers) > 0L) {
      i0 <- match(continuers, d0[[firm_col]])
      first <- d0[[first_active_col]][i0]
      ok <- .fhk_compare(first, "<=", t0, first_active_col)
      if (any(!ok)) {
        mismatch_n <- mismatch_n + sum(!ok)
        mismatch_messages <- c(
          mismatch_messages,
          paste0(sum(!ok), " continuers have first_active later than t0.")
        )
      }
    }
  }

  if (!is.null(last_active_col)) {
    if (length(exiters) > 0L) {
      i0 <- match(exiters, d0[[firm_col]])
      last <- d0[[last_active_col]][i0]
      ok <- .fhk_compare(last, ">=", t0, last_active_col) &
        .fhk_compare(last, "<", t1, last_active_col)
      if (any(!ok)) {
        mismatch_n <- mismatch_n + sum(!ok)
        mismatch_messages <- c(
          mismatch_messages,
          paste0(sum(!ok), " sample exiters have last_active outside [t0, t1).")
        )
      }
    }
    if (length(continuers) > 0L) {
      i1 <- match(continuers, d1[[firm_col]])
      last <- d1[[last_active_col]][i1]
      ok <- .fhk_compare(last, ">=", t1, last_active_col)
      if (any(!ok)) {
        mismatch_n <- mismatch_n + sum(!ok)
        mismatch_messages <- c(
          mismatch_messages,
          paste0(sum(!ok), " continuers have last_active earlier than t1.")
        )
      }
    }
  }

  if (mismatch_n > 0L && turnover_validation != "none") {
    msg <- paste(
      "Sample-presence turnover conflicts with activity-window information:",
      paste(mismatch_messages, collapse = " ")
    )
    if (turnover_validation == "error") stop(msg, call. = FALSE)
    warning(msg, call. = FALSE)
  }

  list(
    basis = "sample_presence_validated_by_activity_window",
    validated = mismatch_n == 0L,
    n_mismatches = mismatch_n
  )
}


.fhk_audit_turnover_from_data <- function(
    d,
    firm_col,
    time_col,
    t0,
    t1,
    first_active_col,
    last_active_col,
    turnover_validation) {

  d0 <- d[d[[time_col]] %in% t0, , drop = FALSE]
  d1 <- d[d[[time_col]] %in% t1, , drop = FALSE]
  id0 <- d0[[firm_col]]
  id1 <- d1[[firm_col]]
  .fhk_validate_turnover(
    d0, d1, firm_col, t0, t1,
    continuers = intersect(id0, id1),
    entrants = setdiff(id1, id0),
    exiters = setdiff(id0, id1),
    first_active_col = first_active_col,
    last_active_col = last_active_col,
    turnover_validation = turnover_validation
  )
}


.fhk_make_shares <- function(
    w0,
    w1,
    weight_is_share,
    share_sum_expected_one,
    renormalize_input_shares,
    tol) {

  total0 <- sum(w0)
  total1 <- sum(w1)
  if (total0 <= 0 || total1 <= 0) {
    stop("Weights must have strictly positive totals in both periods.", call. = FALSE)
  }

  renorm0 <- FALSE
  renorm1 <- FALSE
  if (weight_is_share && share_sum_expected_one) {
    bad0 <- abs(total0 - 1) > tol * max(1, abs(total0))
    bad1 <- abs(total1 - 1) > tol * max(1, abs(total1))
    if (bad0 || bad1) {
      msg <- sprintf(
        "Input shares do not sum to one: sum(t0)=%.12g, sum(t1)=%.12g.",
        total0, total1
      )
      if (!renormalize_input_shares) stop(msg, call. = FALSE)
      warning(paste0(msg, " They were explicitly renormalized."), call. = FALSE)
      renorm0 <- bad0
      renorm1 <- bad1
    }
  }

  # Raw weights and global shares must be normalized inside the current
  # analysis unit. Shares already summing to one are normalized again only to
  # remove harmless floating-point drift.
  list(
    s0 = w0 / total0,
    s1 = w1 / total1,
    weight_total_t0 = total0,
    weight_total_t1 = total1,
    input_share_sum_t0 = if (weight_is_share) total0 else NA_real_,
    input_share_sum_t1 = if (weight_is_share) total1 else NA_real_,
    renormalized_t0 = renorm0,
    renormalized_t1 = renorm1
  )
}


.fhk_two_period_core <- function(
    d,
    firm_col,
    time_col,
    prod_col,
    weight_col,
    t0,
    t1,
    weight_is_share,
    share_sum_expected_one,
    renormalize_input_shares,
    first_active_col,
    last_active_col,
    turnover_validation,
    tol,
    fail_on_identity_error) {

  d0 <- d[d[[time_col]] %in% t0, , drop = FALSE]
  d1 <- d[d[[time_col]] %in% t1, , drop = FALSE]
  if (nrow(d0) == 0L || nrow(d1) == 0L) {
    stop("Both t0 and t1 must contain observations in the analysis unit.", call. = FALSE)
  }

  w0 <- d0[[weight_col]]
  w1 <- d1[[weight_col]]
  shares <- .fhk_make_shares(
    w0, w1,
    weight_is_share = weight_is_share,
    share_sum_expected_one = share_sum_expected_one,
    renormalize_input_shares = renormalize_input_shares,
    tol = tol
  )

  p0_all <- d0[[prod_col]]
  p1_all <- d1[[prod_col]]
  s0_all <- shares$s0
  s1_all <- shares$s1
  P0 <- sum(s0_all * p0_all)
  P1 <- sum(s1_all * p1_all)

  id0 <- d0[[firm_col]]
  id1 <- d1[[firm_col]]
  continuers <- intersect(id0, id1)
  entrants <- setdiff(id1, id0)
  exiters <- setdiff(id0, id1)

  turnover_audit <- .fhk_validate_turnover(
    d0, d1, firm_col, t0, t1,
    continuers, entrants, exiters,
    first_active_col = first_active_col,
    last_active_col = last_active_col,
    turnover_validation = turnover_validation
  )

  within <- between <- cross <- entry <- exit <- 0
  if (length(continuers) > 0L) {
    i0 <- match(continuers, id0)
    i1 <- match(continuers, id1)
    s0 <- s0_all[i0]
    s1 <- s1_all[i1]
    p0 <- p0_all[i0]
    p1 <- p1_all[i1]
    dp <- p1 - p0
    ds <- s1 - s0
    within <- sum(s0 * dp)
    between <- sum(ds * (p0 - P0))
    cross <- sum(ds * dp)
  }

  if (length(entrants) > 0L) {
    i1 <- match(entrants, id1)
    entry <- sum(s1_all[i1] * (p1_all[i1] - P0))
  }
  if (length(exiters) > 0L) {
    i0 <- match(exiters, id0)
    exit <- -sum(s0_all[i0] * (p0_all[i0] - P0))
  }

  delta <- P1 - P0
  component_sum <- within + between + cross + entry + exit
  residual <- delta - component_sum
  audit_scale <- max(1, abs(delta), abs(component_sum), abs(P0), abs(P1))
  identity_ok <- abs(residual) <= tol * audit_scale
  if (fail_on_identity_error && !identity_ok) {
    stop(
      sprintf(
        "FHK identity failed: residual=%g exceeds scaled tolerance=%g.",
        residual, tol * audit_scale
      ),
      call. = FALSE
    )
  }

  if (abs(delta) > tol * audit_scale) {
    within_pct <- 100 * within / delta
    between_pct <- 100 * between / delta
    cross_pct <- 100 * cross / delta
    entry_pct <- 100 * entry / delta
    exit_pct <- 100 * exit / delta
  } else {
    within_pct <- between_pct <- cross_pct <- entry_pct <- exit_pct <- NA_real_
  }

  data.frame(
    period_start = t0,
    period_end = t1,
    P0 = P0,
    P1 = P1,
    aggregate_change = delta,
    within = within,
    between = between,
    cross = cross,
    entry = entry,
    exit = exit,
    component_sum = component_sum,
    residual = residual,
    identity_ok = identity_ok,
    within_pct = within_pct,
    between_pct = between_pct,
    cross_pct = cross_pct,
    entry_pct = entry_pct,
    exit_pct = exit_pct,
    n_t0 = nrow(d0),
    n_t1 = nrow(d1),
    n_continuers = length(continuers),
    n_entrants = length(entrants),
    n_exiters = length(exiters),
    n_zero_weight_t0 = sum(w0 == 0),
    n_zero_weight_t1 = sum(w1 == 0),
    share_continuers_t0 = if (length(continuers)) sum(s0_all[match(continuers, id0)]) else 0,
    share_continuers_t1 = if (length(continuers)) sum(s1_all[match(continuers, id1)]) else 0,
    share_entrants_t1 = if (length(entrants)) sum(s1_all[match(entrants, id1)]) else 0,
    share_exiters_t0 = if (length(exiters)) sum(s0_all[match(exiters, id0)]) else 0,
    weight_total_t0 = shares$weight_total_t0,
    weight_total_t1 = shares$weight_total_t1,
    input_share_sum_t0 = shares$input_share_sum_t0,
    input_share_sum_t1 = shares$input_share_sum_t1,
    renormalized_t0 = shares$renormalized_t0,
    renormalized_t1 = shares$renormalized_t1,
    turnover_basis = turnover_audit$basis,
    turnover_validated = turnover_audit$validated,
    n_turnover_mismatches = turnover_audit$n_mismatches,
    stringsAsFactors = FALSE
  )
}


.fhk_prepare_pair_data <- function(
    df,
    firm_col,
    time_col,
    prod_cols,
    weight_col,
    t0,
    t1,
    group_cols,
    first_active_col,
    last_active_col,
    na_action,
    zero_weight_action,
    require_t1_after_t0) {

  if (length(t0) != 1L || length(t1) != 1L || is.na(t0) || is.na(t1)) {
    stop("t0 and t1 must each be one non-missing period.", call. = FALSE)
  }
  if (.fhk_same_period(t0, t1)) {
    stop("t0 and t1 must be distinct periods by value.", call. = FALSE)
  }
  if (require_t1_after_t0 && !.fhk_is_after(t1, t0)) {
    stop(
      "t1 must be later than t0. Use ordered numeric, Date, POSIXct, or sortable character periods.",
      call. = FALSE
    )
  }

  required <- unique(c(
    firm_col, time_col, prod_cols, weight_col, group_cols,
    first_active_col, last_active_col
  ))
  required <- required[!is.na(required) & nzchar(required)]
  .fhk_assert_columns(df, required)

  if (is.factor(df[[time_col]])) {
    stop(
      "Factor time columns have ambiguous values and ordering. Convert time explicitly first.",
      call. = FALSE
    )
  }
  if (!is.atomic(df[[firm_col]]) || !is.atomic(df[[time_col]])) {
    stop("firm_col and time_col must be atomic vectors, not list columns.", call. = FALSE)
  }

  d <- df[df[[time_col]] %in% c(t0, t1), , drop = FALSE]
  if (nrow(d) == 0L) stop("No observations found for t0 or t1.", call. = FALSE)
  d <- .fhk_clean_required(
    d,
    required_cols = required,
    numeric_cols = unique(c(prod_cols, weight_col)),
    na_action = na_action,
    context = "the requested endpoint sample"
  )
  .fhk_check_ids(d, firm_col)

  if (any(d[[weight_col]] < 0)) {
    stop("Weights/shares must be non-negative.", call. = FALSE)
  }
  d <- .fhk_apply_zero_weight_action(d, weight_col, zero_weight_action)
  if (nrow(d) == 0L) stop("No observations remain after weight checks.", call. = FALSE)

  .fhk_assert_unique_unit_period(d, firm_col, time_col)
  .fhk_validate_activity_columns(d, first_active_col, last_active_col)

  if (!any(d[[time_col]] %in% t0) || !any(d[[time_col]] %in% t1)) {
    stop("Both t0 and t1 must contain observations after validation.", call. = FALSE)
  }
  d
}


.fhk_incomplete_groups <- function(d, group_cols, time_col, t0, t1) {
  key <- interaction(d[group_cols], drop = TRUE, lex.order = TRUE)
  pieces <- split(d, key, drop = TRUE)
  rows <- lapply(pieces, function(g) {
    z <- as.list(g[1L, group_cols, drop = FALSE])
    z$present_t0 <- any(g[[time_col]] %in% t0)
    z$present_t1 <- any(g[[time_col]] %in% t1)
    z$n_rows <- nrow(g)
    as.data.frame(z, stringsAsFactors = FALSE)
  })
  info <- do.call(rbind, rows)
  rownames(info) <- NULL
  info[!(info$present_t0 & info$present_t1), , drop = FALSE]
}


#' Robust two-period FHK decomposition, optionally within groups.
#'
#' @param df data.frame containing one row per analytical unit and period.
#' @param firm_col unit identifier. Use a plant ID or validated composite ID if
#'   firms can have multiple establishments/products in one period.
#' @param time_col ordered period column.
#' @param prod_col genuinely numeric productivity/outcome column.
#' @param weight_col genuinely numeric raw size or share column.
#' @param t0,t1 endpoint periods; t1 must be later by default.
#' @param group_cols optional industry/market columns.
#' @param weight_is_share FALSE for raw employment/sales/output; TRUE for shares.
#' @param share_scope "within_group" if supplied shares sum to one inside every
#'   group-period; "global" if they sum to one across all groups in a period.
#' @param renormalize_input_shares if TRUE, non-unit within-analysis shares are
#'   renormalized with an explicit warning. FALSE is safer for main results.
#' @param first_active_col,last_active_col optional registry-derived first/last
#'   activity periods used to validate sample entry and exit.
#' @param turnover_validation action when presence turnover conflicts with the
#'   supplied activity window.
#' @param group_change_action action when a continuing unit changes group.
#' @param incomplete_group_action action for groups absent at one endpoint.
#' @param zero_weight_action keep, drop with warning, or reject zero weights.
#' @param na_action reject or explicitly drop invalid required rows.
#' @param require_t1_after_t0 require forward-time decomposition.
#' @param tol scaled accounting and share-sum tolerance.
#' @param fail_on_identity_error stop when the accounting identity fails.
#'
#' @return data.frame. For grouped results, skipped groups are stored in the
#'   "skipped_groups" attribute, and group shares are reported when raw weights
#'   or global shares make them identifiable.
fhk_decomposition <- function(
    df,
    firm_col,
    time_col,
    prod_col,
    weight_col,
    t0,
    t1,
    group_cols = NULL,
    weight_is_share = FALSE,
    share_scope = c("within_group", "global"),
    renormalize_input_shares = FALSE,
    first_active_col = NULL,
    last_active_col = NULL,
    turnover_validation = c("error", "warn", "none"),
    group_change_action = c("error", "warn", "allow"),
    incomplete_group_action = c("error", "warn", "drop"),
    zero_weight_action = c("keep", "drop", "error"),
    na_action = c("error", "drop"),
    require_t1_after_t0 = TRUE,
    tol = 1e-10,
    fail_on_identity_error = TRUE) {

  .fhk_validate_interface(
    df, firm_col, time_col, prod_col, weight_col, group_cols,
    first_active_col, last_active_col, weight_is_share,
    renormalize_input_shares, require_t1_after_t0,
    fail_on_identity_error, tol
  )

  share_scope <- match.arg(share_scope)
  turnover_validation <- match.arg(turnover_validation)
  group_change_action <- match.arg(group_change_action)
  incomplete_group_action <- match.arg(incomplete_group_action)
  zero_weight_action <- match.arg(zero_weight_action)
  na_action <- match.arg(na_action)

  d <- .fhk_prepare_pair_data(
    df, firm_col, time_col, prod_col, weight_col, t0, t1,
    group_cols, first_active_col, last_active_col,
    na_action, zero_weight_action, require_t1_after_t0
  )

  n_group_movers <- .fhk_validate_group_changes(
    d, firm_col, time_col, group_cols, t0, t1, group_change_action
  )

  if (is.null(group_cols) || length(group_cols) == 0L) {
    ans <- .fhk_two_period_core(
      d, firm_col, time_col, prod_col, weight_col, t0, t1,
      weight_is_share = weight_is_share,
      share_sum_expected_one = weight_is_share,
      renormalize_input_shares = renormalize_input_shares,
      first_active_col = first_active_col,
      last_active_col = last_active_col,
      turnover_validation = turnover_validation,
      tol = tol,
      fail_on_identity_error = fail_on_identity_error
    )
    ans$n_group_movers <- 0L
    class(ans) <- c("fhk_result", class(ans))
    return(ans)
  }

  # Firm activity windows validate firm birth/death globally. For grouped
  # decompositions, this audit must be separated from group membership changes:
  # an industry mover is an old-group exit/new-group entrant but is not a firm
  # death/birth.
  global_turnover_audit <- .fhk_audit_turnover_from_data(
    d, firm_col, time_col, t0, t1,
    first_active_col, last_active_col, turnover_validation
  )

  incomplete <- .fhk_incomplete_groups(d, group_cols, time_col, t0, t1)
  if (nrow(incomplete) > 0L) {
    msg <- paste0(
      nrow(incomplete), " groups are absent at one endpoint and cannot have a ",
      "within-group endpoint decomposition."
    )
    if (incomplete_group_action == "error") stop(msg, call. = FALSE)
    if (incomplete_group_action == "warn") warning(msg, call. = FALSE)
  }

  global_total0 <- sum(d[[weight_col]][d[[time_col]] %in% t0])
  global_total1 <- sum(d[[weight_col]][d[[time_col]] %in% t1])
  key <- interaction(d[group_cols], drop = TRUE, lex.order = TRUE)
  pieces <- split(d, key, drop = TRUE)

  out <- lapply(pieces, function(g) {
    if (!any(g[[time_col]] %in% t0) || !any(g[[time_col]] %in% t1)) return(NULL)
    res <- .fhk_two_period_core(
      g, firm_col, time_col, prod_col, weight_col, t0, t1,
      weight_is_share = weight_is_share,
      share_sum_expected_one = weight_is_share && share_scope == "within_group",
      renormalize_input_shares = renormalize_input_shares,
      first_active_col = NULL,
      last_active_col = NULL,
      turnover_validation = turnover_validation,
      tol = tol,
      fail_on_identity_error = fail_on_identity_error
    )
    if (n_group_movers > 0L) {
      res$turnover_basis <- "group_membership_presence_includes_movers"
      res$turnover_validated <- FALSE
      res$n_turnover_mismatches <- NA_integer_
    } else if (!is.null(first_active_col) || !is.null(last_active_col)) {
      res$turnover_basis <- "group_presence_validated_by_global_firm_activity_window"
      res$turnover_validated <- global_turnover_audit$validated
      res$n_turnover_mismatches <- global_turnover_audit$n_mismatches
    }
    res$global_firm_turnover_basis <- global_turnover_audit$basis
    res$global_firm_turnover_validated <- global_turnover_audit$validated
    res$n_global_firm_turnover_mismatches <- global_turnover_audit$n_mismatches
    for (nm in group_cols) res[[nm]] <- g[[nm]][1L]

    if (!weight_is_share || share_scope == "global") {
      res$group_weight_t0 <- res$weight_total_t0 / global_total0
      res$group_weight_t1 <- res$weight_total_t1 / global_total1
    } else {
      res$group_weight_t0 <- NA_real_
      res$group_weight_t1 <- NA_real_
    }
    res$n_group_movers <- n_group_movers
    res
  })

  out <- Filter(Negate(is.null), out)
  if (length(out) == 0L) {
    stop("No group contains observations at both endpoints.", call. = FALSE)
  }
  ans <- do.call(rbind, out)
  ans <- ans[, c(group_cols, setdiff(names(ans), group_cols)), drop = FALSE]
  rownames(ans) <- NULL
  attr(ans, "skipped_groups") <- incomplete
  attr(ans, "group_weight_note") <- if (!weight_is_share || share_scope == "global") {
    "group_weight_t0/t1 are identified from raw weights or global shares."
  } else {
    "Group weights are not identified from within-group shares; use raw weights or global shares for hierarchical aggregation."
  }
  class(ans) <- c("fhk_grouped_result", "fhk_result", class(ans))
  ans
}


#' Economy-wide and within-group FHK results from the same validated sample.
#'
#' This function does not add group components. It returns an exact overall
#' firm-level decomposition plus separate within-group decompositions and group
#' endpoint weights. Raw weights or globally defined shares are required.
fhk_hierarchical <- function(
    df,
    firm_col,
    time_col,
    prod_col,
    weight_col,
    t0,
    t1,
    group_cols,
    weight_is_share = FALSE,
    share_scope = c("global", "within_group"),
    ...) {

  share_scope <- match.arg(share_scope)
  if (missing(group_cols) || is.null(group_cols) || length(group_cols) == 0L) {
    stop("group_cols is required for fhk_hierarchical().", call. = FALSE)
  }
  if (weight_is_share && share_scope == "within_group") {
    stop(
      "Economy-wide weights cannot be recovered from within-group shares. ",
      "Supply raw weights or shares that sum to one globally.",
      call. = FALSE
    )
  }

  overall <- fhk_decomposition(
    df, firm_col, time_col, prod_col, weight_col, t0, t1,
    group_cols = NULL,
    weight_is_share = weight_is_share,
    share_scope = "global",
    ...
  )
  by_group <- fhk_decomposition(
    df, firm_col, time_col, prod_col, weight_col, t0, t1,
    group_cols = group_cols,
    weight_is_share = weight_is_share,
    share_scope = share_scope,
    ...
  )

  out <- list(
    overall = overall,
    by_group = by_group,
    skipped_groups = attr(by_group, "skipped_groups")
  )
  class(out) <- "fhk_hierarchical_result"
  out
}


.fhk_step_matches <- function(periods, expected_step) {
  if (length(periods) < 2L) return(TRUE)
  diffs <- tryCatch(diff(periods), error = function(e) NULL)
  if (is.null(diffs)) {
    stop("Periods cannot be differenced; omit expected_step or use an ordered time type.", call. = FALSE)
  }
  if (inherits(diffs, "difftime")) {
    target <- if (inherits(expected_step, "difftime")) expected_step else {
      as.difftime(expected_step, units = attr(diffs, "units"))
    }
    return(all(as.numeric(diffs) == as.numeric(target)))
  }
  all(as.numeric(diffs) == as.numeric(expected_step))
}


#' FHK decompositions over adjacent observed periods.
#'
#' Period pairs are global by default, so industries are compared over the same
#' endpoints. expected_step can enforce true annual/quarterly adjacency.
fhk_adjacent <- function(
    df,
    firm_col,
    time_col,
    prod_col,
    weight_col,
    group_cols = NULL,
    weight_is_share = FALSE,
    renormalize_input_shares = FALSE,
    na_action = c("error", "drop"),
    tol = 1e-10,
    fail_on_identity_error = TRUE,
    expected_step = NULL,
    ...) {

  na_action <- match.arg(na_action)
  .fhk_assert_columns(df, unique(c(
    firm_col, time_col, prod_col, weight_col, group_cols
  )))
  if (is.factor(df[[time_col]])) {
    stop(
      "Factor time columns have ambiguous ordering. Convert time explicitly before fhk_adjacent().",
      call. = FALSE
    )
  }
  if (anyNA(df[[time_col]])) {
    stop("time_col contains missing values.", call. = FALSE)
  }
  periods <- sort(unique(df[[time_col]]))
  if (length(periods) < 2L) stop("Need at least two periods.", call. = FALSE)
  if (!is.null(expected_step) && !.fhk_step_matches(periods, expected_step)) {
    stop(
      "Observed periods do not all match expected_step. Use explicit endpoint pairs or correct time gaps.",
      call. = FALSE
    )
  }

  rows <- vector("list", length(periods) - 1L)
  skipped <- vector("list", length(periods) - 1L)
  for (k in seq_len(length(periods) - 1L)) {
    rows[[k]] <- fhk_decomposition(
      df, firm_col, time_col, prod_col, weight_col,
      t0 = periods[k], t1 = periods[k + 1L],
      group_cols = group_cols,
      weight_is_share = weight_is_share,
      renormalize_input_shares = renormalize_input_shares,
      na_action = na_action,
      tol = tol,
      fail_on_identity_error = fail_on_identity_error,
      ...
    )
    skipped[[k]] <- attr(rows[[k]], "skipped_groups")
  }
  ans <- do.call(rbind, rows)
  rownames(ans) <- NULL
  attr(ans, "skipped_groups_by_pair") <- skipped
  class(ans) <- unique(c("fhk_adjacent_result", class(ans)))
  ans
}


#' Apply the same FHK design to multiple outcomes.
#'
#' With common_sample=TRUE and na_action="drop", rows invalid for any requested
#' outcome are removed once so that measures remain comparable.
fhk_multi_measure <- function(
    df,
    firm_col,
    time_col,
    prod_cols,
    weight_col,
    t0,
    t1,
    group_cols = NULL,
    weight_is_share = FALSE,
    renormalize_input_shares = FALSE,
    na_action = c("error", "drop"),
    tol = 1e-10,
    fail_on_identity_error = TRUE,
    common_sample = TRUE,
    ...) {

  na_action <- match.arg(na_action)
  .fhk_assert_flag(common_sample, "common_sample")
  if (!is.character(prod_cols) || length(prod_cols) == 0L ||
      anyNA(prod_cols) || any(!nzchar(prod_cols)) || anyDuplicated(prod_cols)) {
    stop("prod_cols must contain unique, non-empty column names.", call. = FALSE)
  }
  required <- unique(c(firm_col, time_col, prod_cols, weight_col, group_cols))
  .fhk_assert_columns(df, required)
  .fhk_require_numeric(df, c(prod_cols, weight_col))

  d <- df
  inner_na_action <- na_action
  if (common_sample && na_action == "drop") {
    d <- d[d[[time_col]] %in% c(t0, t1), , drop = FALSE]
    d <- .fhk_clean_required(
      d,
      required_cols = required,
      numeric_cols = c(prod_cols, weight_col),
      na_action = "drop",
      context = "the multi-measure common sample"
    )
    inner_na_action <- "error"
  }

  out <- lapply(prod_cols, function(pc) {
    res <- fhk_decomposition(
      d, firm_col, time_col, pc, weight_col, t0, t1,
      group_cols = group_cols,
      weight_is_share = weight_is_share,
      renormalize_input_shares = renormalize_input_shares,
      na_action = inner_na_action,
      tol = tol,
      fail_on_identity_error = fail_on_identity_error,
      ...
    )
    res$measure <- pc
    res
  })
  ans <- do.call(rbind, out)
  first <- c(group_cols, "measure")
  ans <- ans[, c(first, setdiff(names(ans), first)), drop = FALSE]
  rownames(ans) <- NULL
  attr(ans, "common_sample") <- common_sample
  class(ans) <- unique(c("fhk_multi_measure_result", class(ans)))
  ans
}


print.fhk_hierarchical_result <- function(x, ...) {
  cat("Economy-wide FHK decomposition:\n")
  print(x$overall, ...)
  cat("\nWithin-group FHK decompositions:\n")
  print(x$by_group, ...)
  if (!is.null(x$skipped_groups) && nrow(x$skipped_groups) > 0L) {
    cat("\nSkipped groups are available in $skipped_groups.\n")
  }
  invisible(x)
}


# ============================================================================
# Examples (not executed automatically)
# ============================================================================
if (FALSE) {
  # Complete administrative panel, raw employment weights, industry results.
  by_industry <- fhk_decomposition(
    mydata,
    firm_col = "firm_id",
    time_col = "year",
    prod_col = "tfp",
    weight_col = "employment",
    t0 = 2010,
    t1 = 2015,
    group_cols = "harmonized_industry",
    weight_is_share = FALSE,
    group_change_action = "error",
    incomplete_group_action = "error"
  )

  # Survey sample validated against registry first/last activity dates.
  registry_validated <- fhk_decomposition(
    mydata,
    firm_col = "firm_id",
    time_col = "year",
    prod_col = "tfp",
    weight_col = "output",
    t0 = 2010,
    t1 = 2015,
    first_active_col = "first_active_year",
    last_active_col = "last_active_year",
    turnover_validation = "error"
  )

  # Exact economy-wide result plus industry-level diagnostics.
  both_levels <- fhk_hierarchical(
    mydata,
    firm_col = "firm_id",
    time_col = "year",
    prod_col = "tfp",
    weight_col = "output",
    t0 = 2010,
    t1 = 2015,
    group_cols = "harmonized_industry",
    incomplete_group_action = "warn"
  )

  # Enforce truly annual rather than merely adjacent-observed periods.
  annual <- fhk_adjacent(
    mydata,
    firm_col = "firm_id",
    time_col = "year",
    prod_col = "tfp",
    weight_col = "output",
    group_cols = "harmonized_industry",
    expected_step = 1,
    incomplete_group_action = "warn"
  )
}


# ============================================================================
# Built-in validation suite
# ============================================================================
.fhk_expect_error <- function(expr) {
  inherits(try(force(expr), silent = TRUE), "try-error")
}


fhk_run_tests <- function(seed = 20260901L, verbose = TRUE) {
  tests <- logical()

  toy <- data.frame(
    firm = c("A", "B", "C", "B", "C", "D"),
    year = c(2010, 2010, 2010, 2014, 2014, 2014),
    productivity = c(5.0, 4.0, 3.0, 4.5, 6.0, 5.5),
    share = c(0.5, 0.3, 0.2, 0.4, 0.15, 0.45)
  )
  z <- fhk_decomposition(
    toy, "firm", "year", "productivity", "share", 2010, 2014,
    weight_is_share = TRUE
  )
  tests["canonical_identity"] <- isTRUE(z$identity_ok) &&
    abs(z$aggregate_change - 0.875) < 1e-12 &&
    abs(z$within - 0.75) < 1e-12 &&
    abs(z$between - 0.035) < 1e-12 &&
    abs(z$cross + 0.10) < 1e-12 &&
    abs(z$entry - 0.54) < 1e-12 &&
    abs(z$exit + 0.35) < 1e-12

  raw <- toy
  raw$size <- raw$share * ifelse(raw$year == 2010, 1000, 1700)
  zr <- fhk_decomposition(raw, "firm", "year", "productivity", "size", 2010, 2014)
  tests["raw_share_equivalence"] <- max(abs(
    unlist(zr[c("aggregate_change", "within", "between", "cross", "entry", "exit")]) -
      unlist(z[c("aggregate_change", "within", "between", "cross", "entry", "exit")])
  )) < 1e-12

  bad_factor <- raw
  bad_factor$size <- factor(bad_factor$size)
  tests["factor_numeric_rejected"] <- .fhk_expect_error(
    fhk_decomposition(bad_factor, "firm", "year", "productivity", "size", 2010, 2014)
  )
  tests["same_period_rejected"] <- .fhk_expect_error(
    fhk_decomposition(raw, "firm", "year", "productivity", "size", 2010, 2010L)
  )

  x <- data.frame(
    firm = rep(c("A", "B"), 2),
    year = rep(c(2010, 2011), each = 2),
    p = c(1, 2, 1.2, 2.3),
    w = c(1, 2, 1.2, 2.2)
  )
  xdup <- rbind(transform(x, industry = "X"), transform(x, industry = "Y"))
  tests["cross_group_duplicate_rejected"] <- .fhk_expect_error(
    fhk_decomposition(xdup, "firm", "year", "p", "w", 2010, 2011, group_cols = "industry")
  )

  xna <- transform(x, industry = c("X", "X", "X", NA_character_))
  tests["missing_group_rejected"] <- .fhk_expect_error(
    fhk_decomposition(xna, "firm", "year", "p", "w", 2010, 2011, group_cols = "industry")
  )

  mover <- data.frame(
    firm = c("A", "B", "A", "B"),
    year = c(2010, 2010, 2011, 2011),
    industry = c("X", "Y", "Y", "Y"),
    p = c(1, 2, 1.2, 2.2),
    w = c(1, 1, 1, 1)
  )
  tests["group_mover_rejected"] <- .fhk_expect_error(
    fhk_decomposition(
      mover, "firm", "year", "p", "w", 2010, 2011,
      group_cols = "industry", incomplete_group_action = "drop"
    )
  )

  activity <- data.frame(
    firm = c("A", "B", "B", "C"),
    year = c(2010, 2010, 2011, 2011),
    p = c(1, 2, 2.2, 1.5),
    w = c(1, 2, 2, 1),
    first = c(2000, 2000, 2000, 2011),
    last = c(2010, 2020, 2020, 2020)
  )
  za <- fhk_decomposition(
    activity, "firm", "year", "p", "w", 2010, 2011,
    first_active_col = "first", last_active_col = "last"
  )
  tests["activity_window_validated"] <- isTRUE(za$turnover_validated)
  activity_bad <- activity
  activity_bad$last[activity_bad$firm == "A"] <- 2015
  tests["activity_mismatch_rejected"] <- .fhk_expect_error(
    fhk_decomposition(
      activity_bad, "firm", "year", "p", "w", 2010, 2011,
      first_active_col = "first", last_active_col = "last"
    )
  )

  grouped <- data.frame(
    firm = c("A", "B", "C", "D", "A", "B", "C", "D"),
    year = rep(c(2010, 2011), each = 4),
    industry = rep(c("X", "X", "Y", "Y"), 2),
    p = c(1, 2, 3, 4, 1.2, 2.1, 3.3, 3.8),
    w = c(10, 20, 30, 40, 12, 18, 35, 35)
  )
  bg_raw <- fhk_decomposition(
    grouped, "firm", "year", "p", "w", 2010, 2011,
    group_cols = "industry"
  )
  grouped$global_share <- ave(
    grouped$w, grouped$year,
    FUN = function(v) v / sum(v)
  )
  bg_share <- fhk_decomposition(
    grouped, "firm", "year", "p", "global_share", 2010, 2011,
    group_cols = "industry", weight_is_share = TRUE, share_scope = "global"
  )
  cmp_cols <- c("aggregate_change", "within", "between", "cross", "entry", "exit")
  tests["global_share_scope"] <- max(abs(
    as.matrix(bg_raw[cmp_cols]) - as.matrix(bg_share[cmp_cols])
  )) < 1e-12

  h <- fhk_hierarchical(
    grouped, "firm", "year", "p", "w", 2010, 2011,
    group_cols = "industry"
  )
  direct <- fhk_decomposition(grouped, "firm", "year", "p", "w", 2010, 2011)
  tests["hierarchical_overall_exact"] <- max(abs(
    unlist(h$overall[cmp_cols]) - unlist(direct[cmp_cols])
  )) < 1e-12

  set.seed(seed)
  firms <- paste0("F", seq_len(120))
  ind_map <- setNames(sample(c("I1", "I2", "I3"), length(firms), TRUE), firms)
  years <- 2001:2008
  panel <- do.call(rbind, lapply(years, function(yr) {
    ids <- sample(firms, sample(90:115, 1))
    data.frame(
      firm = ids,
      year = yr,
      industry = unname(ind_map[ids]),
      p = rnorm(length(ids), 4, 0.7),
      w = rexp(length(ids)) + 0.01,
      stringsAsFactors = FALSE
    )
  }))
  mc <- fhk_adjacent(
    panel, "firm", "year", "p", "w",
    group_cols = "industry",
    expected_step = 1,
    incomplete_group_action = "drop"
  )
  tests["monte_carlo_grouped_identity"] <- all(mc$identity_ok) &&
    max(abs(mc$residual)) < 1e-10

  result <- data.frame(
    test = names(tests),
    passed = unname(tests),
    row.names = NULL,
    stringsAsFactors = FALSE
  )
  if (verbose) print(result, row.names = FALSE)
  if (!all(tests)) {
    stop("FHK validation suite failed: ", paste(names(tests)[!tests], collapse = ", "), call. = FALSE)
  }
  invisible(result)
}


# Run manually after sourcing:
#   fhk_run_tests()
