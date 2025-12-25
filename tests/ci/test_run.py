import unittest
from unittest.mock import patch, MagicMock
import sys
import os

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../tools")))

from ci.commands import run

class TestRun(unittest.TestCase):
    def test_parse_command(self):
        # Test bootstrap
        self.assertEqual(run.parse_command("/bootstrap plan"), ("bootstrap-plan", []))
        self.assertEqual(run.parse_command("/bootstrap apply"), ("bootstrap-apply", []))
        
        # Test plan
        self.assertEqual(run.parse_command("/plan"), ("plan", ["all"]))
        self.assertEqual(run.parse_command("/plan layer1"), ("plan", ["layer1"]))
        
        # Test apply
        self.assertEqual(run.parse_command("/apply"), ("apply", ["all"]))
        self.assertEqual(run.parse_command("/apply layer1 layer2"), ("apply", ["layer1", "layer2"]))
        
        # Test new commands
        self.assertEqual(run.parse_command("/e2e"), ("e2e", []))
        self.assertEqual(run.parse_command("/review"), ("review", []))
        self.assertEqual(run.parse_command("/help"), ("help", []))
        
        # Test invalid
        self.assertEqual(run.parse_command("hello world"), (None, []))

    @patch("ci.commands.run.GitHubClient") # Correctly patch the symbol imported in run.py
    @patch("ci.commands.run.parse_event")
    @patch("ci.commands.run.get_pr_number")
    def test_run_issue_comment(self, mock_pr, mock_parse, mock_gh):
        # Setup
        mock_parse.return_value = {
            "name": "issue_comment",
            "data": {
                "comment": {"body": "/e2e"},
                "issue": {"number": 123}
            }
        }
        mock_pr.return_value = 123
        
        # Mock GitHub client inside run.py
        gh_instance = mock_gh.return_value
        gh_instance.get_pr.return_value.head_ref = "feature-branch"
        
        # Run
        with patch("subprocess.run") as mock_sub, \
             patch("ci.commands.run.Dashboard") as mock_dashboard: # Patch Dashboard
            
            mock_sub.return_value.returncode = 0
            ret = run.run(None)
            
            # Verify
            self.assertEqual(ret, 0)
            mock_sub.assert_called()
            args = mock_sub.call_args[0][0]
            self.assertIn("e2e-tests.yml", args)
            self.assertIn("feature-branch", args)
            
            # Verify Dashboard interactions
            mock_dashboard.return_value.update_stage.assert_any_call("e2e", "running", link=unittest.mock.ANY)
            mock_dashboard.return_value.update_stage.assert_any_call("e2e", "success")
            mock_dashboard.return_value.save.assert_called()

if __name__ == "__main__":
    unittest.main()
