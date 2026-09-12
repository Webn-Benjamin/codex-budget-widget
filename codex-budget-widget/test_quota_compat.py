import copy
from pathlib import Path
import tempfile
import unittest

from budget import parse, QuotaError
from monitor import collect
from test_spark import payload, NOW


class QuotaCompatibilityTests(unittest.TestCase):
    def test_missing_account_id_displays_both_weekly_quotas(self):
        data = payload()
        del data['accountId']
        with tempfile.TemporaryDirectory() as folder:
            result = collect(Path(folder), data, NOW)['models']
            self.assertTrue(result['codex']['ok'])
            self.assertTrue(result['spark']['ok'])
            self.assertEqual(result['codex']['remaining'], 75)
            self.assertEqual(result['spark']['remaining'], 90)
            self.assertTrue(result['codex']['snapshot_only'])
            self.assertFalse((Path(folder) / 'history.sqlite').exists())

    def test_unidentified_reads_never_merge_with_each_other_or_known_history(self):
        data = payload()
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            collect(root, data, NOW)
            before = (root / 'history.sqlite').read_bytes()
            del data['accountId']
            collect(root, data, NOW + 60)
            data['rateLimitsByLimitId']['codex']['primary']['usedPercent'] = 80
            result = collect(root, data, NOW + 120)['models']['codex']
            self.assertTrue(result['uncertain'])
            self.assertEqual(result['today_low'], 0)
            self.assertEqual(result['today_high'], 80)
            self.assertEqual((root / 'history.sqlite').read_bytes(), before)

    def test_legacy_fallback_with_empty_bucket_map(self):
        data = payload()
        data['rateLimits'] = data['rateLimitsByLimitId']['codex']
        data['rateLimitsByLimitId'] = {}
        self.assertEqual(parse(data, NOW)['used'], 25)
        data['rateLimits']['limitId'] = 'codex_bengalfox'
        with self.assertRaises(QuotaError):
            parse(data, NOW)

    def test_distinct_parse_failures(self):
        for key, value, code in [('windowDurationMins', 300, 'weekly_missing'),
                                 ('usedPercent', True, 'used_invalid'),
                                 ('resetsAt', NOW-1, 'reset_expired'),
                                 ('resetsAt', 'bad', 'reset_invalid')]:
            data = copy.deepcopy(payload())
            data['rateLimitsByLimitId']['codex']['primary'][key] = value
            with self.assertRaises(QuotaError) as error:
                parse(data, NOW)
            self.assertEqual(error.exception.code, code)


if __name__ == '__main__':
    unittest.main()
