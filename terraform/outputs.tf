# Output the IP addresses of all cluster nodes

output "control_plane_ip" {
  description = "IP address of the K3s control-plane node"
  value       = var.control_plane_ip
}

output "worker1_ip" {
  description = "IP address of worker-1"
  value       = var.worker1_ip
}

output "worker2_ip" {
  description = "IP address of worker-2"
  value       = var.worker2_ip
}
