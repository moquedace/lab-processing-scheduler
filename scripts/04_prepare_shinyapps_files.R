pkg <- c(
  "fs"
)

missing_pkg <- pkg[!vapply(pkg, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_pkg) > 0) {
  install.packages(missing_pkg)
}

invisible(lapply(pkg, library, character.only = TRUE))

rm(list = ls())
gc()

project_root <- if (basename(getwd()) == "scripts") {
  normalizePath(file.path(getwd(), ".."), winslash = "/", mustWork = TRUE)
} else {
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
}

source_logo_dir <- file.path(
  project_root,
  "docs",
  "assets",
  "img"
)

target_logo_dir <- file.path(
  project_root,
  "shiny_app",
  "www",
  "img"
)

source_secret_file <- file.path(
  project_root,
  "secrets",
  "google_service_account.json"
)

target_secret_dir <- file.path(
  project_root,
  "shiny_app",
  "secrets"
)

target_secret_file <- file.path(
  target_secret_dir,
  "google_service_account.json"
)

required_logos <- c(
  "logo_geocis.png",
  "logo_solos.png",
  "logo_esalq.png",
  "logo_usp.png",
  "logo_fapesp.png"
)

fs::dir_create(target_logo_dir)
fs::dir_create(target_secret_dir)

missing_logos <- required_logos[
  !file.exists(file.path(source_logo_dir, required_logos))
]

if (length(missing_logos) > 0) {
  stop(
    paste(
      "Missing logo files:",
      paste(missing_logos, collapse = ", ")
    )
  )
}

for (logo_file in required_logos) {
  fs::file_copy(
    path = file.path(source_logo_dir, logo_file),
    new_path = file.path(target_logo_dir, logo_file),
    overwrite = TRUE
  )
}

if (!file.exists(source_secret_file)) {
  stop(
    paste(
      "Service account file not found:",
      source_secret_file
    )
  )
}

fs::file_copy(
  path = source_secret_file,
  new_path = target_secret_file,
  overwrite = TRUE
)

message("\nFiles prepared for shinyapps.io.")
message("Logos copied to: ", target_logo_dir)
message("Service account copied to: ", target_secret_file)
message("\nDo not commit shiny_app/secrets or any JSON file.")
