variable "project" { 
    description = "Project to build infrastructure"
}

variable "credentials_file" {
    description = "Path to service account credential file"
    default     = "credential.json"
}

variable "region" {
    default = "australia-southeast1"
}

variable "zone" {
    default = "australia-southeast1-b"
}

variable "cloud_run_port" {
    description = "Port to run container"
    default = "8080"
}

variable "sql_username" {
    description = "Database administrator username"
    default     = "app"
    sensitive   = true
}

variable "sql_password" {
    description = "Database administrator password"
    default     = "serviantest"
    sensitive   = true
}