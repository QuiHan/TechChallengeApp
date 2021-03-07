//Variables to make
//Port to listen for cloud run and app
//SQL username and password
variable "gcp_service_list" {
  description = "List of GCP service to be enabled for a project."
  type        = list
}

gcp_service_list = [
  "compute.googleapis.com",     # Compute Engine API
  "cloudresourcemanager.googleapis.com",   # Cloud Resource Manager API
  "vpcaccess.googleapis.com",         # Serverless VPC Access API
  "servicenetworking.googleapis.com",     # Serverless Networking API
  "containerregistry.googleapis.com",        # Container Registry API
  "sqladmin.googleapis.com",           # Cloud SQL Admin API
  "run.googleapis.com",               # Cloud Run Admin API
  "cloudapis.googleapis.com",         # Google Cloud APIs"
  "iam.googleapis.com",               # Identity and Access Management (IAM) API
  "iamcredentials.googleapis.com"    # IAM Service Account Credentials API
]

provider "google" {
    credentials = file("credential.json")
    //project = var.project
    //region = var.region
    //zone = var.zone
    project = "serviantest-306910"
    region = "australia-southeast1"
    zone = "australia-southeast1-b"

}

resource "google_cloud_run_service" "default" {
    name     = "cloudrun-srv"
    //location = region
    location = "australia-southeast1"
  
    template {
      spec {
          containers {
              //image = "us-docker.pkg.dev/cloudrun/container/hello"
            image = "gcr.io/serviantest-306910/techchallengeapp:latest"
            args = [ "serve" ]
            
            env {
                name = "VTT_DBNAME"
                value = google_sql_database.database.name
            }
            env {
                name = "VTT_DBHOST"
                value = google_sql_database_instance.postgres.private_ip_address
            }
            env {
                name = "VTT_LISTENPORT"
                value = "8080"
            }
            env {
                name = "VTT_LISTENHOST"
                value = "0.0.0.0"
            }
            env {
                name = "VTT_DBUSER"
                value = google_sql_user.users.name
            }
            env {
                name = "VTT_DBPASSWORD"
                value = google_sql_user.users.password
            }

            
          }
          
      }
    

    metadata {
      annotations = {
          "autoscaling.knative.dev/maxScale"        = "2"
          //"run.googleapis.com/cloudsql-instances"   = google_sql_database_instance.instance.connection_name
          "run.googleapis.com/client-name"          = "terraform"
          //"run.googleapis.com/vpc-access-connector" = concat("projects/${data.google_settings.current.name}/locations/${data.google_settings.current.region}/connectors/",google_vpc_access_connector.connector.name)
          "run.googleapis.com/vpc-access-connector" = google_vpc_access_connector.connector.id
        } 
    }
    }

    autogenerate_revision_name = true
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
    location = google_cloud_run_service.default.location
    project = google_cloud_run_service.default.project
    service = google_cloud_run_service.default.name

    policy_data = data.google_iam_policy.noauth.policy_data
}

resource "google_vpc_access_connector" "connector" {
  name          = "vpc-con"
  //ip_cidr_range = "10.8.0.0/28"
  ip_cidr_range = "10.7.0.0/28"
  network       = "default"
}

//Cloud SQL related configuration
resource "google_compute_global_address" "private_ip_address" {
  name          = "private-ip-address"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  //network       = google_compute_network.private_network.id
  network       = "projects/serviantest-306910/global/networks/default"
}

resource "google_service_networking_connection" "private_vpc_connection" {
  //network                 = google_compute_network.private_network.id
  network                 = "projects/serviantest-306910/global/networks/default"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

resource "google_sql_database_instance" "postgres" {
  name = "techappdbinstance"
  database_version = "POSTGRES_10"

  depends_on = [google_service_networking_connection.private_vpc_connection]
    
    settings {
      tier = "db-f1-micro"

      ip_configuration {
        //private_network = google_compute_network.private_network.id
        private_network = "projects/serviantest-306910/global/networks/default"
        authorized_networks {
          name = "public"
          value = "0.0.0.0/0"
        }
      }
    }
    deletion_protection = false
}

resource "google_sql_user" "users" {
  //depends_on = [ google_sql_database.database ]
  name     = "app"
  instance = google_sql_database_instance.postgres.name
  password = "admin"

  provisioner "local-exec" {
    command = "PGPASSWORD=${self.password} psql --host=${google_sql_database_instance.postgres.public_ip_address} --username=${self.name} ${google_sql_database.database.name} < createtaskstable.sql"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "PGPASSWORD=${self.password} psql --host=${google_sql_database_instance.postgres.public_ip_address} --username=${self.name} ${google_sql_database.database.name} -c '\\x' -c 'DROP TABLE tasks;'"
  }
}

resource "google_sql_database" "database" {
  name     = "techappdb"
  instance = google_sql_database_instance.postgres.name
}