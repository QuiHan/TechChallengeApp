provider "google" {
  credentials = file("credential.json")
  project     = var.project
  region      = var.region
  zone        = var.zone
}

resource "google_cloud_run_service" "default" {
  name                       = "cloudrun-techchallengeapp"
  location                   = var.region
  autogenerate_revision_name = true

  template {
    spec {
      containers {
        image = "gcr.io/${var.project}/techchallengeapp:latest"
        args  = [ "serve" ]

          ports {
            container_port = var.cloud_run_port
          }

          env {
              name  = "VTT_DBNAME"
              value = google_sql_database.database.name
          }

          env {
              name  = "VTT_DBHOST"
              value = google_sql_database_instance.postgres.private_ip_address
          }

          env {
              name  = "VTT_LISTENPORT"
              value = var.cloud_run_port
          }

          env {
              name  = "VTT_LISTENHOST"
              value = "0.0.0.0"
          }

          env {
              name  = "VTT_DBUSER"
              value = google_sql_user.users.name
          }

          env {
              name  = "VTT_DBPASSWORD"
              value = google_sql_user.users.password
          }
      }   
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"        = "2"
        "run.googleapis.com/client-name"          = "terraform"
        "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.connector.id
      } 
    }
  }
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
      members = [
        "allUsers",
      ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location    = google_cloud_run_service.default.location
  project     = google_cloud_run_service.default.project
  service     = google_cloud_run_service.default.name
  policy_data = data.google_iam_policy.noauth.policy_data
}

resource "google_vpc_access_connector" "connector" {
  name          = "vpc-con"
  ip_cidr_range = "10.8.0.0/28"
  network       = "default"
}

//Cloud SQL related configuration
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = "projects/${var.project}/global/networks/default"
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = "projects/${var.project}/global/networks/default"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "google_sql_database_instance" "postgres" {
  name             = "techappdbinstance"
  database_version = "POSTGRES_10"

  //Terraform doesn't automatically detect this dependency
  depends_on = [google_service_networking_connection.private_vpc_connection]
    
    settings {
      tier = "db-f1-micro"

      // Open public access for table creation and deletion, could be disabled after setup and
      // must be enabled during destroy
      ip_configuration {
        private_network = "projects/${var.project}/global/networks/default"
        authorized_networks {
          name  = "public"
          value = "0.0.0.0/0"
        }
      }
    }
    deletion_protection = false
}

resource "google_sql_database" "database" {
  name     = "techappdb"
  instance = google_sql_database_instance.postgres.name
}

resource "google_sql_user" "users" {
  name     = var.sql_username
  instance = google_sql_database_instance.postgres.name
  password = var.sql_password

  //Run createtaskstable sql script and seed data on creation
  provisioner "local-exec" {
    command = "PGPASSWORD=${self.password} psql --host=${google_sql_database_instance.postgres.public_ip_address} --username=${self.name} ${google_sql_database.database.name} < createtaskstable.sql"
  }

  //Remove Tasks table on destroy to avoid fail destruction
  provisioner "local-exec" {
    when    = destroy
    command = "PGPASSWORD=${self.password} psql --host=${google_sql_database_instance.postgres.public_ip_address} --username=${self.name} ${google_sql_database.database.name} -c '\\x' -c 'DROP TABLE tasks;'"
  }
}