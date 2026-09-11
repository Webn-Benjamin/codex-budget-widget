import subprocess
import unittest
from unittest.mock import patch, Mock

from wsl_client import decode_list, find_wsl, PROBE, RUN
from client import Client, ClientError


class WslTests(unittest.TestCase):
    def test_list_encodings(self):
        for encoding in ('utf-16', 'utf-16-le', 'utf-8'):
            self.assertEqual(decode_list('Debian\r\nUbuntu\r\n'.encode(encoding)), ['Debian', 'Ubuntu'])

    @patch('wsl_client.Path.is_file', return_value=True)
    def test_skips_docker_and_missing_cli(self, exists):
        with patch('wsl_client.subprocess.run', side_effect=[
            Mock(returncode=0, stdout='docker-desktop\nUbuntu\nDebian\n'.encode('utf-16-le')),
            Mock(returncode=1, stdout=b''),
            Mock(returncode=0, stdout=b'profile greeting\nCODEX_WIDGET_FOUND\n')
        ]) as run:
            command, source = find_wsl()
            self.assertEqual(source, 'WSL / Debian')
            self.assertEqual(command[1:], ['--distribution', 'Debian', '--exec', 'sh', '-lc', RUN])
            self.assertEqual(run.call_count, 3)
            self.assertEqual(run.call_args.args[0][-1], PROBE)

    @patch('wsl_client.Path.is_file', return_value=True)
    def test_timeout_continues_to_next_distribution(self, exists):
        with patch('wsl_client.subprocess.run', side_effect=[
            Mock(returncode=0, stdout=b'Ubuntu\nDebian\n'),
            subprocess.TimeoutExpired('probe', 8),
            Mock(returncode=0, stdout=b'CODEX_WIDGET_FOUND\n')
        ]):
            self.assertEqual(find_wsl()[1], 'WSL / Debian')

    @patch('wsl_client.Path.is_file', return_value=True)
    def test_unavailable_wsl(self, exists):
        for outcome in (OSError(), subprocess.TimeoutExpired('list', 5)):
            with patch('wsl_client.subprocess.run', side_effect=outcome):
                self.assertIsNone(find_wsl())
        with patch('wsl_client.subprocess.run', return_value=Mock(returncode=1, stdout=b'error')):
            self.assertIsNone(find_wsl())

    @patch('wsl_client.Path.is_file', return_value=True)
    def test_distribution_name_is_never_interpolated_into_shell(self, exists):
        name = 'Debian ; echo unexpected'
        with patch('wsl_client.subprocess.run', side_effect=[
            Mock(returncode=0, stdout=name.encode()), Mock(returncode=0, stdout=b'CODEX_WIDGET_FOUND\n')
        ]):
            command, _ = find_wsl()
            self.assertEqual(command[2], name)
            self.assertNotIn(name, command[-1])

    def test_wsl_account_error(self):
        client = Client.__new__(Client)
        client.source = 'WSL / Debian'
        client.call = Mock(return_value={'account': None})
        with self.assertRaises(ClientError) as error:
            client.read_limits()
        self.assertEqual(error.exception.code, 'wsl_login_required')

    def test_windows_does_not_probe_wsl(self):
        with patch('client.find_codex', return_value='codex.exe'), patch('client.find_wsl') as wsl, patch('client.subprocess.Popen') as popen, patch.object(Client, 'call'), patch.object(Client, '_write'), patch('client.threading.Thread'):
            client = Client()
            self.assertEqual(client.source, 'Windows')
            wsl.assert_not_called()
            self.assertEqual(popen.call_args.args[0], ['codex.exe', 'app-server', '--stdio'])

    def test_wsl_transport_selected_when_windows_missing(self):
        command = ['wsl.exe', '-d', 'Debian', '--exec', 'sh', '-lc', RUN]
        with patch('client.find_codex', side_effect=ClientError('codex_missing')), patch('client.find_wsl', return_value=(command, 'WSL / Debian')), patch('client.subprocess.Popen') as popen, patch.object(Client, 'call'), patch.object(Client, '_write'), patch('client.threading.Thread'):
            self.assertEqual(Client().source, 'WSL / Debian')
            self.assertEqual(popen.call_args.args[0], command)


if __name__ == '__main__':
    unittest.main()
