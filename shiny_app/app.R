pkg <- c(
  "shiny",
  "bslib",
  "readxl",
  "dplyr",
  "stringr",
  "purrr",
  "DT",
  "tibble",
  "htmltools",
  "lubridate",
  "openxlsx"
)

missing_pkg <- pkg[!vapply(pkg, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_pkg) > 0) {
  install.packages(missing_pkg)
}

invisible(lapply(pkg, library, character.only = TRUE))

rm(list = ls())
gc()

app_dir <- getwd()

project_root <- if (basename(app_dir) == "shiny_app") {
  dirname(app_dir)
} else {
  app_dir
}

database_file <- file.path(
  project_root,
  "data",
  "database",
  "lab_processing_scheduler_database.xlsx"
)

logo_dir <- file.path(
  project_root,
  "docs",
  "assets",
  "img"
)

if (dir.exists(logo_dir)) {
  shiny::addResourcePath("site-assets", logo_dir)
}

read_sheet_clean <- function(sheet_name) {
  readxl::read_excel(
    path = database_file,
    sheet = sheet_name,
    col_types = "text"
  ) %>%
    dplyr::rename_with(stringr::str_trim) %>%
    dplyr::mutate(
      dplyr::across(
        dplyr::everything(),
        ~ ifelse(is.na(.x), NA_character_, stringr::str_trim(as.character(.x)))
      )
    )
}

read_database <- function() {
  sheet_names <- c(
    "users",
    "computers",
    "reservations",
    "lists",
    "priority_rules",
    "usage_log",
    "audit_log",
    "settings"
  )
  
  purrr::map(
    sheet_names,
    read_sheet_clean
  ) %>%
    stats::setNames(sheet_names)
}

write_sheet_to_workbook <- function(database_file, sheet_name, data_tbl) {
  wb <- openxlsx::loadWorkbook(database_file)
  
  if (sheet_name %in% openxlsx::sheets(wb)) {
    openxlsx::removeWorksheet(wb, sheet_name)
  }
  
  openxlsx::addWorksheet(wb, sheet_name)
  openxlsx::writeData(wb, sheet = sheet_name, x = data_tbl)
  openxlsx::saveWorkbook(wb, database_file, overwrite = TRUE)
}

align_tables_as_character <- function(reference_tbl, new_tbl) {
  reference_tbl <- reference_tbl %>%
    dplyr::mutate(
      dplyr::across(
        dplyr::everything(),
        ~ as.character(.x)
      )
    )
  
  new_tbl <- new_tbl %>%
    dplyr::mutate(
      dplyr::across(
        dplyr::everything(),
        ~ as.character(.x)
      )
    )
  
  missing_in_reference <- setdiff(names(new_tbl), names(reference_tbl))
  
  if (length(missing_in_reference) > 0) {
    for (col_name in missing_in_reference) {
      reference_tbl[[col_name]] <- NA_character_
    }
  }
  
  missing_in_new <- setdiff(names(reference_tbl), names(new_tbl))
  
  if (length(missing_in_new) > 0) {
    for (col_name in missing_in_new) {
      new_tbl[[col_name]] <- NA_character_
    }
  }
  
  new_tbl <- new_tbl %>%
    dplyr::select(dplyr::all_of(names(reference_tbl)))
  
  list(
    reference_tbl = reference_tbl,
    new_tbl = new_tbl
  )
}

get_active_users <- function(database) {
  database$users %>%
    dplyr::filter(status == "active") %>%
    dplyr::arrange(full_name)
}

get_active_computers <- function(database) {
  database$computers %>%
    dplyr::filter(status == "active", can_be_booked == "TRUE") %>%
    dplyr::arrange(computer_id)
}

get_active_lists <- function(database) {
  database$lists %>%
    dplyr::filter(active == "TRUE") %>%
    dplyr::arrange(list_name, as.numeric(sort_order))
}

get_active_settings <- function(database) {
  database$settings %>%
    dplyr::filter(active == "TRUE") %>%
    dplyr::arrange(setting_name)
}

get_setting_value <- function(settings_tbl, setting_name, default_value = NA_character_) {
  value <- settings_tbl %>%
    dplyr::filter(.data$setting_name == !!setting_name, active == "TRUE") %>%
    dplyr::pull(setting_value)
  
  if (length(value) == 0 || is.na(value[1])) {
    return(default_value)
  }
  
  value[1]
}

get_setting_logical <- function(settings_tbl, setting_name, default_value = FALSE) {
  value <- get_setting_value(settings_tbl, setting_name, as.character(default_value))
  identical(value, "TRUE")
}

get_setting_numeric <- function(settings_tbl, setting_name, default_value = NA_real_) {
  value <- get_setting_value(settings_tbl, setting_name, as.character(default_value))
  suppressWarnings(as.numeric(value))
}

get_setting_vector <- function(settings_tbl, setting_name) {
  value <- get_setting_value(settings_tbl, setting_name, "")
  
  if (is.na(value) || value == "") {
    return(character(0))
  }
  
  stringr::str_split(value, ",")[[1]] %>%
    stringr::str_trim()
}

get_choices <- function(lists_tbl, list_name) {
  selected <- lists_tbl %>%
    dplyr::filter(.data$list_name == !!list_name, active == "TRUE") %>%
    dplyr::arrange(as.numeric(sort_order))
  
  stats::setNames(selected$value, selected$label)
}

get_label_from_value <- function(lists_tbl, list_name, value) {
  out <- lists_tbl %>%
    dplyr::filter(
      .data$list_name == !!list_name,
      .data$value == !!value,
      active == "TRUE"
    ) %>%
    dplyr::pull(label)
  
  if (length(out) == 0 || is.na(out[1])) {
    return(value)
  }
  
  out[1]
}

get_rule_points <- function(priority_rules_tbl, rule_group_value, condition_value_value) {
  points <- priority_rules_tbl %>%
    dplyr::filter(
      active == "TRUE",
      rule_group == !!rule_group_value,
      condition_value == !!condition_value_value
    ) %>%
    dplyr::pull(points)
  
  if (length(points) == 0) {
    return(0)
  }
  
  suppressWarnings(as.numeric(points[1]))
}

get_deadline_points <- function(priority_rules_tbl, deadline_date) {
  if (is.null(deadline_date) || is.na(deadline_date)) {
    return(0)
  }
  
  days_to_deadline <- as.numeric(as.Date(deadline_date) - Sys.Date())
  
  if (is.na(days_to_deadline) || days_to_deadline < 0) {
    return(0)
  }
  
  rules <- priority_rules_tbl %>%
    dplyr::filter(active == "TRUE", rule_group == "deadline_within_days") %>%
    dplyr::mutate(
      threshold = suppressWarnings(as.numeric(condition_value)),
      points_num = suppressWarnings(as.numeric(points))
    ) %>%
    dplyr::filter(!is.na(threshold), days_to_deadline <= threshold) %>%
    dplyr::arrange(threshold)
  
  if (nrow(rules) == 0) {
    return(0)
  }
  
  rules$points_num[1]
}

get_duration_points <- function(priority_rules_tbl, estimated_hours) {
  rules <- priority_rules_tbl %>%
    dplyr::filter(active == "TRUE", rule_group == "duration_over_hours") %>%
    dplyr::mutate(
      threshold = suppressWarnings(as.numeric(condition_value)),
      points_num = suppressWarnings(as.numeric(points))
    ) %>%
    dplyr::filter(!is.na(threshold), estimated_hours > threshold) %>%
    dplyr::arrange(dplyr::desc(threshold))
  
  if (nrow(rules) == 0) {
    return(0)
  }
  
  rules$points_num[1]
}

calculate_priority_score <- function(
    user_level,
    deadline_date,
    computing_demand,
    requires_super_2,
    uses_gpu,
    estimated_hours,
    can_be_reallocated,
    main_environment,
    priority_rules_tbl
) {
  user_points <- get_rule_points(priority_rules_tbl, "user_level", user_level)
  deadline_points <- get_deadline_points(priority_rules_tbl, deadline_date)
  demand_points <- get_rule_points(priority_rules_tbl, "computing_demand", computing_demand)
  super_2_points <- get_rule_points(priority_rules_tbl, "requires_super_2", requires_super_2)
  gpu_points <- get_rule_points(priority_rules_tbl, "uses_gpu", uses_gpu)
  duration_points <- get_duration_points(priority_rules_tbl, estimated_hours)
  reallocation_points <- get_rule_points(priority_rules_tbl, "can_be_reallocated", can_be_reallocated)
  environment_points <- get_rule_points(priority_rules_tbl, "main_environment", main_environment)
  
  user_points +
    deadline_points +
    demand_points +
    super_2_points +
    gpu_points +
    duration_points +
    reallocation_points +
    environment_points
}

format_users_public <- function(users_tbl) {
  users_tbl %>%
    dplyr::select(
      user_id,
      full_name,
      user_level_label,
      advisor,
      project_or_group,
      status,
      can_book,
      priority_base
    ) %>%
    dplyr::rename(
      "ID" = user_id,
      "Nome" = full_name,
      "Categoria" = user_level_label,
      "Orientador" = advisor,
      "Grupo" = project_or_group,
      "Status" = status,
      "Pode solicitar" = can_book,
      "Prioridade base" = priority_base
    )
}

