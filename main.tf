provider "archive" {
  version = "~> 1.0"
}

provider "template" {
  version = "~> 1.0"
}

locals {
  version = "0.1.3"
}

data "template_file" "config" {
  template = "${file("${path.module}/src/config.tpl")}"

  vars {
    channel            = "${var.channel}"
    color              = "${var.color}"
    project            = "${var.project}"
    redirect_url       = "${var.redirect_url}"
    slash_command      = "${var.slash_command}"
    verification_token = "${var.verification_token}"
    web_api_token      = "${var.web_api_token}"
  }
}

data "archive_file" "archive" {
  type        = "zip"
  output_path = "${path.module}/dist/${var.function_name}-${local.version}.zip"

  source {
    content  = "${var.client_secret}"
    filename = "client_secret.json"
  }

  source {
    content  = "${data.template_file.config.rendered}"
    filename = "config.json"
  }

  source {
    content  = "${file("${path.module}/src/index.js")}"
    filename = "index.js"
  }

  source {
    content  = "${file("${path.module}/src/messages.json")}"
    filename = "messages.json"
  }

  source {
    content  = "${file("${path.module}/package.json")}"
    filename = "package.json"
  }

  source {
    content  = "${jsonencode("${var.users}")}"
    filename = "users.json"
  }
}

resource "google_storage_bucket_object" "archive" {
  bucket = "${var.bucket_name}"
  name   = "${var.bucket_prefix}${var.function_name}-${local.version}.zip"
  source = "${data.archive_file.archive.output_path}"
}

resource "google_cloudfunctions_function" "function" {
  name                  = "${var.function_name}"
  description           = "Slack Drive slash command"
  available_memory_mb   = "${var.memory}"
  source_archive_bucket = "${var.bucket_name}"
  source_archive_object = "${google_storage_bucket_object.archive.name}"
  trigger_http          = true
  timeout               = "${var.timeout}"
  entry_point           = "slashCommand"

  labels {
    deployment-tool = "terraform"
  }
}
