import unittest
from unittest.mock import patch, mock_open, MagicMock
import sys
import os
import json

# Add tools to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "../../tools")))

from ci.commands import parse

class TestParse(unittest.TestCase):
    def setUp(self):
        self.output_mock = mock_open()

    @patch("builtins.open")
    @patch("os.path.exists") # Patch exists
    @patch("os.environ.get")
    def test_pr_event(self, mock_env, mock_exists, mock_file):
        mock_exists.return_value = True # File exists
        mock_env.side_effect = lambda k, d="": {
            "GITHUB_EVENT_NAME": "pull_request",
            "GITHUB_EVENT_PATH": "/tmp/event.json",
            "GITHUB_OUTPUT": "/tmp/output"
        }.get(k, d)
        
        read_mock = mock_open(read_data=json.dumps({"number": 123}))
        output_handle = MagicMock()
        output_file_mock = MagicMock()
        output_file_mock.__enter__.return_value = output_handle
        
        def open_side_effect(file, mode="r", *args, **kwargs):
            if file == "/tmp/event.json":
                return read_mock(file, mode, *args, **kwargs)
            return output_file_mock
            
        mock_file.side_effect = open_side_effect
        
        parse.run(None)
        
        output_handle.write.assert_any_call("mode=digger\n")
        output_handle.write.assert_any_call("command=plan\n")
        output_handle.write.assert_any_call("pr_number=123\n")

    @patch("builtins.open")
    @patch("os.path.exists")
    @patch("os.environ.get")
    def test_bootstrap_comment(self, mock_env, mock_exists, mock_file):
        mock_exists.return_value = True
        mock_env.side_effect = lambda k, d="": {
            "GITHUB_EVENT_NAME": "issue_comment",
            "GITHUB_EVENT_PATH": "/tmp/event.json",
            "GITHUB_OUTPUT": "/tmp/output"
        }.get(k, d)
        
        event_data = {
            "issue": {"pull_request": {"url": "http://api.github.com"}, "number": 456},
            "comment": {"body": "/bootstrap apply"}
        }
        read_mock = mock_open(read_data=json.dumps(event_data))
        output_handle = MagicMock()
        output_file_mock = MagicMock()
        output_file_mock.__enter__.return_value = output_handle
        
        def open_side_effect(file, mode="r", *args, **kwargs):
            if file == "/tmp/event.json":
                return read_mock(file, mode, *args, **kwargs)
            return output_file_mock
            
        mock_file.side_effect = open_side_effect
        
        parse.run(None)
        
        output_handle.write.assert_any_call("mode=python\n")
        output_handle.write.assert_any_call("command=bootstrap-apply\n")

    @patch("builtins.open")
    @patch("os.path.exists")
    @patch("os.environ.get")
    def test_plan_comment(self, mock_env, mock_exists, mock_file):
        mock_exists.return_value = True
        mock_env.side_effect = lambda k, d="": {
            "GITHUB_EVENT_NAME": "issue_comment",
            "GITHUB_EVENT_PATH": "/tmp/event.json",
            "GITHUB_OUTPUT": "/tmp/output"
        }.get(k, d)
        
        event_data = {
            "issue": {"pull_request": {"url": "http://api.github.com"}, "number": 456},
            "comment": {"body": "/plan all"}
        }
        read_mock = mock_open(read_data=json.dumps(event_data))
        output_handle = MagicMock()
        output_file_mock = MagicMock()
        output_file_mock.__enter__.return_value = output_handle
        
        def open_side_effect(file, mode="r", *args, **kwargs):
            if file == "/tmp/event.json":
                return read_mock(file, mode, *args, **kwargs)
            return output_file_mock
            
        mock_file.side_effect = open_side_effect
        
        parse.run(None)
        
        output_handle.write.assert_any_call("mode=digger\n")
        output_handle.write.assert_any_call("command=plan\n")

    @patch("builtins.open")
    @patch("os.path.exists")
    @patch("os.environ.get")
    def test_push_main(self, mock_env, mock_exists, mock_file):
        mock_exists.return_value = True
        mock_env.side_effect = lambda k, d="": {
            "GITHUB_EVENT_NAME": "push",
            "GITHUB_REF": "refs/heads/main",
            "GITHUB_EVENT_PATH": "/tmp/event.json",
            "GITHUB_OUTPUT": "/tmp/output"
        }.get(k, d)
        
        read_mock = mock_open(read_data="{}")
        output_handle = MagicMock()
        output_file_mock = MagicMock()
        output_file_mock.__enter__.return_value = output_handle
        
        def open_side_effect(file, mode="r", *args, **kwargs):
            if file == "/tmp/event.json":
                return read_mock(file, mode, *args, **kwargs)
            return output_file_mock
            
        mock_file.side_effect = open_side_effect
        
        parse.run(None)
        
        output_handle.write.assert_any_call("mode=python\n")
        output_handle.write.assert_any_call("command=verify\n")


if __name__ == "__main__":
    unittest.main()