format_computers_public <- function(computers_tbl) {
  computers_tbl %>%
    dplyr::select(
      computer_id,
      computer_name,
      computer_label,
      processor,
      cores,
      threads,
      ram_gb,
      gpu,
      gpu_memory_gb,
      main_profile,
      public_description,
      status,
      can_be_booked
    ) %>%
    dplyr::rename(
      "ID" = computer_id,
      "Computador" = computer_name,
      "Perfil" = computer_label,
      "Processador" = processor,
      "Núcleos" = cores,
      "Threads" = threads,
      "RAM GB" = ram_gb,
      "GPU" = gpu,
      "Memória GPU GB" = gpu_memory_gb,
      "Uso principal" = main_profile,
      "Descrição pública" = public_description,
      "Status" = status,
      "Pode reservar" = can_be_booked
    )
}

format_reservations_public <- function(reservations_tbl, users_tbl, lists_tbl) {
  if (nrow(reservations_tbl) == 0) {
    return(
      tibble::tibble(
        "Reserva" = character(),
        "Usuário" = character(),
        "Computador solicitado" = character(),
        "Computador atribuído" = character(),
        "Início" = character(),
        "Fim previsto" = character(),
        "Duração h" = character(),
        "Tipo" = character(),
        "Status" = character(),
        "Aprovação" = character(),
        "Prioridade" = character()
      )
    )
  }
  
  reservations_tbl %>%
    dplyr::left_join(
      users_tbl %>% dplyr::select(user_id, full_name),
      by = "user_id"
    ) %>%
    dplyr::mutate(
      computer_requested_label = purrr::map_chr(
        computer_requested,
        ~ get_label_from_value(lists_tbl, "computer_requested", .x)
      ),
      computer_assigned_label = purrr::map_chr(
        computer_assigned,
        ~ get_label_from_value(lists_tbl, "computer_assigned", .x)
      ),
      processing_type_label = purrr::map_chr(
        processing_type,
        ~ get_label_from_value(lists_tbl, "processing_type", .x)
      ),
      status_label = purrr::map_chr(
        status,
        ~ get_label_from_value(lists_tbl, "reservation_status", .x)
      ),
      approval_mode_label = purrr::map_chr(
        approval_mode,
        ~ get_label_from_value(lists_tbl, "approval_mode", .x)
      )
    ) %>%
    dplyr::select(
      reservation_id,
      full_name,
      computer_requested_label,
      computer_assigned_label,
      start_time,
      end_time,
      estimated_hours,
      processing_type_label,
      status_label,
      approval_mode_label,
      priority_score
    ) %>%
    dplyr::rename(
      "Reserva" = reservation_id,
      "Usuário" = full_name,
      "Computador solicitado" = computer_requested_label,
      "Computador atribuído" = computer_assigned_label,
      "Início" = start_time,
      "Fim previsto" = end_time,
      "Duração h" = estimated_hours,
      "Tipo" = processing_type_label,
      "Status" = status_label,
      "Aprovação" = approval_mode_label,
      "Prioridade" = priority_score
    )
}

format_audit_public <- function(audit_tbl, users_tbl) {
  if (nrow(audit_tbl) == 0) {
    return(
      tibble::tibble(
        "Log" = character(),
        "Data" = character(),
        "Evento" = character(),
        "Reserva" = character(),
        "Usuário" = character(),
        "Admin" = character(),
        "Antes" = character(),
        "Depois" = character(),
        "Observação" = character()
      )
    )
  }
  
  audit_tbl %>%
    dplyr::left_join(
      users_tbl %>% dplyr::select(user_id, full_name),
      by = "user_id"
    ) %>%
    dplyr::select(
      log_id,
      event_time,
      event_type,
      reservation_id,
      full_name,
      admin_user,
      old_value,
      new_value,
      notes
    ) %>%
    dplyr::rename(
      "Log" = log_id,
      "Data" = event_time,
      "Evento" = event_type,
      "Reserva" = reservation_id,
      "Usuário" = full_name,
      "Admin" = admin_user,
      "Antes" = old_value,
      "Depois" = new_value,
      "Observação" = notes
    )
}

time_choices <- sprintf(
  "%02d:%02d",
  rep(0:23, each = 2),
  rep(c(0, 30), times = 24)
)

parse_datetime <- function(date_value, time_value, timezone_value) {
  lubridate::ymd_hm(
    paste(as.Date(date_value), time_value),
    tz = timezone_value
  )
}

format_datetime_pt <- function(datetime_value, timezone_value = "America/Sao_Paulo") {
  if (is.null(datetime_value) || is.na(datetime_value)) {
    return("")
  }
  
  format(
    lubridate::with_tz(datetime_value, timezone_value),
    "%Y-%m-%d %H:%M:%S"
  )
}

format_datetime_label_pt <- function(datetime_value, timezone_value = "America/Sao_Paulo") {
  if (is.null(datetime_value) || is.na(datetime_value)) {
    return("")
  }
  
  format(
    lubridate::with_tz(datetime_value, timezone_value),
    "%d/%m/%Y %H:%M"
  )
}

check_reservation_conflict <- function(
    reservations_tbl,
    computer_id_value,
    start_time_value,
    end_time_value,
    timezone_value
) {
  if (nrow(reservations_tbl) == 0) {
    return(FALSE)
  }
  
  reservations_clean <- reservations_tbl %>%
    dplyr::filter(
      status %in% c("approved", "in_use"),
      computer_assigned == !!computer_id_value,
      !is.na(start_time),
      !is.na(end_time),
      start_time != "",
      end_time != ""
    ) %>%
    dplyr::mutate(
      start_time_parsed = lubridate::ymd_hms(start_time, tz = timezone_value, quiet = TRUE),
      end_time_parsed = lubridate::ymd_hms(end_time, tz = timezone_value, quiet = TRUE)
    )
  
  if (nrow(reservations_clean) == 0) {
    return(FALSE)
  }
  
  any(
    reservations_clean$start_time_parsed < end_time_value &
      reservations_clean$end_time_parsed > start_time_value,
    na.rm = TRUE
  )
}

suggest_computer_assignment <- function(
    computer_requested,
    computing_demand,
    reservations_tbl,
    start_time_value,
    end_time_value,
    timezone_value
) {
  if (computer_requested %in% c("super_1", "super_2")) {
    return(computer_requested)
  }
  
  intensive_demands <- c(
    "cpu_intensive",
    "ram_intensive",
    "raster_processing",
    "large_data",
    "deep_learning"
  )
  
  preferred_order <- if (computing_demand %in% intensive_demands) {
    c("super_2", "super_1")
  } else {
    c("super_1", "super_2")
  }
  
  for (computer_id_value in preferred_order) {
    has_conflict <- check_reservation_conflict(
      reservations_tbl = reservations_tbl,
      computer_id_value = computer_id_value,
      start_time_value = start_time_value,
      end_time_value = end_time_value,
      timezone_value = timezone_value
    )
    
    if (!has_conflict) {
      return(computer_id_value)
    }
  }
  
  preferred_order[1]
}

decide_approval_mode <- function(
    user_level,
    estimated_hours,
    requires_super_2,
    computing_demand,
    has_conflict,
    settings_tbl
) {
  manual_user_levels <- get_setting_vector(settings_tbl, "manual_approval_user_levels")
  manual_above_hours <- get_setting_numeric(settings_tbl, "manual_approval_above_hours", 24)
  
  manual_if_requires_super_2 <- get_setting_logical(
    settings_tbl,
    "manual_approval_if_requires_super_2",
    TRUE
  )
  
  manual_if_conflict <- get_setting_logical(
    settings_tbl,
    "manual_approval_if_conflict",
    TRUE
  )
  
  manual_if_unknown_demand <- get_setting_logical(
    settings_tbl,
    "manual_approval_if_unknown_demand",
    TRUE
  )
  
  reasons <- character(0)
  
  if (user_level %in% manual_user_levels) {
    reasons <- c(reasons, "categoria exige aprovação manual")
  }
  
  if (!is.na(manual_above_hours) && estimated_hours > manual_above_hours) {
    reasons <- c(reasons, "duração acima do limite de aprovação automática")
  }
  
  if (manual_if_requires_super_2 && requires_super_2 == "yes") {
    reasons <- c(reasons, "uso obrigatório do Super 2")
  }
  
  if (manual_if_conflict && has_conflict) {
    reasons <- c(reasons, "conflito de horário")
  }
  
  if (manual_if_unknown_demand && computing_demand == "unknown") {
    reasons <- c(reasons, "demanda computacional desconhecida")
  }
  
  if (length(reasons) > 0) {
    return(list(mode = "manual", reasons = reasons))
  }
  
  list(mode = "automatic", reasons = "atende aos critérios de aprovação automática")
}

