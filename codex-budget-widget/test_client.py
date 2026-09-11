import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch, Mock

from client import Client, ClientError, find_codex


class ClientTests(unittest.TestCase):
    def test_discovery_without_desktop(self):
        for layout in ('codex', 'codex-win32-x64', 'codex/node_modules/@openai/codex-win32-x64'):
            with self.subTest(layout=layout), tempfile.TemporaryDirectory() as folder:
                root = Path(folder)
                prefix = root / 'npm with spaces & symbols'
                binary_dir = 'codex' if layout == 'codex' else 'bin'
                exe = prefix / 'node_modules/@openai' / layout / 'vendor/x86_64-pc-windows-msvc' / binary_dir / 'codex.exe'
                exe.parent.mkdir(parents=True)
                exe.touch()
                with patch.dict(os.environ, {'PATH': str(prefix), 'APPDATA': str(root), 'LOCALAPPDATA': str(root)}), patch('client.platform.machine', return_value='AMD64'):
                    self.assertEqual(find_codex(), str(exe))

    def test_native_path_and_missing(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            with patch.dict(os.environ, {'PATH': folder, 'APPDATA': folder, 'LOCALAPPDATA': folder}):
                with self.assertRaises(ClientError) as error:
                    find_codex()
                self.assertEqual(error.exception.code, 'codex_missing')
                (root / 'codex.cmd').write_text('do not execute')
                with self.assertRaises(ClientError):
                    find_codex()
                (root / 'codex.exe').touch()
                self.assertEqual(find_codex(), str(root / 'codex.exe'))

    def test_account_states_do_not_read_limits_without_chatgpt(self):
        for account, code in ((None, 'login_required'), ({'type': 'apiKey'}, 'api_key')):
            client = Client.__new__(Client)
            client.call = Mock(return_value={'account': account})
            with self.assertRaises(ClientError) as error:
                client.read_limits()
            self.assertEqual(error.exception.code, code)
            client.call.assert_called_once_with('account/read', {'refreshToken': False})

    def test_chatgpt_reads_only_metadata(self):
        client = Client.__new__(Client)
        payload = {'rateLimits': {'usedPercent': 20}}
        client.call = Mock(side_effect=[{'account': {'type': 'chatgpt'}}, payload])
        self.assertEqual(client.read_limits(), payload)
        self.assertEqual(client.call.call_args.args, ('account/rateLimits/read',))

    def test_model_calls_remain_forbidden(self):
        with self.assertRaises(ValueError):
            Client.__new__(Client).call('turn/start')


if __name__ == '__main__':
    unittest.main()
