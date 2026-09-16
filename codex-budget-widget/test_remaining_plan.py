import unittest
from datetime import datetime
from zoneinfo import ZoneInfo
from budget import calculate, remaining_plan

Z=ZoneInfo('Europe/Paris')
class RemainingPlanTests(unittest.TestCase):
    def test_reported_33_percent_wednesday(self):
        now=datetime(2026,9,16,9,tzinfo=Z);reset=datetime(2026,9,19,10,38,tzinfo=Z)
        r=remaining_plan(now,reset,[0,1,2,3,4,6],33,16)
        self.assertEqual((r['available'],r['daily'],r['days']),(11,11,3))
        self.assertEqual(r['tomorrow_available'],16.5)
        self.assertAlmostEqual(r['projected_tomorrow'],11.5)
        row=dict(account='a',at=now.timestamp(),reset=reset.timestamp(),used=67)
        state=calculate([row],[0,1,2,3,4,6],Z)
        self.assertEqual(state['remaining_plan']['available'],11)

    def test_usage_updates_remaining_and_future_sunday_is_irrelevant(self):
        now=datetime(2026,9,16,22,tzinfo=Z);reset=datetime(2026,9,19,10,38,tzinfo=Z)
        for remaining in [0,1,32,33,100]:
            a=remaining_plan(now,reset,[0,1,2,3,4],remaining)
            b=remaining_plan(now,reset,[0,1,2,3,4,6],remaining)
            self.assertEqual(a,b)
            self.assertAlmostEqual(a['available'],remaining/3)
            self.assertLessEqual(a['tomorrow_available'],remaining)

    def test_partial_reset_day_and_day_off(self):
        now=datetime(2026,9,18,12,tzinfo=Z);reset=datetime(2026,9,19,10,38,tzinfo=Z)
        r=remaining_plan(now,reset,list(range(7)),33)
        self.assertAlmostEqual(r['available'],33/(1+638/1440))
        self.assertEqual(r['tomorrow_available'],33)
        r=remaining_plan(datetime(2026,9,19,9,tzinfo=Z),reset,[0,1,2,3,4,6],33)
        self.assertEqual((r['available'],r['days']),(0,0))
        self.assertIsNone(r['tomorrow_available'])

    def test_forecast_is_bounded_by_remaining(self):
        now=datetime(2026,9,16,9,tzinfo=Z);reset=datetime(2026,9,19,10,38,tzinfo=Z)
        for average in [0,10,1000,None]:
            r=remaining_plan(now,reset,[0,1,2,3,4],33,average)
            if average is None:self.assertIsNone(r['projected_tomorrow'])
            else:self.assertTrue(0 <= r['projected_tomorrow'] <= r['tomorrow_available'] <=33)