decide_reservation_status <- function(approval_mode, settings_tbl) {
  allow_auto_approval <- get_setting_logical(settings_tbl, "allow_auto_approval", TRUE)
  
  if (approval_mode == "automatic" && allow_auto_approval) {
    return(get_setting_value(settings_tbl, "default_auto_approved_status", "approved"))
  }
  
  get_setting_value(settings_tbl, "default_manual_approval_status", "pending")
}

generate_reservation_id <- function() {
  paste0(
    "res_",
    format(Sys.time(), "%Y%m%d_%H%M%S"),
    "_",
    sample(1000:9999, 1)
  )
}

generate_log_id <- function() {
  paste0(
    "log_",
    format(Sys.time(), "%Y%m%d_%H%M%S"),
    "_",
    sample(1000:9999, 1)
  )
}

create_reservation_row <- function(preview, timezone_value) {
  now_value <- lubridate::now(tzone = timezone_value)
  
  tibble::tibble(
    reservation_id = generate_reservation_id(),
    created_at = format_datetime_pt(now_value, timezone_value),
    updated_at = format_datetime_pt(now_value, timezone_value),
    user_id = preview$user_id,
    computer_requested = preview$computer_requested,
    computer_assigned = preview$computer_assigned,
    start_time = format_datetime_pt(preview$start_time, timezone_value),
    end_time = format_datetime_pt(preview$end_time, timezone_value),
    estimated_hours = as.character(preview$estimated_hours),
    main_environment = preview$main_environment,
    processing_type = preview$processing_type,
    computing_demand = preview$computing_demand,
    uses_gpu = preview$uses_gpu,
    requires_super_2 = preview$requires_super_2,
    can_be_reallocated = preview$can_be_reallocated,
    deadline = ifelse(
      is.null(preview$deadline) || is.na(preview$deadline),
      NA_character_,
      as.character(as.Date(preview$deadline))
    ),
    justification = preview$justification,
    priority_score = as.character(preview$priority_score),
    status = preview$status,
    approval_mode = preview$approval_mode,
    approved_by = NA_character_,
    approved_at = NA_character_,
    rejected_by = NA_character_,
    rejected_at = NA_character_,
    cancelled_by = NA_character_,
    cancelled_at = NA_character_,
    admin_notes = NA_character_,
    public_notes = preview$public_notes
  )
}

create_audit_row <- function(
    event_type,
    reservation_id,
    user_id,
    admin_user,
    old_value,
    new_value,
    notes,
    timezone_value
) {
  now_value <- lubridate::now(tzone = timezone_value)
  
  tibble::tibble(
    log_id = generate_log_id(),
    event_time = format_datetime_pt(now_value, timezone_value),
    event_type = event_type,
    reservation_id = reservation_id,
    user_id = user_id,
    admin_user = admin_user,
    old_value = old_value,
    new_value = new_value,
    notes = notes
  )
}

update_reservation_status <- function(
    reservations_tbl,
    reservation_id_value,
    new_status,
    admin_user,
    admin_notes_value,
    timezone_value
) {
  now_text <- format_datetime_pt(
    lubridate::now(tzone = timezone_value),
    timezone_value
  )
  
  reservations_tbl <- reservations_tbl %>%
    dplyr::mutate(
      dplyr::across(
        dplyr::everything(),
        ~ as.character(.x)
      )
    )
  
  row_id <- which(reservations_tbl$reservation_id == reservation_id_value)
  
  if (length(row_id) != 1) {
    stop("Reserva não encontrada ou identificador duplicado.")
  }
  
  old_status <- reservations_tbl$status[row_id]
  
  reservations_tbl$status[row_id] <- new_status
  reservations_tbl$updated_at[row_id] <- now_text
  reservations_tbl$admin_notes[row_id] <- admin_notes_value
  
  if (new_status == "approved") {
    reservations_tbl$approved_by[row_id] <- admin_user
    reservations_tbl$approved_at[row_id] <- now_text
  }
  
  if (new_status == "rejected") {
    reservations_tbl$rejected_by[row_id] <- admin_user
    reservations_tbl$rejected_at[row_id] <- now_text
  }
  
  if (new_status == "cancelled") {
    reservations_tbl$cancelled_by[row_id] <- admin_user
    reservations_tbl$cancelled_at[row_id] <- now_text
  }
  
  list(
    reservations_tbl = reservations_tbl,
    old_status = old_status,
    user_id = reservations_tbl$user_id[row_id]
  )
}

dt_language_pt <- list(
  search = "Buscar:",
  lengthMenu = "Mostrar _MENU_ registros",
  info = "Mostrando _START_ a _END_ de _TOTAL_ registros",
  infoEmpty = "Mostrando 0 a 0 de 0 registros",
  infoFiltered = "(filtrado de _MAX_ registros)",
  zeroRecords = "Nenhum registro encontrado",
  emptyTable = "Nenhum dado disponível",
  paginate = list(
    first = "Primeiro",
    previous = "Anterior",
    `next` = "Próximo",
    last = "Último"
  )
)

institutional_header_ui <- function() {
  tags$section(
    class = "institutional-header",
    tags$div(
      class = "institutional-main",
      tags$img(
        src = "site-assets/logo_geocis.png",
        alt = "GeoCIS",
        class = "logo-geocis"
      ),
      tags$div(
        class = "institutional-text",
        tags$span("Grupo de Geotecnologias em Ciência do Solo"),
        tags$strong("Departamento de Ciência do Solo | ESALQ | USP")
      )
    ),
    tags$div(
      class = "institutional-logo-row",
      tags$img(
        src = "site-assets/logo_solos.png",
        alt = "Departamento de Ciência do Solo",
        class = "logo-institution logo-solos"
      ),
      tags$img(
        src = "site-assets/logo_esalq.png",
        alt = "ESALQ",
        class = "logo-institution logo-esalq"
      ),
      tags$img(
        src = "site-assets/logo_usp.png",
        alt = "USP",
        class = "logo-institution logo-usp"
      ),
      tags$div(
        class = "support-logo-box",
        tags$span("Apoio"),
        tags$img(
          src = "site-assets/logo_fapesp.png",
          alt = "FAPESP",
          class = "logo-institution logo-fapesp"
        )
      )
    )
  )
}

hero_ui <- function() {
  tags$section(
    class = "app-hero-grid",
    tags$div(
      class = "app-hero",
      tags$div(class = "hero-badge", "Banco de dados do sistema"),
      tags$h1("Reserva dos Computadores de Processamento"),
      tags$p(
        "Painel de validação conectado à base local do sistema. ",
        "Esta etapa confirma usuários, computadores, listas, regras e configurações ",
        "antes da integração final com o Google Sheets."
      )
    ),
    tags$aside(
      class = "hero-summary-card",
      tags$span(class = "summary-label", "Status do banco"),
      tags$div(class = "summary-main", "OK"),
      tags$p("Planilha lida com sucesso e pronta para alimentar o Shiny."),
      tags$div(
        class = "summary-list",
        tags$div(
          tags$span("Fonte atual"),
          tags$strong("Excel local")
        ),
        tags$div(
          tags$span("Etapa atual"),
          tags$strong("Administração local")
        )
      )
    )
  )
}

metric_card_ui <- function(label, output_id, class_name = "") {
  tags$div(
    class = paste("metric-card", class_name),
    tags$span(label),
    tags$strong(textOutput(output_id, inline = TRUE))
  )
}

computer_cards_ui <- function(computers_tbl) {
  card_list <- purrr::pmap(
    computers_tbl,
    function(
    computer_id,
    computer_name,
    computer_label,
    processor,
    cores,
    threads,
    ram_gb,
    gpu,
    gpu_memory_gb,
    main_profile,
    status,
    can_be_booked,
    public_description,
    notes,
    ...
    ) {
      tags$article(
        class = ifelse(
          computer_id == "super_2",
          "computer-card computer-card-featured",
          "computer-card"
        ),
        tags$div(
          class = "computer-card-header",
          tags$div(
            tags$h3(computer_name),
            tags$span(computer_label)
          ),
          tags$div(
            class = ifelse(
              can_be_booked == "TRUE",
              "status-pill status-available",
              "status-pill status-warning"
            ),
            ifelse(can_be_booked == "TRUE", "Disponível para reserva", "Indisponível")
          )
        ),
        tags$p(public_description),
        tags$div(
          class = "computer-spec-grid",
          tags$div(tags$span("Processador"), tags$strong(processor)),
          tags$div(tags$span("Núcleos e threads"), tags$strong(paste0(cores, " núcleos | ", threads, " threads"))),
          tags$div(tags$span("Memória RAM"), tags$strong(paste0(ram_gb, " GB"))),
          tags$div(tags$span("GPU"), tags$strong(paste0(gpu, " | ", gpu_memory_gb, " GB")))
        )
      )
    }
  )
  
  tags$div(
    class = "computer-card-grid",
    card_list
  )
}

