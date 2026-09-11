import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from budget import parse, short_window
from monitor import collect

NOW=1789120000

def payload():
    return {'accountId':'test','rateLimitsByLimitId':{
        'codex':{'primary':{'usedPercent':25,'windowDurationMins':10080,'resetsAt':NOW+500000}},
        'codex_bengalfox':{'limitName':'GPT-5.3-Codex-Spark','primary':{'usedPercent':90,'windowDurationMins':300,'resetsAt':NOW+7200},'secondary':{'usedPercent':10,'windowDurationMins':10080,'resetsAt':NOW+490000}}}}

class SparkTests(unittest.TestCase):
    def test_separate_reserves_and_history(self):
        with TemporaryDirectory() as folder:
            p=payload(); a=collect(Path(folder),p,NOW)['models']
            self.assertEqual(a['codex']['remaining'],75)
            self.assertEqual(a['spark']['remaining'],90)
            self.assertEqual(a['spark']['short']['remaining'],10)
            p['rateLimitsByLimitId']['codex']['primary']['usedPercent']=26
            p['rateLimitsByLimitId']['codex_bengalfox']['secondary']['usedPercent']=12
            b=collect(Path(folder),p,NOW+60)['models']
            self.assertEqual(b['codex']['used'],26)
            self.assertEqual(b['spark']['used'],12)
            self.assertNotEqual(b['codex']['reset'],b['spark']['reset'])
    def test_window_order_does_not_matter(self):
        p=payload();q=p['rateLimitsByLimitId']['codex_bengalfox'];q['primary'],q['secondary']=q['secondary'],q['primary']
        self.assertEqual(parse(p,NOW,'spark')['used'],10)
        self.assertEqual(short_window(p,NOW)['used'],90)
    def test_absent_spark_does_not_break_codex(self):
        with TemporaryDirectory() as folder:
            p=payload();del p['rateLimitsByLimitId']['codex_bengalfox']
            result=collect(Path(folder),p,NOW)['models']
            self.assertTrue(result['codex']['ok']);self.assertFalse(result['spark']['ok'])
    def test_exhaustion_and_expiry_never_invent_refill(self):
        p=payload();q=p['rateLimitsByLimitId']['codex_bengalfox']['primary'];q['usedPercent']=100
        self.assertEqual(short_window(p,NOW)['remaining'],0)
        q['resetsAt']=NOW-1
        self.assertFalse(short_window(p,NOW)['ok'])
        q['resetsAt']=NOW+600;q['usedPercent']=float('nan')
        self.assertFalse(short_window(p,NOW)['ok'])
    def test_five_hour_reset_does_not_reset_weekly(self):
        p=payload();q=p['rateLimitsByLimitId']['codex_bengalfox']['primary'];q['usedPercent']=0;q['resetsAt']=NOW+18000
        self.assertEqual(short_window(p,NOW)['remaining'],100)
        self.assertEqual(parse(p,NOW,'spark')['used'],10)
