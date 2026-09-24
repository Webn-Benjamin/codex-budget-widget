import unittest
from datetime import datetime
from zoneinfo import ZoneInfo
from budget import calculate, remaining_plan

Z=ZoneInfo('Europe/Paris')
class RemainingPlanTests(unittest.TestCase):
    def test_reported_87_remaining_and_four_used_today(self):
        now = datetime(2026, 9, 24, 10, 20, tzinfo=Z)
        reset = datetime(2026, 9, 30, 21, 50, 50, tzinfo=Z)
        midnight = now.replace(hour=0, minute=0)
        rows = [dict(account='a', at=midnight.timestamp(), reset=reset.timestamp(), used=9),
                dict(account='a', at=now.timestamp(), reset=reset.timestamp(), used=13)]
        state = calculate(rows, list(range(7)), Z)
        plan = state['remaining_plan']
        equivalents = 6 + (21 * 3600 + 50 * 60 + 50) / 86400
        self.assertEqual(state['remaining'], 87)
        self.assertEqual((state['today_low'], state['today_high']), (4, 4))
        self.assertAlmostEqual(plan['day_equivalents'], equivalents)
        self.assertAlmostEqual(plan['total_today'], 91 / equivalents)
        self.assertAlmostEqual(plan['available'], 9.168746336152752)

    def test_tuesday_reset_changes_budget_and_excludes_wednesday(self):
        now = datetime(2026, 9, 24, 10, 20, tzinfo=Z)
        reset = datetime(2026, 9, 29, 21, 50, 50, tzinfo=Z)
        plan = remaining_plan(now, reset, list(range(7)), 87, today_used=4)
        equivalents = 5 + (21 * 3600 + 50 * 60 + 50) / 86400
        self.assertEqual(plan['days'], 6)
        self.assertAlmostEqual(plan['available'], 91 / equivalents - 4)
        without_wednesday = remaining_plan(now, reset, [0, 1, 3, 4, 5, 6], 87, today_used=4)
        self.assertEqual(plan, without_wednesday)

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

    def test_reported_thursday_12_used_13_left_saturday_off(self):
        now=datetime(2026,9,17,20,12,tzinfo=Z);reset=datetime(2026,9,19,10,31,tzinfo=Z)
        r=remaining_plan(now,reset,[0,1,2,3,4,6],13,16.1,today_used=12)
        self.assertEqual((r['total_today'],r['available'],r['daily'],r['days']),(12.5,0.5,12.5,2))
        self.assertEqual(r['tomorrow_available'],13)

    def test_spending_does_not_increase_daily_target(self):
        now=datetime(2026,9,16,9,tzinfo=Z);reset=datetime(2026,9,19,10,31,tzinfo=Z)
        for spent in [0,1,3,11,12,25,33]:
            r=remaining_plan(now,reset,[0,1,2,3,4,6],33-spent,today_used=spent)
            self.assertEqual(r['total_today'],11)
            self.assertEqual(r['available'],max(0,11-spent))

    def test_partial_saturday_overspend_keeps_original_target(self):
        now=datetime(2026,9,17,20,12,tzinfo=Z);reset=datetime(2026,9,19,10,31,tzinfo=Z)
        r=remaining_plan(now,reset,list(range(7)),13,today_used=12)
        self.assertAlmostEqual(r['total_today'],25/(2+631/1440))
        self.assertEqual(r['available'],0)
        self.assertAlmostEqual(r['day_equivalents'],2+631/1440)

    def test_day_off_usage_reduces_future_daily_amount(self):
        now=datetime(2026,9,19,21,tzinfo=Z);reset=datetime(2026,9,26,11,55,tzinfo=Z)
        for spent in [0,2,25,100]:
            r=remaining_plan(now,reset,[0,1,2,3,4,6],100-spent,today_used=spent)
            self.assertFalse(r['working_today'])
            self.assertEqual(r['available'],0)
            self.assertAlmostEqual(r['daily'],(100-spent)/6)
            self.assertAlmostEqual(r['tomorrow_available'],r['daily'])
            self.assertEqual(r['days'],6)