footer_ui <- function() {
  tags$footer(
    class = "app-footer",
    tags$div(
      class = "footer-main",
      tags$img(
        src = "site-assets/logo_geocis.png",
        alt = "GeoCIS",
        class = "footer-logo"
      ),
      tags$div(
        tags$p("Grupo de Geotecnologias em Ciência do Solo"),
        tags$span("Departamento de Ciência do Solo | Escola Superior de Agricultura Luiz de Queiroz | Universidade de São Paulo")
      )
    ),
    tags$div(
      class = "footer-support",
      tags$span("Apoio"),
      tags$img(
        src = "site-assets/logo_fapesp.png",
        alt = "FAPESP",
        class = "footer-fapesp"
      )
    )
  )
}

reservation_preview_ui <- function(preview) {
  if (is.null(preview)) {
    return(
      tags$div(
        class = "empty-preview",
        tags$h3("Prévia da solicitação"),
        tags$p("Preencha o formulário e clique em Gerar prévia da reserva.")
      )
    )
  }
  
  status_class <- ifelse(preview$status == "approved", "preview-approved", "preview-pending")
  status_label <- ifelse(preview$status == "approved", "Aprovada automaticamente", "Pendente de aprovação")
  
  tags$div(
    class = "preview-card",
    tags$div(
      class = "preview-header",
      tags$div(
        tags$span(class = "section-kicker", "Prévia da solicitação"),
        tags$h3(preview$user_name)
      ),
      tags$div(class = paste("preview-status", status_class), status_label)
    ),
    tags$div(
      class = "preview-grid",
      tags$div(tags$span("Computador solicitado"), tags$strong(preview$computer_requested_label)),
      tags$div(tags$span("Computador sugerido"), tags$strong(preview$computer_assigned_label)),
      tags$div(tags$span("Início"), tags$strong(preview$start_time_label)),
      tags$div(tags$span("Fim previsto"), tags$strong(preview$end_time_label)),
      tags$div(tags$span("Duração estimada"), tags$strong(paste0(preview$estimated_hours, " h"))),
      tags$div(tags$span("Ambiente"), tags$strong(preview$main_environment_label)),
      tags$div(tags$span("Tipo de processamento"), tags$strong(preview$processing_type_label)),
      tags$div(tags$span("Demanda computacional"), tags$strong(preview$computing_demand_label)),
      tags$div(tags$span("Usa GPU"), tags$strong(preview$uses_gpu_label)),
      tags$div(tags$span("Exige Super 2"), tags$strong(preview$requires_super_2_label)),
      tags$div(tags$span("Pode ser realocada"), tags$strong(preview$can_be_reallocated_label)),
      tags$div(tags$span("Prioridade calculada"), tags$strong(preview$priority_score))
    ),
    tags$div(
      class = "preview-reasons",
      tags$span("Decisão preliminar"),
      tags$p(preview$approval_reason)
    ),
    tags$p(
      class = "preview-note",
      "Confira os dados antes de enviar. Nesta etapa, a solicitação será gravada apenas no arquivo Excel local."
    ),
    tags$div(
      class = "submit-area",
      actionButton(
        inputId = "submit_booking",
        label = "Enviar solicitação",
        class = "btn-success"
      )
    )
  )
}

theme_app <- bslib::bs_theme(
  version = 5,
  bootswatch = "flatly",
  primary = "#1f4f7a",
  base_font = bslib::font_google("Inter")
)

app_css <- "
:root {
  --background: #f4f7fb;
  --surface: #ffffff;
  --surface-soft: #f8fafc;
  --text-main: #101828;
  --text-muted: #667085;
  --text-light: #ffffff;
  --primary: #1f4f7a;
  --primary-dark: #123552;
  --primary-soft: #e8f1fb;
  --green: #0f8a5f;
  --green-soft: #e8f7ef;
  --orange: #b85c00;
  --orange-soft: #fff2df;
  --border: #e5e7eb;
  --shadow: 0 20px 55px rgba(15, 23, 42, 0.08);
  --shadow-soft: 0 12px 30px rgba(15, 23, 42, 0.05);
  --radius-large: 28px;
  --radius-medium: 20px;
  --radius-small: 14px;
}

body {
  background:
    radial-gradient(circle at top left, rgba(31, 79, 122, 0.16), transparent 34rem),
    linear-gradient(180deg, #eef5fb 0%, #f7f9fc 42%, #ffffff 100%);
  color: var(--text-main);
}

.navbar {
  background: #0f172a !important;
  box-shadow: 0 10px 30px rgba(15, 23, 42, 0.18);
}

.navbar .navbar-brand,
.navbar .nav-link {
  color: #ffffff !important;
  font-weight: 750;
}

.navbar .nav-link.active {
  color: #bfdbfe !important;
}

.container-fluid {
  padding-left: 7vw !important;
  padding-right: 7vw !important;
}

.institutional-header {
  display: flex;
  justify-content: space-between;
  gap: 28px;
  align-items: center;
  padding: 24px 7vw 10px;
}

.institutional-main {
  display: flex;
  gap: 18px;
  align-items: center;
  min-width: 320px;
}

.logo-geocis {
  width: 88px;
  height: 88px;
  object-fit: contain;
}

.institutional-text {
  display: grid;
  gap: 4px;
}

.institutional-text span {
  color: var(--text-muted);
  font-size: 0.92rem;
  font-weight: 700;
}

.institutional-text strong {
  color: #111827;
  font-size: 1rem;
  line-height: 1.35;
}

.institutional-logo-row {
  display: flex;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 18px;
  align-items: center;
}

.logo-institution {
  display: block;
  max-width: 100%;
  object-fit: contain;
  filter: saturate(0.95);
}

.logo-solos {
  height: 54px;
}

.logo-esalq {
  height: 48px;
  max-width: 260px;
}

.logo-usp {
  height: 44px;
  max-width: 150px;
}

.logo-fapesp {
  height: 38px;
  max-width: 170px;
}

.support-logo-box {
  display: flex;
  gap: 10px;
  align-items: center;
  padding-left: 18px;
  border-left: 1px solid rgba(102, 112, 133, 0.24);
}

.support-logo-box span {
  color: var(--text-muted);
  font-size: 0.76rem;
  font-weight: 900;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.app-hero-grid {
  display: grid;
  grid-template-columns: minmax(0, 1.45fr) minmax(300px, 0.65fr);
  gap: 24px;
  align-items: stretch;
  margin-top: 20px;
  margin-bottom: 24px;
}

.app-hero {
  background: rgba(255, 255, 255, 0.82);
  backdrop-filter: blur(14px);
  border: 1px solid rgba(255, 255, 255, 0.78);
  border-radius: var(--radius-large);
  padding: 34px;
  box-shadow: var(--shadow);
}

.hero-badge,
.section-kicker {
  display: inline-flex;
  width: fit-content;
  align-items: center;
  gap: 8px;
  margin-bottom: 18px;
  padding: 8px 14px;
  border-radius: 999px;
  color: var(--primary);
  background: var(--primary-soft);
  font-size: 0.84rem;
  font-weight: 850;
  letter-spacing: 0.02em;
}

.app-hero h1 {
  font-weight: 900;
  letter-spacing: -0.055em;
  color: #0f172a;
  font-size: clamp(2.2rem, 4.6vw, 4.4rem);
  line-height: 0.98;
  margin-bottom: 18px;
}

.app-hero p {
  color: #475467;
  margin-bottom: 0;
  max-width: 920px;
  line-height: 1.72;
  font-size: 1.05rem;
}

.hero-summary-card {
  position: relative;
  overflow: hidden;
  padding: 28px;
  border-radius: var(--radius-large);
  color: var(--text-light);
  background: #0f172a;
  box-shadow: var(--shadow);
}

.hero-summary-card::after {
  position: absolute;
  top: -90px;
  right: -80px;
  width: 220px;
  height: 220px;
  content: '';
  border-radius: 999px;
  background: rgba(59, 130, 246, 0.24);
}

.summary-label {
  display: block;
  margin-bottom: 18px;
  color: #bfdbfe;
  font-size: 0.9rem;
  font-weight: 850;
}

.summary-main {
  margin-bottom: 10px;
  font-size: 3.2rem;
  font-weight: 900;
  line-height: 1;
}

.hero-summary-card p {
  margin: 0 0 22px;
  color: #cbd5e1;
  line-height: 1.62;
}

.summary-list {
  display: grid;
  gap: 12px;
}

.summary-list div {
  display: flex;
  justify-content: space-between;
  gap: 20px;
  padding-top: 12px;
  border-top: 1px solid rgba(255, 255, 255, 0.12);
}

.summary-list span {
  color: #cbd5e1;
}

.summary-list strong {
  color: #ffffff;
}

.metric-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 18px;
  margin-bottom: 24px;
}

.metric-card {
  background: #ffffff;
  border: 1px solid var(--border);
  border-radius: var(--radius-medium);
  padding: 20px;
  box-shadow: var(--shadow-soft);
  min-height: 112px;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
}

.metric-card span {
  display: block;
  color: var(--text-muted);
  font-weight: 800;
  font-size: 0.86rem;
  margin-bottom: 10px;
}

.metric-card strong {
  display: block;
  color: #101828;
  font-size: 2.2rem;
  line-height: 1;
  letter-spacing: -0.04em;
}

.section-card {
  background: #ffffff;
  border: 1px solid var(--border);
  border-radius: var(--radius-large);
  padding: 26px;
  box-shadow: var(--shadow-soft);
  margin-bottom: 24px;
}

.section-card h2 {
  font-weight: 850;
  letter-spacing: -0.035em;
  margin-bottom: 16px;
}

.status-ok {
  color: var(--green);
  background: var(--green-soft);
  border-radius: 999px;
  padding: 7px 13px;
  font-weight: 850;
  display: inline-flex;
  margin-bottom: 14px;
}

.status-warning {
  color: var(--orange);
  background: var(--orange-soft);
  border-radius: 999px;
  padding: 7px 13px;
  font-weight: 850;
  display: inline-flex;
}

.form-layout {
  display: grid;
  grid-template-columns: minmax(0, 0.9fr) minmax(340px, 0.55fr);
  gap: 24px;
  align-items: start;
}

.form-layout .shiny-input-container {
  width: 100% !important;
  max-width: none !important;
}

.form-layout .selectize-control {
  width: 100% !important;
}

.form-layout .selectize-dropdown {
  width: 100% !important;
  min-width: 100% !important;
}

.form-layout .form-control {
  width: 100% !important;
}

.form-section-title {
  font-weight: 850;
  margin-top: 12px;
  margin-bottom: 14px;
  color: #101828;
}

.user-info-box {
  background: var(--surface-soft);
  border: 1px solid var(--border);
  border-radius: var(--radius-medium);
  padding: 18px;
  margin-top: 10px;
  margin-bottom: 18px;
}

.user-info-box span {
  display: block;
  color: var(--text-muted);
  font-size: 0.8rem;
  font-weight: 800;
  margin-bottom: 4px;
}

.user-info-box strong {
  display: block;
  color: #101828;
  margin-bottom: 10px;
}

.empty-preview,
.preview-card {
  background: #ffffff;
  border: 1px solid var(--border);
  border-radius: var(--radius-large);
  padding: 24px;
  box-shadow: var(--shadow-soft);
  position: sticky;
  top: 86px;
}

.empty-preview h3,
.preview-card h3 {
  font-weight: 850;
  letter-spacing: -0.035em;
}

.empty-preview p {
  color: var(--text-muted);
  margin-bottom: 0;
}

.preview-header {
  display: flex;
  justify-content: space-between;
  gap: 18px;
  align-items: start;
  margin-bottom: 18px;
}

.preview-status {
  padding: 8px 12px;
  border-radius: 999px;
  font-size: 0.8rem;
  font-weight: 850;
  white-space: nowrap;
}

.preview-approved {
  color: var(--green);
  background: var(--green-soft);
}

.preview-pending {
  color: var(--orange);
  background: var(--orange-soft);
}

.preview-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
  margin-bottom: 18px;
}

