# Local state for offline assessment validation.
# For shared/team deployment, migrate to remote S3 backend using prod.backend.hcl.example.
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
