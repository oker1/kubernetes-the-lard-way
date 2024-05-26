resource "tls_private_key" "ca" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem = tls_private_key.ca.private_key_pem

  subject {
    common_name  = "ktla.com"
    organization = "Kubernetes The Lard Way Inc."
  }

  validity_period_hours = 365 * 24

  is_ca_certificate = true

  allowed_uses = [
    "crl_signing",
    "cert_signing",
  ]
}

resource "local_file" "ca_pk" {
  filename = "${path.module}/ansible/certs/ca.key"
  content = tls_private_key.ca.private_key_pem
}

resource "local_file" "ca_crt" {
  filename = "${path.module}/ansible//certs/ca.crt"
  content = tls_self_signed_cert.ca.cert_pem
}

locals {
    node_cert_names = { for i in range(var.node_count) : "node-${i}" => { "CN" = "system:node:node-${i}", "O" = "system:nodes" } }
    oneof_cert_names = {
        "admin" = { "CN" = "admin", "O" = "system:masters" },
        "kube-proxy" = { "CN" = "kube-proxy" },
        "kube-scheduler" = { "CN" = "system:kube-scheduler", "O" = "system:system:kube-scheduler" },
        "kube-controller-manager" = { "CN" = "system:kube-controller-manager", "O" = "system:kube-controller-manager" },
        "kube-api-server" = {
          "CN" = "kubernetes",
          "dns_names" = [
            "kubernetes",
            "kubernetes.default",
            "kubernetes.default.svc",
            "kubernetes.default.svc.cluster",
            "kubernetes.svc.cluster.local",
            "server.kubernetes.local",
            "api-server.kubernetes.local",
          ]
        }
        "service-accounts" = { "CN" = "service-accounts" },
    }
    certs = merge(local.oneof_cert_names, local.node_cert_names)
}

resource "tls_private_key" "pk" {
  for_each = local.certs
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "cr" {
  for_each = local.certs
  private_key_pem = tls_private_key.pk[each.key].private_key_pem

  dns_names = lookup(each.value, "dns_names", [])

  subject {
    common_name  = each.value["CN"]
    organization = lookup(each.value, "O", "Kubernetes The Lard Way Inc.")
  }
}

resource "tls_locally_signed_cert" "cert" {
  for_each = local.certs
  cert_request_pem   = tls_cert_request.cr[each.key].cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem
  set_subject_key_id = true

  validity_period_hours = 365 * 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
    "server_auth", # todo: only server
  ]
}

resource "local_file" "pk" {
  for_each = local.certs
  filename = "${path.module}/ansible/certs/${each.key}.key"
  content = tls_private_key.pk[each.key].private_key_pem
}

resource "local_file" "crt" {
  for_each = local.certs
  filename = "${path.module}/ansible/certs/${each.key}.crt"
  content = tls_locally_signed_cert.cert[each.key].cert_pem
}