.preview-grid div {
  padding: 14px;
  border: 1px solid var(--border);
  border-radius: var(--radius-small);
  background: var(--surface-soft);
}

.preview-grid span,
.preview-reasons span {
  display: block;
  color: var(--text-muted);
  font-size: 0.78rem;
  font-weight: 800;
  margin-bottom: 6px;
}

.preview-grid strong {
  color: #111827;
  font-size: 0.9rem;
  line-height: 1.35;
}

.preview-reasons {
  padding: 16px;
  background: #f8fafc;
  border-radius: var(--radius-medium);
  margin-bottom: 14px;
}

.preview-reasons p {
  margin-bottom: 0;
  color: #475467;
  line-height: 1.55;
}

.preview-note {
  color: var(--text-muted);
  font-size: 0.9rem;
  margin-bottom: 0;
}

.submit-area {
  margin-top: 18px;
}

.submit-area .btn {
  width: 100%;
  border-radius: 999px;
  font-weight: 850;
  min-height: 44px;
}

.computer-card-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 22px;
}

.computer-card {
  background: #ffffff;
  border: 1px solid var(--border);
  border-radius: var(--radius-large);
  padding: 26px;
  box-shadow: var(--shadow-soft);
}

.computer-card-featured {
  border-color: rgba(31, 79, 122, 0.25);
  background:
    radial-gradient(circle at top right, rgba(31, 79, 122, 0.08), transparent 18rem),
    #ffffff;
}

.computer-card-header {
  display: flex;
  justify-content: space-between;
  gap: 18px;
  align-items: start;
  margin-bottom: 18px;
}

.computer-card h3 {
  margin: 0 0 5px;
  font-size: 1.45rem;
  font-weight: 850;
  letter-spacing: -0.035em;
}

.computer-card-header span {
  color: var(--text-muted);
  font-weight: 650;
}

.computer-card p {
  color: #475467;
  line-height: 1.65;
  margin-bottom: 20px;
}

.status-pill {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: fit-content;
  padding: 8px 12px;
  border-radius: 999px;
  font-size: 0.8rem;
  font-weight: 850;
  white-space: nowrap;
}

.status-available {
  color: var(--green);
  background: var(--green-soft);
}

.computer-spec-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 14px;
}

.computer-spec-grid div {
  padding: 15px;
  border: 1px solid var(--border);
  border-radius: var(--radius-small);
  background: var(--surface-soft);
}

.computer-spec-grid span {
  display: block;
  margin-bottom: 6px;
  color: var(--text-muted);
  font-size: 0.8rem;
  font-weight: 800;
}

.computer-spec-grid strong {
  color: #111827;
  font-size: 0.92rem;
  line-height: 1.35;
}

.dataTables_wrapper {
  font-size: 0.92rem;
}

table.dataTable {
  border-collapse: collapse !important;
}

table.dataTable thead th {
  background: #f8fafc;
  color: #475467;
  font-weight: 850;
  border-bottom: 1px solid var(--border) !important;
}

table.dataTable tbody td {
  border-top: 1px solid var(--border);
}

.app-footer {
  display: flex;
  justify-content: space-between;
  gap: 24px;
  align-items: center;
  margin-top: 28px;
  margin-bottom: 20px;
  padding: 24px 26px;
  color: var(--text-muted);
  background: rgba(255, 255, 255, 0.82);
  border: 1px solid var(--border);
  border-radius: var(--radius-large);
  box-shadow: var(--shadow-soft);
}

.footer-main {
  display: flex;
  gap: 16px;
  align-items: center;
}

.footer-logo {
  width: 62px;
  height: 62px;
  object-fit: contain;
}

.app-footer p,
.app-footer span {
  margin: 0;
}

.app-footer p {
  margin-bottom: 4px;
  font-weight: 850;
  color: #344054;
}

.footer-support {
  display: flex;
  gap: 12px;
  align-items: center;
}

.footer-support span {
  color: var(--text-muted);
  font-size: 0.76rem;
  font-weight: 900;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.footer-fapesp {
  height: 34px;
  width: auto;
  object-fit: contain;
}

@media (max-width: 1180px) {
  .institutional-header {
    display: block;
  }

  .institutional-logo-row {
    justify-content: flex-start;
    margin-top: 18px;
  }

  .support-logo-box {
    padding-left: 0;
    border-left: none;
  }

  .app-hero-grid,
  .computer-card-grid,
  .form-layout {
    grid-template-columns: 1fr;
  }

  .metric-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }

  .empty-preview,
  .preview-card {
    position: static;
  }
}

@media (max-width: 760px) {
  .container-fluid,
  .institutional-header {
    padding-left: 20px !important;
    padding-right: 20px !important;
  }

  .institutional-main {
    display: block;
    min-width: 0;
  }

  .logo-geocis {
    width: 76px;
    height: 76px;
    margin-bottom: 12px;
  }

  .institutional-logo-row {
    gap: 14px;
  }

  .logo-solos {
    height: 42px;
  }

  .logo-esalq {
    height: 38px;
    max-width: 220px;
  }

  .logo-usp {
    height: 36px;
    max-width: 120px;
  }

  .logo-fapesp {
    height: 32px;
    max-width: 140px;
  }

  .metric-grid,
  .computer-spec-grid,
  .preview-grid {
    grid-template-columns: 1fr;
  }

  .app-hero,
  .hero-summary-card,
  .section-card,
  .computer-card,
  .app-footer {
    border-radius: 22px;
  }

  .app-hero {
    padding: 26px;
  }

  .app-footer {
    display: block;
  }

  .footer-main {
    align-items: flex-start;
  }

  .footer-support {
    margin-top: 20px;
  }
}
"

