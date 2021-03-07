output "cloud_run_url" {
  description = "Cloud Run URL to browse app"
  value       = google_cloud_run_service.default.status.url
}