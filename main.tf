/**
 * Copyright 2019 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/******************************************
	Scheduled Function Definition
 *****************************************/

resource "google_cloud_scheduler_job" "job" {
  name        = var.job_name
  project     = var.project_id
  region      = var.region
  description = var.job_description
  schedule    = var.job_schedule
  time_zone   = var.time_zone

  pubsub_target {
    topic_name = "projects/${var.project_id}/topics/${module.pubsub_topic.topic}"
    data       = var.message_data
  }
}

/******************************************
	PubSub Topic Definition
 *****************************************/

module "pubsub_topic" {
  source     = "terraform-google-modules/pubsub/google"
  version    = "~> 1.0"
  topic      = var.topic_name
  project_id = var.project_id
}

/******************************************
	Cloud Function Resource Definitions
 *****************************************/

resource "google_cloudfunctions_function" "main" {
  name                  = var.function_name
  source_archive_bucket = var.from_repo ? null : google_storage_bucket.main[0].name
  source_archive_object = var.from_repo ? null : google_storage_bucket_object.main[0].name
  description           = var.function_description
  available_memory_mb   = var.function_available_memory_mb
  timeout               = var.function_timeout_s
  entry_point           = var.function_entry_point

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = module.pubsub_topic.topic

    failure_policy {
      retry = var.function_event_trigger_failure_policy_retry
    }
  }

  labels                = var.function_labels
  runtime               = var.function_runtime
  environment_variables = var.function_environment_variables
  project               = var.project_id
  region                = var.region
  service_account_email = var.function_service_account_email
  dynamic "source_repository" {
    for_each = var.from_repo ? [var.repo_url] : []
    content {
      url = source_repository.value
    }
  }
}

data "archive_file" "main" {
  count       = var.from_repo ? 0 : 1
  type        = "zip"
  output_path = pathexpand("${var.function_source_directory}.zip")
  source_dir  = pathexpand(var.function_source_directory)
}

resource "random_string" "random_suffix" {
  count   = var.from_repo ? 0 : 1
  length  = 4
  upper   = "false"
  special = "false"
}

resource "google_storage_bucket" "main" {
  count = var.from_repo ? 0 : 1
  name = coalesce(
    var.bucket_name,
    "${var.project_id}-scheduled-function-${random_string.random_suffix[0].result}",
  )
  force_destroy = "true"
  location      = var.region
  project       = var.project_id
  storage_class = "REGIONAL"
  labels        = var.function_source_archive_bucket_labels
}

resource "google_storage_bucket_object" "main" {
  count               = var.from_repo ? 0 : 1
  name                = "event_function-${random_string.random_suffix[0].result}.zip"
  bucket              = google_storage_bucket.main[0].name
  source              = data.archive_file.main[0].output_path
  content_disposition = "attachment"
  content_encoding    = "gzip"
  content_type        = "application/zip"
}
