terraform {
  required_providers {
    virtualbox = {
      source = "terra-farm/virtualbox"
      version = "0.2.2-alpha.1"
    }
    local = {
      source = "hashicorp/local"
      version = "2.5.1"
    }
    tls = {
      source = "hashicorp/tls"
      version = "4.0.5"
    }
  }
}

variable "node_count" {
  default = 2
}

variable "ssh_user" {
  default = "vagrant"
}

variable "ssh_key_file" {
  default = "./vagrant-key"
}

variable "host_interface" {
  default = "wlo1"
}

resource "virtualbox_vm" "server" {
  name      = "server"
  image     = "virtualbox.box" # https://app.vagrantup.com/bento/boxes/ubuntu-22.04/versions/202401.31.0/providers/virtualbox.box
  cpus      = 1
  memory    = "1.0 gib"

  network_adapter {
    type           = "bridged"
    host_interface = var.host_interface
  }
}

resource "virtualbox_vm" "node" {
  count     = var.node_count
  name      = format("node-%01d", count.index)
  image     = "virtualbox.box"
  cpus      = 2
  memory    = "2.0 gib"

  network_adapter {
    type           = "bridged"
    host_interface = var.host_interface
  }
}

locals {
  server_ip = virtualbox_vm.server.network_adapter.0.ipv4_address
  node_host_ips = { for k, v in virtualbox_vm.node: v.name =>
    {
      ansible_host = v.network_adapter.0.ipv4_address
      pod_subnet = "10.200.${k}.0/24"
    }
  }
}

output "server_ip" {
  value = local.server_ip
}

output "node_ips" {
  value = virtualbox_vm.node.*.network_adapter.0.ipv4_address
}

resource "local_file" "ansible-script" {
  content = "ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ${var.ssh_user} --private-key ${var.ssh_key_file} -i '${local_file.hosts.filename}' ansible/playbook-cluster.yml"
  filename = "${path.module}/run_playbook.sh"
}


resource "local_file" "hosts" {
  content  = yamlencode({
    nodes = { hosts = local.node_host_ips },
    servers = { hosts = { (virtualbox_vm.server.name) = { ansible_host = local.server_ip } } }
  })
  filename = "${path.module}/ansible/hosts.yaml"
}