ui <- bslib::page_navbar(
  title = "Reserva dos Computadores de Processamento",
  theme = theme_app,
  id = "main_nav",
  
  header = tagList(
    tags$head(tags$style(HTML(app_css))),
    institutional_header_ui()
  ),
  
  bslib::nav_panel(
    title = "Visão geral",
    hero_ui(),
    tags$div(
      class = "metric-grid",
      metric_card_ui("Usuários ativos", "n_users"),
      metric_card_ui("Computadores ativos", "n_computers"),
      metric_card_ui("Reservas registradas", "n_reservations"),
      metric_card_ui("Regras de prioridade", "n_rules")
    ),
    tags$div(
      class = "section-card",
      tags$h2("Resumo do sistema"),
      uiOutput("system_summary")
    ),
    tags$div(
      class = "section-card",
      tags$h2("Infraestrutura ativa"),
      uiOutput("computer_cards")
    ),
    footer_ui()
  ),
  
  bslib::nav_panel(
    title = "Solicitar reserva",
    tags$div(
      class = "section-card",
      tags$h2("Solicitar reserva"),
      tags$p(
        "Gere a prévia, confira os dados e envie a solicitação. Nesta fase, a solicitação será gravada no arquivo Excel local."
      ),
      tags$div(
        class = "form-layout",
        tags$div(
          selectInput(
            inputId = "booking_user_id",
            label = "Selecione seu nome",
            choices = NULL
          ),
          textInput(
            inputId = "booking_email",
            label = "Confirme seu e-mail cadastrado",
            placeholder = "Digite o e-mail cadastrado na base"
          ),
          uiOutput("selected_user_info"),
          tags$h4(class = "form-section-title", "Reserva"),
          selectInput(
            inputId = "booking_computer_requested",
            label = "Computador desejado",
            choices = NULL
          ),
          fluidRow(
            column(
              width = 6,
              dateInput(
                inputId = "booking_start_date",
                label = "Data de início",
                value = Sys.Date(),
                min = Sys.Date(),
                language = "pt-BR",
                weekstart = 0
              )
            ),
            column(
              width = 6,
              selectInput(
                inputId = "booking_start_time",
                label = "Horário de início",
                choices = time_choices,
                selected = "08:00"
              )
            )
          ),
          numericInput(
            inputId = "booking_estimated_hours",
            label = "Duração estimada em horas",
            value = 4,
            min = 0.5,
            max = 168,
            step = 0.5
          ),
          tags$h4(class = "form-section-title", "Processamento"),
          selectInput(
            inputId = "booking_main_environment",
            label = "Ambiente principal",
            choices = NULL
          ),
          selectInput(
            inputId = "booking_processing_type",
            label = "Tipo de processamento",
            choices = NULL
          ),
          selectInput(
            inputId = "booking_computing_demand",
            label = "Demanda computacional principal",
            choices = NULL
          ),
          fluidRow(
            column(
              width = 4,
              selectInput(
                inputId = "booking_uses_gpu",
                label = "Usa GPU?",
                choices = NULL
              )
            ),
            column(
              width = 4,
              selectInput(
                inputId = "booking_requires_super_2",
                label = "Exige Super 2?",
                choices = NULL
              )
            ),
            column(
              width = 4,
              selectInput(
                inputId = "booking_can_be_reallocated",
                label = "Pode ser realocada?",
                choices = NULL
              )
            )
          ),
          dateInput(
            inputId = "booking_deadline",
            label = "Data limite do processamento, se houver",
            value = NA,
            language = "pt-BR",
            weekstart = 0
          ),
          helpText(
            "Informe apenas se houver uma entrega, reunião, relatório, qualificação, submissão ou outro prazo formal relacionado ao processamento."
          ),
          textAreaInput(
            inputId = "booking_justification",
            label = "Justificativa da solicitação",
            placeholder = "Descreva brevemente o objetivo do processamento, o motivo da escolha do computador e, se houver, o prazo relacionado.",
            rows = 4
          ),
          textAreaInput(
            inputId = "booking_public_notes",
            label = "Observação pública, opcional",
            placeholder = "Exemplo: processamento raster, modelagem espectral, predição em larga escala. Evite informações sensíveis.",
            rows = 2
          ),
          actionButton(
            inputId = "generate_booking_preview",
            label = "Gerar prévia da reserva",
            class = "btn-primary"
          )
        ),
        tags$div(
          uiOutput("booking_preview")
        )
      )
    )
  ),
  
  bslib::nav_panel(
    title = "Reservas",
    tags$div(
      class = "section-card",
      tags$h2("Reservas registradas"),
      tags$p("Tabela com as solicitações gravadas localmente na aba reservations."),
      DT::DTOutput("reservations_table")
    )
  ),
  
  bslib::nav_panel(
    title = "Administração",
    tags$div(
      class = "section-card",
      tags$h2("Administração"),
      tags$p(
        "Área para aprovar, rejeitar ou cancelar reservas. O acesso exige senha administrativa."
      ),
      uiOutput("admin_panel")
    )
  ),
  
  bslib::nav_panel(
    title = "Usuários",
    tags$div(
      class = "section-card",
      tags$h2("Usuários cadastrados"),
      DT::DTOutput("users_table")
    )
  ),
  
  bslib::nav_panel(
    title = "Computadores",
    tags$div(
      class = "section-card",
      tags$h2("Computadores cadastrados"),
      DT::DTOutput("computers_table")
    )
  ),
  
  bslib::nav_panel(
    title = "Listas",
    tags$div(
      class = "section-card",
      tags$h2("Listas do sistema"),
      DT::DTOutput("lists_table")
    )
  ),
  
  bslib::nav_panel(
    title = "Regras",
    tags$div(
      class = "section-card",
      tags$h2("Regras de prioridade"),
      DT::DTOutput("priority_rules_table")
    )
  ),
  
  bslib::nav_panel(
    title = "Configurações",
    tags$div(
      class = "section-card",
      tags$h2("Configurações ativas"),
      DT::DTOutput("settings_table")
    )
  ),
  
  bslib::nav_panel(
    title = "Auditoria",
    tags$div(
      class = "section-card",
      tags$h2("Auditoria"),
      tags$p("Registro local das ações administrativas gravadas na aba audit_log."),
      DT::DTOutput("audit_table")
    )
  )
)

