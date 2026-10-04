terraform {
  required_version = ">= 1.9.8"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.13"
    }
  }
}

provider "yandex" {
}

resource "yandex_vpc_address" "friend-ip" {
  name = "friend-ip"
  external_ipv4_address {
    zone_id = "ru-central1-a"
  }
}


resource "yandex_vpc_network" "vps_network" {
  name = "vps-network"
}

resource "yandex_vpc_subnet" "vps_subnet" {
  name           = "vps-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.vps_network.id
  v4_cidr_blocks = ["10.5.0.0/24"]
}

resource "yandex_vpc_security_group" "vps_sg" {
  name       = "vps-security-group"
  network_id = yandex_vpc_network.vps_network.id

  ingress {
    protocol       = "TCP"
    description    = "Allow SSH"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
  }

  ingress {
    protocol       = "TCP"
    description    = "Allow HTTP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  egress {
    protocol       = "ANY"
    description    = "Allow outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 0
    to_port        = 65535
  }
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "vps" {
  name                      = "ubuntu-vps"
  platform_id               = "standard-v3"
  zone                      = "ru-central1-a"
  allow_recreate            = true
  allow_stopping_for_update = true

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 20
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.vps_subnet.id
    nat                = true
    nat_ip_address     = yandex_vpc_address.friend-ip.external_ipv4_address[0].address
    security_group_ids = [yandex_vpc_security_group.vps_sg.id] # Привязываем SG здесь
  }

  lifecycle {
    create_before_destroy = true
  }

  metadata = {
    ssh-keys  = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
    user-data = templatefile("hello.tftpl", { owner = "lawrence", friends = ["Roma", "Kirill", "Egor", "Alex"] })
  }
}

output "server_ip" {
  value       = yandex_compute_instance.vps.network_interface[0].nat_ip_address
  description = "There must be an IP of the server"
}
output "elastic_ip" {
  value       = yandex_compute_instance.vps.network_interface[0].nat_ip_address
  description = "Expected as equal server_ip"
}
output "friend-ip" {
  value = yandex_vpc_address.friend-ip.external_ipv4_address[0].address
}

