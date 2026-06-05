# Variables for K3s cluster VM provisioning

variable "vm_image_path" {
  description = "Path to the Ubuntu 22.04 cloud image on the libvirt host"
  type        = string
  default     = "/var/lib/libvirt/images/jammy-server-cloudimg-amd64.img"
}

variable "network_cidr" {
  description = "CIDR block for the K3s libvirt network"
  type        = string
  default     = "192.168.100.0/24"
}

variable "control_plane_ip" {
  description = "Static IP address for the control-plane node"
  type        = string
  default     = "192.168.100.10"
}

variable "worker1_ip" {
  description = "Static IP address for worker-1"
  type        = string
  default     = "192.168.100.11"
}

variable "worker2_ip" {
  description = "Static IP address for worker-2"
  type        = string
  default     = "192.168.100.12"
}

variable "ssh_public_key" {
  description = "SSH public key to inject into VMs via cloud-init"
  type        = string
}

variable "control_plane_vcpu" {
  description = "Number of vCPUs for the control-plane node"
  type        = number
  default     = 2
}

variable "control_plane_memory" {
  description = "RAM in MiB for the control-plane node"
  type        = number
  default     = 3072
}

variable "control_plane_disk_size" {
  description = "Disk size in bytes for the control-plane node (20 Go)"
  type        = number
  default     = 21474836480
}

variable "worker_vcpu" {
  description = "Number of vCPUs per worker node"
  type        = number
  default     = 2
}

variable "worker_memory" {
  description = "RAM in MiB per worker node"
  type        = number
  default     = 4096
}

variable "worker_disk_size" {
  description = "Disk size in bytes per worker node (30 Go)"
  type        = number
  default     = 32212254720
}