server <- function(input, output, session) {
  reload_key <- reactiveVal(0)
  last_submitted_id <- reactiveVal(NULL)
  admin_authenticated <- reactiveVal(FALSE)
  
  database <- reactive({
    reload_key()
    
    validate(
      need(file.exists(database_file), paste("Arquivo não encontrado:", database_file))
    )
    
    read_database()
  })
  
  users <- reactive({
    get_active_users(database())
  })
  
  computers <- reactive({
    get_active_computers(database())
  })
  
  lists <- reactive({
    get_active_lists(database())
  })
  
  reservations <- reactive({
    database()$reservations
  })
  
  audit_log <- reactive({
    database()$audit_log
  })
  
  priority_rules <- reactive({
    database()$priority_rules %>%
      dplyr::filter(active == "TRUE") %>%
      dplyr::arrange(rule_id)
  })
  
  settings <- reactive({
    get_active_settings(database())
  })
  
  observe({
    user_choices <- users() %>%
      dplyr::mutate(label = paste0(full_name, " | ", user_level_label)) %>%
      dplyr::arrange(full_name)
    
    updateSelectInput(
      session,
      inputId = "booking_user_id",
      choices = stats::setNames(user_choices$user_id, user_choices$label),
      selected = user_choices$user_id[1]
    )
    
    updateSelectInput(
      session,
      inputId = "booking_computer_requested",
      choices = get_choices(lists(), "computer_requested"),
      selected = "any"
    )
    
    updateSelectInput(
      session,
      inputId = "booking_main_environment",
      choices = get_choices(lists(), "main_environment"),
      selected = "r"
    )
    
    updateSelectInput(
      session,
      inputId = "booking_processing_type",
      choices = get_choices(lists(), "processing_type"),
      selected = "raster_processing"
    )
    
    updateSelectInput(
      session,
      inputId = "booking_computing_demand",
      choices = get_choices(lists(), "computing_demand"),
      selected = "raster_processing"
    )
    
    updateSelectInput(
      session,
      inputId = "booking_uses_gpu",
      choices = get_choices(lists(), "yes_no"),
      selected = "unknown"
    )
    
    updateSelectInput(
      session,
      inputId = "booking_requires_super_2",
      choices = get_choices(lists(), "yes_no"),
      selected = "unknown"
    )
    
    updateSelectInput(
      session,
      inputId = "booking_can_be_reallocated",
      choices = get_choices(lists(), "yes_no"),
      selected = "yes"
    )
  })
  
  selected_user <- reactive({
    users() %>%
      dplyr::filter(user_id == input$booking_user_id) %>%
      dplyr::slice(1)
  })
  
  output$selected_user_info <- renderUI({
    user_tbl <- selected_user()
    
    if (nrow(user_tbl) == 0) {
      return(NULL)
    }
    
    tags$div(
      class = "user-info-box",
      tags$span("Cadastro selecionado"),
      tags$strong(user_tbl$full_name),
      tags$span("Categoria"),
      tags$strong(user_tbl$user_level_label),
      tags$span("Orientador"),
      tags$strong(user_tbl$advisor),
      tags$span("E-mail cadastrado"),
      tags$strong(user_tbl$email)
    )
  })
  
  output$n_users <- renderText({
    nrow(users())
  })
  
  output$n_computers <- renderText({
    nrow(computers())
  })
  
  output$n_reservations <- renderText({
    nrow(reservations())
  })
  
  output$n_rules <- renderText({
    nrow(priority_rules())
  })
  
  output$system_summary <- renderUI({
    reservations_n <- nrow(reservations())
    usage_n <- nrow(database()$usage_log)
    audit_n <- nrow(audit_log())
    
    source_label <- ifelse(
      file.exists(database_file),
      "Excel local",
      "Fonte não encontrada"
    )
    
    auto_approval <- get_setting_value(settings(), "allow_auto_approval", "FALSE")
    require_email <- get_setting_value(settings(), "require_email_confirmation", "FALSE")
    
    tagList(
      tags$p(
        tags$span(class = "status-ok", "Conexão local funcionando")
      ),
      tags$p(
        "A planilha foi lida com sucesso. Existem ",
        tags$strong(nrow(users())),
        " usuários ativos, ",
        tags$strong(nrow(computers())),
        " computadores ativos, ",
        tags$strong(nrow(database()$lists)),
        " itens de lista, ",
        tags$strong(nrow(priority_rules())),
        " regras de prioridade e ",
        tags$strong(nrow(settings())),
        " configurações ativas."
      ),
      tags$p(
        "Reservas registradas: ",
        tags$strong(reservations_n),
        ". Registros de uso: ",
        tags$strong(usage_n),
        ". Eventos administrativos: ",
        tags$strong(audit_n),
        "."
      ),
      tags$p(
        "Fonte atual: ",
        tags$strong(source_label),
        ". Aprovação automática: ",
        tags$strong(ifelse(auto_approval == "TRUE", "habilitada", "desabilitada")),
        ". Confirmação de e-mail: ",
        tags$strong(ifelse(require_email == "TRUE", "obrigatória", "desabilitada")),
        "."
      )
    )
  })
  
  output$computer_cards <- renderUI({
    computer_cards_ui(computers())
  })
  
  booking_preview_data <- eventReactive(input$generate_booking_preview, {
    user_tbl <- selected_user()
    
    validate(
      need(nrow(user_tbl) == 1, "Selecione um usuário válido."),
      need(input$booking_email != "", "Confirme o e-mail cadastrado."),
      need(
        stringr::str_to_lower(input$booking_email) == stringr::str_to_lower(user_tbl$email),
        "O e-mail informado não confere com o e-mail cadastrado."
      ),
      need(input$booking_estimated_hours > 0, "Informe uma duração válida.")
    )
    
    timezone_value <- get_setting_value(settings(), "timezone", "America/Sao_Paulo")
    
    start_time_value <- parse_datetime(
      input$booking_start_date,
      input$booking_start_time,
      timezone_value
    )
    
    end_time_value <- start_time_value + lubridate::hours(input$booking_estimated_hours)
    
    assigned_computer <- suggest_computer_assignment(
      computer_requested = input$booking_computer_requested,
      computing_demand = input$booking_computing_demand,
      reservations_tbl = reservations(),
      start_time_value = start_time_value,
      end_time_value = end_time_value,
      timezone_value = timezone_value
    )
    
    has_conflict <- check_reservation_conflict(
      reservations_tbl = reservations(),
      computer_id_value = assigned_computer,
      start_time_value = start_time_value,
      end_time_value = end_time_value,
      timezone_value = timezone_value
    )
    
    priority_score <- calculate_priority_score(
      user_level = user_tbl$user_level,
      deadline_date = input$booking_deadline,
      computing_demand = input$booking_computing_demand,
      requires_super_2 = input$booking_requires_super_2,
      uses_gpu = input$booking_uses_gpu,
      estimated_hours = input$booking_estimated_hours,
      can_be_reallocated = input$booking_can_be_reallocated,
      main_environment = input$booking_main_environment,
      priority_rules_tbl = priority_rules()
    )
    
    approval_decision <- decide_approval_mode(
      user_level = user_tbl$user_level,
      estimated_hours = input$booking_estimated_hours,
      requires_super_2 = input$booking_requires_super_2,
      computing_demand = input$booking_computing_demand,
      has_conflict = has_conflict,
      settings_tbl = settings()
    )
    
    reservation_status <- decide_reservation_status(
      approval_mode = approval_decision$mode,
      settings_tbl = settings()
    )
    
    choices_computer_requested <- get_choices(lists(), "computer_requested")
    choices_computer_assigned <- get_choices(lists(), "computer_assigned")
    choices_environment <- get_choices(lists(), "main_environment")
    choices_processing <- get_choices(lists(), "processing_type")
    choices_demand <- get_choices(lists(), "computing_demand")
    choices_yes_no <- get_choices(lists(), "yes_no")
    
    list(
      user_id = user_tbl$user_id,
      user_name = user_tbl$full_name,
      user_level = user_tbl$user_level,
      user_level_label = user_tbl$user_level_label,
      computer_requested = input$booking_computer_requested,
      computer_requested_label = names(choices_computer_requested)[match(input$booking_computer_requested, choices_computer_requested)],
      computer_assigned = assigned_computer,
      computer_assigned_label = names(choices_computer_assigned)[match(assigned_computer, choices_computer_assigned)],
      start_time = start_time_value,
      start_time_label = format_datetime_label_pt(start_time_value, timezone_value),
      end_time = end_time_value,
      end_time_label = format_datetime_label_pt(end_time_value, timezone_value),
      estimated_hours = input$booking_estimated_hours,
      main_environment = input$booking_main_environment,
      main_environment_label = names(choices_environment)[match(input$booking_main_environment, choices_environment)],
      processing_type = input$booking_processing_type,
      processing_type_label = names(choices_processing)[match(input$booking_processing_type, choices_processing)],
      computing_demand = input$booking_computing_demand,
      computing_demand_label = names(choices_demand)[match(input$booking_computing_demand, choices_demand)],
      uses_gpu = input$booking_uses_gpu,
      uses_gpu_label = names(choices_yes_no)[match(input$booking_uses_gpu, choices_yes_no)],
      requires_super_2 = input$booking_requires_super_2,
      requires_super_2_label = names(choices_yes_no)[match(input$booking_requires_super_2, choices_yes_no)],
      can_be_reallocated = input$booking_can_be_reallocated,
      can_be_reallocated_label = names(choices_yes_no)[match(input$booking_can_be_reallocated, choices_yes_no)],
      deadline = input$booking_deadline,
      justification = input$booking_justification,
      public_notes = input$booking_public_notes,
      priority_score = priority_score,
      has_conflict = has_conflict,
      approval_mode = approval_decision$mode,
      approval_reason = paste(approval_decision$reasons, collapse = "; "),
      status = reservation_status
    )
  })
  
  output$booking_preview <- renderUI({
    reservation_preview_ui(booking_preview_data())
  })
  
  observeEvent(input$submit_booking, {
    preview <- booking_preview_data()
    req(preview)
    
    timezone_value <- get_setting_value(settings(), "timezone", "America/Sao_Paulo")
    new_reservation <- create_reservation_row(preview, timezone_value)
    
    aligned_reservations <- align_tables_as_character(
      reference_tbl = reservations(),
      new_tbl = new_reservation
    )
    
    reservations_updated <- dplyr::bind_rows(
      aligned_reservations$reference_tbl,
      aligned_reservations$new_tbl
    )
    
    tryCatch(
      {
        write_sheet_to_workbook(
          database_file = database_file,
          sheet_name = "reservations",
          data_tbl = reservations_updated
        )
        
        last_submitted_id(new_reservation$reservation_id[1])
        reload_key(reload_key() + 1)
        
        showNotification(
          paste0(
            "Solicitação enviada com sucesso: ",
            new_reservation$reservation_id[1]
          ),
          type = "message",
          duration = 6
        )
        
        updateTabsetPanel(session, "main_nav", selected = "Reservas")
      },
      error = function(e) {
        showNotification(
          paste(
            "Não foi possível gravar a solicitação. Verifique se o arquivo Excel está fechado.",
            e$message
          ),
          type = "error",
          duration = 10
        )
      }
    )
  })
  
  output$admin_panel <- renderUI({
    if (!admin_authenticated()) {
      return(
        tags$div(
          class = "form-layout",
          tags$div(
            passwordInput(
              inputId = "admin_password",
              label = "Senha administrativa",
              placeholder = "Digite a senha administrativa"
            ),
            actionButton(
              inputId = "admin_login",
              label = "Entrar",
              class = "btn-primary"
            )
          ),
          tags$div(
            class = "empty-preview",
            tags$h3("Acesso restrito"),
            tags$p(
              "Use esta área apenas para revisar solicitações e alterar status de reservas."
            )
          )
        )
      )
    }
    
    admin_reservations <- reservations() %>%
      dplyr::filter(status %in% c("pending", "approved", "in_use")) %>%
      dplyr::left_join(
        database()$users %>% dplyr::select(user_id, full_name),
        by = "user_id"
      ) %>%
      dplyr::arrange(status, start_time)
    
    reservation_choices <- if (nrow(admin_reservations) == 0) {
      character(0)
    } else {
      stats::setNames(
        admin_reservations$reservation_id,
        paste0(
          admin_reservations$reservation_id,
          " | ",
          admin_reservations$full_name,
          " | ",
          admin_reservations$status
        )
      )
    }
    
    tags$div(
      class = "form-layout",
      tags$div(
        tags$h4(class = "form-section-title", "Reserva"),
        selectInput(
          inputId = "admin_reservation_id",
          label = "Selecione uma reserva",
          choices = reservation_choices
        ),
        textAreaInput(
          inputId = "admin_notes",
          label = "Observação administrativa",
          placeholder = "Informe o motivo da decisão ou alguma orientação para o usuário.",
          rows = 4
        ),
        fluidRow(
          column(
            width = 4,
            actionButton(
              inputId = "admin_approve",
              label = "Aprovar",
              class = "btn-success"
            )
          ),
          column(
            width = 4,
            actionButton(
              inputId = "admin_reject",
              label = "Rejeitar",
              class = "btn-warning"
            )
          ),
          column(
            width = 4,
            actionButton(
              inputId = "admin_cancel",
              label = "Cancelar",
              class = "btn-danger"
            )
          )
        )
      ),
      tags$div(
        uiOutput("admin_selected_reservation")
      )
    )
  })
  
  observeEvent(input$admin_login, {
    expected_password <- Sys.getenv("LAB_SCHEDULER_ADMIN_PASSWORD")
    
    if (expected_password == "") {
      showNotification(
        "Senha administrativa não configurada no ambiente R.",
        type = "error",
        duration = 8
      )
      return(NULL)
    }
    
    if (identical(input$admin_password, expected_password)) {
      admin_authenticated(TRUE)
      showNotification(
        "Acesso administrativo liberado.",
        type = "message",
        duration = 5
      )
    } else {
      admin_authenticated(FALSE)
      showNotification(
        "Senha administrativa incorreta.",
        type = "error",
        duration = 6
      )
    }
  })
  
  output$admin_selected_reservation <- renderUI({
    req(admin_authenticated())
    
    selected_id <- input$admin_reservation_id
    
    if (is.null(selected_id) || selected_id == "") {
      return(
        tags$div(
          class = "empty-preview",
          tags$h3("Nenhuma reserva selecionada"),
          tags$p("Selecione uma reserva para revisar os detalhes.")
        )
      )
    }
    
    reservation_tbl <- reservations() %>%
      dplyr::filter(reservation_id == selected_id) %>%
      dplyr::left_join(
        database()$users %>% dplyr::select(user_id, full_name, user_level_label, email),
        by = "user_id"
      ) %>%
      dplyr::slice(1)
    
    if (nrow(reservation_tbl) == 0) {
      return(
        tags$div(
          class = "empty-preview",
          tags$h3("Reserva não encontrada"),
          tags$p("A reserva selecionada não foi encontrada na base.")
        )
      )
    }
    
    tags$div(
      class = "preview-card",
      tags$div(
        class = "preview-header",
        tags$div(
          tags$span(class = "section-kicker", "Revisão administrativa"),
          tags$h3(reservation_tbl$full_name)
        ),
        tags$div(
          class = "preview-status preview-pending",
          reservation_tbl$status
        )
      ),
      tags$div(
        class = "preview-grid",
        tags$div(tags$span("Reserva"), tags$strong(reservation_tbl$reservation_id)),
        tags$div(tags$span("Categoria"), tags$strong(reservation_tbl$user_level_label)),
        tags$div(tags$span("Computador solicitado"), tags$strong(reservation_tbl$computer_requested)),
        tags$div(tags$span("Computador atribuído"), tags$strong(reservation_tbl$computer_assigned)),
        tags$div(tags$span("Início"), tags$strong(reservation_tbl$start_time)),
        tags$div(tags$span("Fim previsto"), tags$strong(reservation_tbl$end_time)),
        tags$div(tags$span("Duração h"), tags$strong(reservation_tbl$estimated_hours)),
        tags$div(tags$span("Prioridade"), tags$strong(reservation_tbl$priority_score)),
        tags$div(tags$span("Tipo"), tags$strong(reservation_tbl$processing_type)),
        tags$div(tags$span("Demanda"), tags$strong(reservation_tbl$computing_demand)),
        tags$div(tags$span("Usa GPU"), tags$strong(reservation_tbl$uses_gpu)),
        tags$div(tags$span("Exige Super 2"), tags$strong(reservation_tbl$requires_super_2))
      ),
      tags$div(
        class = "preview-reasons",
        tags$span("Justificativa"),
        tags$p(reservation_tbl$justification)
      )
    )
  })
  
  process_admin_action <- function(new_status, event_type) {
    req(admin_authenticated())
    req(input$admin_reservation_id)
    
    selected_id <- input$admin_reservation_id
    timezone_value <- get_setting_value(settings(), "timezone", "America/Sao_Paulo")
    admin_user <- "admin"
    admin_notes_value <- ifelse(
      is.null(input$admin_notes) || input$admin_notes == "",
      NA_character_,
      input$admin_notes
    )
    
    tryCatch(
      {
        updated_result <- update_reservation_status(
          reservations_tbl = reservations(),
          reservation_id_value = selected_id,
          new_status = new_status,
          admin_user = admin_user,
          admin_notes_value = admin_notes_value,
          timezone_value = timezone_value
        )
        
        audit_row <- create_audit_row(
          event_type = event_type,
          reservation_id = selected_id,
          user_id = updated_result$user_id,
          admin_user = admin_user,
          old_value = updated_result$old_status,
          new_value = new_status,
          notes = admin_notes_value,
          timezone_value = timezone_value
        )
        
        aligned_audit <- align_tables_as_character(
          reference_tbl = audit_log(),
          new_tbl = audit_row
        )
        
        audit_updated <- dplyr::bind_rows(
          aligned_audit$reference_tbl,
          aligned_audit$new_tbl
        )
        
        write_sheet_to_workbook(
          database_file = database_file,
          sheet_name = "reservations",
          data_tbl = updated_result$reservations_tbl
        )
        
        write_sheet_to_workbook(
          database_file = database_file,
          sheet_name = "audit_log",
          data_tbl = audit_updated
        )
        
        reload_key(reload_key() + 1)
        
        showNotification(
          paste0("Reserva atualizada para: ", new_status),
          type = "message",
          duration = 6
        )
        
        updateTabsetPanel(session, "main_nav", selected = "Reservas")
      },
      error = function(e) {
        showNotification(
          paste(
            "Não foi possível atualizar a reserva. Verifique se o Excel está fechado.",
            e$message
          ),
          type = "error",
          duration = 10
        )
      }
    )
  }
  
  observeEvent(input$admin_approve, {
    process_admin_action(
      new_status = "approved",
      event_type = "reservation_approved"
    )
  })
  
  observeEvent(input$admin_reject, {
    process_admin_action(
      new_status = "rejected",
      event_type = "reservation_rejected"
    )
  })
  
  observeEvent(input$admin_cancel, {
    process_admin_action(
      new_status = "cancelled",
      event_type = "reservation_cancelled"
    )
  })
  
  output$reservations_table <- DT::renderDT({
    DT::datatable(
      format_reservations_public(reservations(), database()$users, lists()),
      rownames = FALSE,
      filter = "top",
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        order = list(list(4, "desc")),
        language = dt_language_pt
      )
    )
  })
  
  output$audit_table <- DT::renderDT({
    DT::datatable(
      format_audit_public(audit_log(), database()$users),
      rownames = FALSE,
      filter = "top",
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        order = list(list(1, "desc")),
        language = dt_language_pt
      )
    )
  })
  
  output$users_table <- DT::renderDT({
    DT::datatable(
      format_users_public(users()),
      rownames = FALSE,
      filter = "top",
      options = list(
        pageLength = 10,
        scrollX = TRUE,
        language = dt_language_pt
      )
    )
  })
  
  output$computers_table <- DT::renderDT({
    DT::datatable(
      format_computers_public(computers()),
      rownames = FALSE,
      options = list(
        pageLength = 5,
        scrollX = TRUE,
        language = dt_language_pt
      )
    )
  })
  
  output$lists_table <- DT::renderDT({
    DT::datatable(
      lists(),
      rownames = FALSE,
      filter = "top",
      options = list(
        pageLength = 15,
        scrollX = TRUE,
        language = dt_language_pt
      )
    )
  })
  
  output$priority_rules_table <- DT::renderDT({
    DT::datatable(
      priority_rules(),
      rownames = FALSE,
      filter = "top",
      options = list(
        pageLength = 15,
        scrollX = TRUE,
        language = dt_language_pt
      )
    )
  })
  
  output$settings_table <- DT::renderDT({
    DT::datatable(
      settings(),
      rownames = FALSE,
      filter = "top",
      options = list(
        pageLength = 15,
        scrollX = TRUE,
        language = dt_language_pt
      )
    )
  })
}

shinyApp(ui = ui, server = server)