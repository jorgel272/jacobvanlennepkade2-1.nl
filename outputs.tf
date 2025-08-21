output "load_balancer_ip" {
  description = "The public IP address of the load balancer. Point your domain's A record here."
  value       = google_compute_global_address.static_ip.address
}

output "bucket_name" {
  description = "The name of the GCS bucket where you should upload your website files."
  value       = google_storage_bucket.website.name
}

output "site_url" {
  description = "The URL for your website."
  value       = "https://${var.domain_name}"
}

output "dns_name_servers" {
  description = "The authoritative name servers for your Cloud DNS zone. Update these at your domain registrar."
  value       = google_dns_managed_zone.primary.name_servers
}