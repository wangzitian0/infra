resource "null_resource" "atlantis_test" {
  triggers = {
    timestamp = timestamp()
  }

  provisioner "local-exec" {
    command = "echo 'Atlantis is working! Verification ID: ${timestamp()}'"
  }
}
