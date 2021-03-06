variable "do_token" {}
variable "cloudflare_email" {}
variable "cloudflare_token" {}

provider "digitalocean" {
  token = var.do_token
}

provider "cloudflare" {
  version = "~> 1.0"
  email = var.cloudflare_email
  token = var.cloudflare_token
}


data "digitalocean_ssh_key" "ondrejsika" {
  name = "ondrejsika"
}

resource "digitalocean_droplet" "rancher" {
  image  = "rancheros"
  name   = "rancher"
  region = "fra1"
  size   = "s-4vcpu-8gb"
  ssh_keys = [
    data.digitalocean_ssh_key.ondrejsika.id
  ]

  connection {
    user        = "rancher"
    type        = "ssh"
    host        = self.ipv4_address
  }

  provisioner "remote-exec" {
    inline = [
      "docker pull -q rancher/rancher:latest",
      "docker run --name rancher -d --restart=always -p 80:80 -p 443:443 rancher/rancher:latest --acme-domain rancher.sikademo.com",
    ]
  }
}

resource "cloudflare_record" "droplet" {
  domain = "sikademo.com"
  name   = "rancher"
  value  = digitalocean_droplet.rancher.ipv4_address
  type   = "A"
  proxied = false
}

provider "rancher2" {
  alias = "bootstrap"

  api_url   = "https://${cloudflare_record.droplet.hostname}"
  bootstrap = true
}

resource "rancher2_bootstrap" "admin" {
  provider = rancher2.bootstrap

  password = "asdfasdf"
  telemetry = true
}

output "rancher_api_url" {
  value = rancher2_bootstrap.admin.url
}

output "rancher_token_key" {
  value = rancher2_bootstrap.admin.token
  sensitive = true
}
