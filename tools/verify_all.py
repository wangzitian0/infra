#!/usr/bin/env python3
import sys
import os
import json
import unittest
from unittest.mock import patch, mock_open, MagicMock

# Add tools to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../tools")))

from ci.commands import parse

class TestFullVerification(unittest.TestCase):
    def setUp(self):
        self.output_mock = mock_open()
        print(f"\n🧪 Testing Scenario: {self._testMethodName} ...")

    @patch("builtins.open")
    @patch("os.path.exists")
    @patch("os.environ.get")
    def run_scenario(self, env_vars, event_data, expected_mode, expected_cmd, mock_env, mock_exists, mock_file):
        # Mock Environment
        mock_exists.return_value = True
        mock_env.side_effect = lambda k, d="": {**env_vars, "GITHUB_EVENT_PATH": "/tmp/event.json", "GITHUB_OUTPUT": "/tmp/output"}.get(k, d)
        
        # Mock File I/O
        read_mock = mock_open(read_data=json.dumps(event_data))
        output_handle = MagicMock()
        output_file_mock = MagicMock()
        output_file_mock.__enter__.return_value = output_handle
        
        def open_side_effect(file, mode="r", *args, **kwargs):
            if file == "/tmp/event.json":
                return read_mock(file, mode, *args, **kwargs)
            return output_file_mock
            
        mock_file.side_effect = open_side_effect
        
        # Run Parse
        parse.run(None)
        
        # Verify
        try:
            output_handle.write.assert_any_call(f"mode={expected_mode}\n")
            output_handle.write.assert_any_call(f"command={expected_cmd}\n")
            print(f"✅ Verified: mode={expected_mode}, command={expected_cmd}")
        except AssertionError as e:
            print(f"❌ FAILED: Expected mode={expected_mode}, command={expected_cmd}")
            print(f"   Actual calls: {output_handle.write.call_args_list}")
            raise e

    def test_01_bootstrap_plan(self):
        self.run_scenario(
            {"GITHUB_EVENT_NAME": "issue_comment"},
            {"issue": {"pull_request": {"url": "http://..."}}, "comment": {"body": "/bootstrap plan"}},
            "python", "bootstrap-plan"
        )

    def test_02_bootstrap_apply(self):
        self.run_scenario(
            {"GITHUB_EVENT_NAME": "issue_comment"},
            {"issue": {"pull_request": {"url": "http://..."}}, "comment": {"body": "/bootstrap apply"}},
            "python", "bootstrap-apply"
        )
        
    def test_03_digger_plan(self):
        self.run_scenario(
            {"GITHUB_EVENT_NAME": "issue_comment"},
            {"issue": {"pull_request": {"url": "http://..."}}, "comment": {"body": "/plan"}},
            "digger", "plan"
        )

    def test_04_digger_apply(self):
        self.run_scenario(
            {"GITHUB_EVENT_NAME": "issue_comment"},
            {"issue": {"pull_request": {"url": "http://..."}}, "comment": {"body": "/apply"}},
            "digger", "apply"
        )

    def test_05_e2e_test(self):
        self.run_scenario(
            {"GITHUB_EVENT_NAME": "issue_comment"},
            {"issue": {"pull_request": {"url": "http://..."}}, "comment": {"body": "/e2e"}},
            "python", "e2e"
        )
        
    def test_06_review(self):
        self.run_scenario(
            {"GITHUB_EVENT_NAME": "issue_comment"},
            {"issue": {"pull_request": {"url": "http://..."}}, "comment": {"body": "/review"}},
            "python", "review"
        )

    def test_07_push_main_verify(self):
        self.run_scenario(
            {"GITHUB_EVENT_NAME": "push", "GITHUB_REF": "refs/heads/main"},
            {},
            "python", "verify"
        )

    def test_08_pr_open_auto_plan(self):
        self.run_scenario(
            {"GITHUB_EVENT_NAME": "pull_request"},
            {"number": 123},
            "digger", "plan"
        )

if __name__ == "__main__":
    unittest.main(verbosity=2)
