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

terraform {
  required_version = ">= 0.12"
}

provider "google-beta" {
  version = "~> 2.5"
  project = var.project_id
  region  = var.region
}

// cloud source repository
resource "google_sourcerepo_repository" "default" {
  name    = "tester"
  project = var.project_id
}

resource "null_resource" "push_to_git" {
  triggers = {
    time = timestamp()
  }
  provisioner "local-exec" {
    command = "${path.module}/git-setup.sh"

    environment = {
      URL        = google_sourcerepo_repository.default.url
      LOCAL_REPO = "${path.module}/function_source"
    }
  }
  depends_on = [
    google_sourcerepo_repository.default
  ]
}

module "source_repo_example" {
  providers = {
    google = google-beta
  }

  source               = "../../"
  function_runtime     = "python37"
  project_id           = var.project_id
  job_name             = "hello-world"
  job_schedule         = "*/5 * * * *"
  function_entry_point = "hello_world"
  function_name        = "testfunction-foo"
  region               = var.region
  topic_name           = "source_repo_example_topic"
  from_repo            = true
  repo_url             = "https://source.developers.google.com/projects/${var.project_id}/repos/${google_sourcerepo_repository.default.name}/moveable-aliases/*/paths//"
}
