# Jacobvanlennepkade.nl - v1.0 20082025
# This is the beginning of the life of our Jacob van Lennepkade 2-1 website,
# Hosted on Google Cloud Storage Bucket with ELB for SSL encryption and Google DNS.
# Resources are created with Terraform and code is stored on Github.
# Website code and required GCP resources are deployed by Github Action which runs on code change on commit to main branch.

# 0. Enable the Google Compute Engine API
# Required for creating resources like static IP addresses, forwarding rules, and proxies.
resource "google_project_service" "compute_api" {
  project = var.gcp_project_id
  service = "compute.googleapis.com"

  # Prevents Terraform from disabling the API when the resource is removed from the config.
  disable_on_destroy = false
}

# 0. Enable the Google Cloud DNS API
# Required for managing DNS zones and record sets for your domain.
resource "google_project_service" "dns_api" {
  project = var.gcp_project_id
  service = "dns.googleapis.com"

  # Prevents Terraform from disabling the API when the resource is removed from the config.
  disable_on_destroy = false
}

# 0. Enable the Google Cloud Domains API
# Required for registering and managing domain names within GCP.
resource "google_project_service" "cloud_domains_api" {
  project = var.gcp_project_id
  service = "domains.googleapis.com"

  # Prevents Terraform from disabling the API when the resource is removed from the config.
  disable_on_destroy = false
}

# 1. Create the GCS bucket to hold website content
resource "google_storage_bucket" "website" {
  name          = var.bucket_name
  location      = var.region
  force_destroy = true

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }
}

# 2. Make the bucket public by granting all users the Storage Object Viewer role
resource "google_storage_bucket_iam_member" "public_access" {
  bucket = google_storage_bucket.website.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}

# --- Load Balancer Components ---

# 3. Reserve a global static IP address for the ELB
resource "google_compute_global_address" "static_ip" {
  name = "website-static-ip"
}

# 4. Create a Cloud DNS managed zone for your domain
resource "google_dns_managed_zone" "primary" {
  name = "primary-zone"
  # The DNS name must end with a trailing dot
  dns_name    = "${var.domain_name}."
  description = "Managed zone for ${var.domain_name}"
}

# 5. Create the 'A' record to point your domain to the load balancer
resource "google_dns_record_set" "a_record" {
  # The name must end with a trailing dot
  name         = google_dns_managed_zone.primary.dns_name
  managed_zone = google_dns_managed_zone.primary.name
  type         = "A"
  ttl          = 300 # Time-to-live in seconds

  # This automatically links the A record to the load balancer's IP
  rrdatas = [google_compute_global_address.static_ip.address]
}


# 6. Create a Google-managed SSL certificate for the custom domain
resource "google_compute_managed_ssl_certificate" "ssl_cert" {
  name = "website-ssl-cert"
  managed {
    domains = [var.domain_name]
  }

  # This depends_on block ensures that Cloud DNS record has been created before SSL certificate is generated.
  depends_on = [
    google_dns_managed_zone.primary
  ]
}

# 7. Create a backend bucket for the load balancer to point to GCS
resource "google_compute_backend_bucket" "website_backend" {
  name        = "website-backend-bucket"
  description = "Backend for the static website bucket"
  bucket_name = google_storage_bucket.website.name
  enable_cdn  = true
}

# 8. Create a URL map to route all incoming requests to the backend bucket
resource "google_compute_url_map" "default" {
  name            = "website-url-map"
  default_service = google_compute_backend_bucket.website_backend.id
}

# 9. Create the target HTTPS proxy to route requests to the URL map
resource "google_compute_target_https_proxy" "https_proxy" {
  name             = "website-https-proxy"
  url_map          = google_compute_url_map.default.id
  ssl_certificates = [google_compute_managed_ssl_certificate.ssl_cert.id]
}

# 10. Create the global forwarding rule to route incoming requests to the proxy
resource "google_compute_global_forwarding_rule" "https_forwarding_rule" {
  name                  = "website-forwarding-rule"
  target                = google_compute_target_https_proxy.https_proxy.id
  ip_address            = google_compute_global_address.static_ip.address
  port_range            = "443"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# 11. Upload website files

# Find all image files in the local 'photos' directory
locals {
  # This creates a list of all files ending with common image extensions.
  photo_files = fileset("${path.module}/photos", "**/*.{jpg,jpeg,png,gif,webp}")
}

# Upload the main static files (HTML, CSS, JS)
resource "google_storage_bucket_object" "static_files" {
  # We create one object for each of these files
  for_each = {
    "index.html" = "text/html"
    "style.css"  = "text/css"
    "gallery.js" = "application/javascript"
  }

  name          = each.key
  bucket        = google_storage_bucket.website.name
  source        = "${path.module}/${each.key}"
  content_type  = each.value
  cache_control = "public, max-age=300"

  # Tracking the file's hash.
  metadata = {
    content-md5 = filemd5("${path.module}/${each.key}")
  }

  # This depends_on block ensures the bucket is made public *before* we upload files.
  depends_on = [
    google_storage_bucket_iam_member.public_access
  ]
}

# Upload all photos from the 'photos' directory
resource "google_storage_bucket_object" "photos" {
  # This loops through the list of photo files we found earlier
  for_each = local.photo_files

  name          = "photos/${each.value}" # Uploads to the 'photos/' folder in the bucket
  bucket        = google_storage_bucket.website.name
  source        = "${path.module}/photos/${each.value}"
  cache_control = "public, max-age=300"

  # Explicitly tracks each photo's hash.
  metadata = {
    content-md5 = filemd5("${path.module}/photos/${each.value}")
  }

  depends_on = [
    google_storage_bucket_iam_member.public_access
  ]
}