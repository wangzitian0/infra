# Vault Kubernetes Auth Backend Configuration
# Enables pods to authenticate with Vault using their ServiceAccount tokens.

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "config" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = "https://103.214.23.41:6443"
  kubernetes_ca_cert     = base64decode("LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUJkekNDQVIyZ0F3SUJBZ0lCQURBS0JnZ3Foa2pPUFFRREFqQWpNU0V3SHdZRFZRUUREQmhyTTNNdGMyVnkKZG1WeUxXTmhRREUzTmpRNE1qazVNak13SGhjTk1qVXhNakEwTURZek1qQXpXaGNOTXpVeE1qQXlNRFl6TWpBegpXakFqTVNFd0h3WURWUVFEREJock0zTXRjMlZ5ZG1TeUxXTmhRREUzTmpRNE1qazVNak13V1RBVEJnY3Foa2pPClBRSUJCZ2dxaGtqT1BRTUJCd05DQUFTcW5haDZxakJDbk1FZnJIWVhvbTZyYWN5bXI4MWdsMURiaWRxTFloZ0IKTStIb2k5RllBWEFNdkVtSko0Qk10R1hmOU5RczgwVnNuQzBRb3RCY2h6SmxvMEl3UURBT0JnTlZIUThCQWY4RQpCQU1DQXFRd0R3WURWUjBUQVFIL0JBVXdBd0VCL3pBZEJnTlZIUTRFRmdRVWY2SklBcXZ4eEtSR2lhTzNzQ2tvClhpNjlFWHN3Q2dZSUtvWkl6ajBFQXdJRFNBQXdSUUlnSldpMzU3MzRnUzRiaSt3T3JqYXh6M0kvVjNPTmhSTlIKVHRXelF0djBxZjRDSVFDeUZ2dnhFYnh0VDRkU0JBTUkvZExQNU1Mblp0WWVnOEY3Z3QybE5KTzJvQT09Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K")
  disable_iss_validation = true
}
