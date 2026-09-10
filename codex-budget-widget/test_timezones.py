import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch
from zoneinfo import ZoneInfo
from budget import calculate, local_zone, schedule

class TimezoneTests(unittest.TestCase):
    def test_same_instant_uses_local_date_and_reset(self):
        at = datetime(2026, 9, 10, 1, tzinfo=timezone.utc).timestamp()
        reset = datetime(2026, 9, 16, 8, tzinfo=timezone.utc).timestamp()
        rows = [dict(account='test', at=at, reset=reset, used=17)]
        for name, day in [('America/Los_Angeles','09/09'), ('Asia/Tokyo','10/09'), ('Asia/Kathmandu','10/09'), ('Pacific/Auckland','10/09')]:
            with self.subTest(name=name):
                zone = ZoneInfo(name)
                result = calculate(rows, list(range(7)), zone=zone)
                self.assertEqual(result['day'], day)
                self.assertEqual(result['reset'], reset)
                self.assertEqual(result['remaining'], 83)
                self.assertEqual(result['reset_label'], datetime.fromtimestamp(reset, zone).strftime('%d/%m à %H:%M'))

    def test_dst_days_keep_full_daily_allowance(self):
        for name, date, duration in [('America/New_York',(2026,3,8),23), ('America/New_York',(2026,11,1),25), ('Europe/Paris',(2026,3,29),23), ('Europe/Paris',(2026,10,25),25)]:
            with self.subTest(name=name, date=date):
                zone=ZoneInfo(name)
                start=datetime(*date,tzinfo=zone)
                end=start+timedelta(days=1)
                self.assertEqual((end.timestamp()-start.timestamp())/3600,duration)
                self.assertEqual(list(schedule(start,end,list(range(7))).values()),[100/7])
                rows=[dict(account='a',at=start.timestamp(),reset=end.timestamp()+86400,used=10),dict(account='a',at=(start+timedelta(hours=12)).timestamp(),reset=end.timestamp()+86400,used=13)]
                result=calculate(rows,list(range(7)),zone=zone)
                self.assertFalse(result['uncertain'])
                self.assertEqual(result['today_low'],3)

    def test_timezone_changes_are_reloaded(self):
        with patch('budget.reload_localzone',side_effect=[ZoneInfo('Asia/Tokyo'),ZoneInfo('America/Los_Angeles')]) as reload:
            self.assertEqual(str(local_zone()),'Asia/Tokyo')
            self.assertEqual(str(local_zone()),'America/Los_Angeles')
            self.assertEqual(reload.call_count,2)

    def test_calculate_detects_zone_by_default(self):
        at=datetime(2026,9,10,1,tzinfo=timezone.utc).timestamp()
        row=dict(account='a',at=at,reset=at+86400,used=4)
        with patch('budget.local_zone', return_value=ZoneInfo('America/Los_Angeles')):
            self.assertEqual(calculate([row])['day'],'09/09')
