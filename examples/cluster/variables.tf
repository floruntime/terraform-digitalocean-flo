variable "do_token" {
  type        = string
  description = "DigitalOcean API token."
  sensitive   = true
}

variable "ssh_key_name" {
  type        = string
  description = "Name of an SSH key already uploaded to your DigitalOcean account."
}

variable "region" {
  type        = string
  description = "DigitalOcean region. All cluster nodes go in the same region."
  default     = "lon1"
}

variable "operator_cidrs" {
  type        = list(string)
  description = "CIDR blocks allowed to reach the dashboard."
  default     = ["0.0.0.0/0", "::/0"]
}
