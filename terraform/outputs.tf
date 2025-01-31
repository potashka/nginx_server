output "vm1_external_ip" {
  value = yandex_compute_instance.vm1.network_interface.0.nat_ip_address
}

output "vm1_internal_ip" {
  value = yandex_compute_instance.vm1.network_interface.0.ip_address
}

output "vm2_external_ip" {
  value = yandex_compute_instance.vm2.network_interface.0.nat_ip_address
}

output "vm2_internal_ip" {
  value = yandex_compute_instance.vm2.network_interface.0.ip_address
}

output "vm3_external_ip" {
  value = yandex_compute_instance.vm3.network_interface.0.nat_ip_address
}

output "vm3_internal_ip" {
  value = yandex_compute_instance.vm3.network_interface.0.ip_address
}
