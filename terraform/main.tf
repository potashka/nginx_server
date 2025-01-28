##################################################
#  1. Настройка провайдера Yandex Cloud
##################################################
provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_zone
}

##################################################
#  2. Создаём виртуальную сеть (VPC) и подсеть
##################################################
resource "yandex_vpc_network" "demo_network" {
  name = "demo-network"
}

resource "yandex_vpc_subnet" "demo_subnet" {
  name           = "demo-subnet"
  zone           = var.yc_zone
  network_id     = yandex_vpc_network.demo_network.id
  v4_cidr_blocks = ["10.128.0.0/24"]
}

##################################################
#  3. Опционально: data-ресурс, если нужно
#     искать образ по ID/семейству/фильтру
##################################################

data "yandex_compute_image" "custom_image" {
  image_id = var.instance_image
}

##################################################
#  4. Создаём три ВМ:
#     vm1, vm2, vm3
##################################################
resource "yandex_compute_instance" "vm1" {
  name        = "samba-proxy"
  platform_id = "standard-v2"

  resources {
    cores  = 1
    memory = 1
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.custom_image.id
      size     = 20
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.demo_subnet.id
    nat       = true  
  }

  metadata = {
    ssh-keys = "${var.instance_user}:${var.ssh_public_key}"
  }
}

resource "yandex_compute_instance" "vm2" {
  name        = "web-node-1"
  platform_id = "standard-v2"

  resources {
    cores  = 1
    memory = 1
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.custom_image.id
      size     = 20
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.demo_subnet.id
    nat       = true
  }

  metadata = {
    ssh-keys = "${var.instance_user}:${var.ssh_public_key}"
  }
}

resource "yandex_compute_instance" "vm3" {
  name        = "web-node-2"
  platform_id = "standard-v2"

  resources {
    cores  = 1
    memory = 1
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.custom_image.id
      size     = 20
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.demo_subnet.id
    nat       = true
  }

  metadata = {
    ssh-keys = "${var.instance_user}:${var.ssh_public_key}"
  }
}
