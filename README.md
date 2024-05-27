Kubernetes the lard way
=====

The TF code creates all the certs needed for the k8s components and provisions Virtualbox vms for the server and the nodes.
An ansible inventory yaml is generated from these ips with pod subnets assigned to the nodes.

To provision the services on the VMs `run_playbook.sh` needs to be executed. After it's finished the cluster is fully provisioned.
