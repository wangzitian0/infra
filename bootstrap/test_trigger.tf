resource "null_resource" "ci_test" {
  triggers = {
    trigger = "${timestamp()}"
  }
  provisioner "local-exec" {
    command = "echo 'CI Slash Command Verification'"
  }
}
