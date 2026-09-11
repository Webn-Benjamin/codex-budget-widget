import json
import queue
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

from client import Client, ClientError
from diagnostics import Journal


class DiagnosticTests(unittest.TestCase):
    def test_bounded_report_without_untrusted_message(self):
        with tempfile.TemporaryDirectory() as folder:
            journal = Journal(Path(folder))
            for i in range(50):
                journal.add('error', 'WSL / Debian', 'account/read', code='TOKEN secret@example.com', rpc_code='secret')
            report = journal.path.read_text(encoding='utf-8')
            self.assertNotIn('TOKEN', report)
            self.assertNotIn('secret', report)
            self.assertEqual(len(json.loads(report)['entries']), 40)

    def test_rpc_error_retains_only_code_and_stage(self):
        client = Client.__new__(Client)
        client.counter = 0
        client._write = Mock()
        client.messages = queue.Queue()
        client.messages.put({'id': 1, 'error': {'code': -32601, 'message': 'private-token example@example.com', 'data': 'secret'}})
        with self.assertRaises(ClientError) as error:
            client.call('account/read')
        self.assertEqual(error.exception.stage, 'account/read')
        self.assertEqual(error.exception.code, 'method_unsupported')
        self.assertEqual(error.exception.rpc_code, -32601)
        self.assertNotIn('secret', str(error.exception))

    def test_write_failure_does_not_break_monitoring(self):
        with tempfile.TemporaryDirectory() as folder, patch('diagnostics.os.replace', side_effect=PermissionError()):
            journal = Journal(Path(folder))
            journal.add('quotas_ok')
            self.assertEqual(len(journal.entries), 1)

    def test_numeric_details_and_clean_source(self):
        with tempfile.TemporaryDirectory() as folder:
            journal = Journal(Path(folder))
            journal.add('error', 'WSL / Debian\n', 'initialize', 'connection_closed', system_code=5, exit_code=2)
            entry = json.loads(journal.path.read_text())['entries'][0]
            self.assertEqual(entry['source'], 'WSL / Debian')
            self.assertEqual(entry['exit_code'], 2)
            self.assertEqual(entry['system_code'], 5)


if __name__ == '__main__':
    unittest.main()
