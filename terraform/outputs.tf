############################################
# Outputs: Внешний и внутренний IP машин
############################################

output "samba_proxy_external_ip" {
  description = "External (public) IP of the samba-proxy instance"
  value       = yandex_compute_instance.samba_proxy.network_interface.0.nat_ip_address
}

output "samba_proxy_internal_ip" {
  description = "Internal (private) IP of the samba-proxy instance"
  value       = yandex_compute_instance.samba_proxy.network_interface.0.ip_address
}

output "web_node_1_external_ip" {
  description = "External IP of web-node-1"
  value       = yandex_compute_instance.web_node_1.network_interface.0.nat_ip_address
}

output "web_node_1_internal_ip" {
  description = "Internal IP of web-node-1"
  value       = yandex_compute_instance.web_node_1.network_interface.0.ip_address
}

output "web_node_2_external_ip" {
  description = "External IP of web-node-2"
  value       = yandex_compute_instance.web_node_2.network_interface.0.nat_ip_address
}

output "web_node_2_internal_ip" {
  description = "Internal IP of web-node-2"
  value       = yandex_compute_instance.web_node_2.network_interface.0.ip_address
}
