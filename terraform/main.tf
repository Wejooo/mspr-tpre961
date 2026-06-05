terraform {
  required_version = ">= 1.15.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.6"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

# ---------- Storage pool ----------

resource "libvirt_pool" "k3s" {
  name = "k3s-pool"
  type = "dir"
  path = "/var/lib/libvirt/images/k3s-pool"
}

# ---------- Network ----------

resource "libvirt_network" "k3s_net" {
  name      = "k3s-net"
  mode      = "nat"
  domain    = "k3s.local"
  autostart = true

  addresses = [var.network_cidr]

  dns {
    enabled = true
  }

  dhcp { enabled = false }
}

# ---------- Base volume (Ubuntu 22.04 cloud image) ----------

resource "libvirt_volume" "ubuntu_base" {
  name   = "ubuntu-22.04-base.qcow2"
  pool   = libvirt_pool.k3s.name
  source = var.vm_image_path
  format = "qcow2"
}

# ---------- Control-plane ----------

resource "libvirt_volume" "control_plane_disk" {
  name           = "control-plane.qcow2"
  pool           = libvirt_pool.k3s.name
  base_volume_id = libvirt_volume.ubuntu_base.id
  size           = var.control_plane_disk_size
  format         = "qcow2"
}

resource "libvirt_cloudinit_disk" "control_plane_init" {
  name = "control-plane-cloudinit.iso"
  pool = libvirt_pool.k3s.name

  user_data = templatefile("${path.module}/cloud-init/control-plane.yml", {
    ssh_public_key = var.ssh_public_key
  })

  network_config = templatefile("${path.module}/cloud-init/network-config.yml", {
    ip_address = var.control_plane_ip
  })
}

resource "libvirt_domain" "control_plane" {
  name   = "control-plane"
  memory = var.control_plane_memory
  vcpu   = var.control_plane_vcpu

  cloudinit = libvirt_cloudinit_disk.control_plane_init.id

  network_interface {
    network_id     = libvirt_network.k3s_net.id
    addresses      = [var.control_plane_ip]
    wait_for_lease = false
  }

  disk {
    volume_id = libvirt_volume.control_plane_disk.id
  }

  # Required for Ubuntu cloud images
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}

# ---------- Worker 1 ----------

resource "libvirt_volume" "worker1_disk" {
  name           = "worker-1.qcow2"
  pool           = libvirt_pool.k3s.name
  base_volume_id = libvirt_volume.ubuntu_base.id
  size           = var.worker_disk_size
  format         = "qcow2"
}

resource "libvirt_cloudinit_disk" "worker1_init" {
  name = "worker-1-cloudinit.iso"
  pool = libvirt_pool.k3s.name

  user_data = templatefile("${path.module}/cloud-init/worker.yml", {
    hostname       = "worker-1"
    ssh_public_key = var.ssh_public_key
  })

  network_config = templatefile("${path.module}/cloud-init/network-config.yml", {
    ip_address = var.worker1_ip
  })
}

resource "libvirt_domain" "worker1" {
  name   = "worker-1"
  memory = var.worker_memory
  vcpu   = var.worker_vcpu

  cloudinit = libvirt_cloudinit_disk.worker1_init.id

  network_interface {
    network_id     = libvirt_network.k3s_net.id
    addresses      = [var.worker1_ip]
    wait_for_lease = false
  }

  disk {
    volume_id = libvirt_volume.worker1_disk.id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}

# ---------- Worker 2 ----------

resource "libvirt_volume" "worker2_disk" {
  name           = "worker-2.qcow2"
  pool           = libvirt_pool.k3s.name
  base_volume_id = libvirt_volume.ubuntu_base.id
  size           = var.worker_disk_size
  format         = "qcow2"
}

resource "libvirt_cloudinit_disk" "worker2_init" {
  name = "worker-2-cloudinit.iso"
  pool = libvirt_pool.k3s.name

  user_data = templatefile("${path.module}/cloud-init/worker.yml", {
    hostname       = "worker-2"
    ssh_public_key = var.ssh_public_key
  })

  network_config = templatefile("${path.module}/cloud-init/network-config.yml", {
    ip_address = var.worker2_ip
  })
}

resource "libvirt_domain" "worker2" {
  name   = "worker-2"
  memory = var.worker_memory
  vcpu   = var.worker_vcpu

  cloudinit = libvirt_cloudinit_disk.worker2_init.id

  network_interface {
    network_id     = libvirt_network.k3s_net.id
    addresses      = [var.worker2_ip]
    wait_for_lease = false
  }

  disk {
    volume_id = libvirt_volume.worker2_disk.id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}
