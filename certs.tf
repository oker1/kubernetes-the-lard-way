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
    certs = toset([
        "admin",
        "kube-proxy",
        "kube-scheduler",
        "kube-controller-manager",
        "kube-api-server",
        "service-accounts",
    ])
}

resource "tls_private_key" "pk" {
  for_each = local.certs
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "tls_cert_request" "cr" {
  for_each = local.certs
  private_key_pem = tls_private_key.pk[each.value].private_key_pem

  subject {
    common_name  = each.value
    organization = "Kubernetes The Lard Way Inc."
  }
}

resource "tls_locally_signed_cert" "cert" {
  for_each = local.certs
  cert_request_pem   = tls_cert_request.cr[each.value].cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem
  set_subject_key_id = true

  validity_period_hours = 365 * 24

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

resource "local_file" "pk" {
  for_each = local.certs
  filename = "${path.module}/ansible//certs/${each.value}.key"
  content = tls_private_key.pk[each.value].private_key_pem
}

resource "local_file" "crt" {
  for_each = local.certs
  filename = "${path.module}/ansible//certs/${each.value}.crt"
  content = tls_locally_signed_cert.cert[each.value].cert_pem
}