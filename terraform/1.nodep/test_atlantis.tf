# Test resource for Atlantis verification
# This file exists to verify Atlantis is working correctly.
# Verification timestamp: 2025-12-06
resource "null_resource" "atlantis_test" {
  triggers = {
    # Change this value to trigger Atlantis plan
    test_trigger = "atlantis-bot-verification-v2"
  }
}
