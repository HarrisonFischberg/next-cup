#!/usr/bin/env python3
"""Self-check for score.py's comparison rules. usage: python3 qa/tools/test_score.py"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from score import outcome, wilson  # noqa: E402

fx = {"expect": {"roastDate": "", "name": "Ethiopia Guji", "bagWeightGrams": 250,
                 "flavorNotes": ["blueberry", "jasmine"], "isDecaf": False},
      "accept": {"name": ["Guji", "Ethiopia Guji"]}}
assert outcome(fx, "roastDate", "") == "abstain-ok"
assert outcome(fx, "roastDate", "2026-03-04") == "invented"
assert outcome(fx, "name", "ethiopia  GUJI.") == "correct"
assert outcome(fx, "name", "") == "missed"
assert outcome(fx, "name", "Ridge & River") == "wrong"
assert outcome(fx, "bagWeightGrams", 252) == "correct"
assert outcome(fx, "bagWeightGrams", 340) == "wrong"
assert outcome(fx, "flavorNotes", ["Jasmine", "blueberry"]) == "correct"
assert outcome(fx, "flavorNotes", ["jasmine"]) == "wrong"
assert outcome(fx, "isDecaf", True) == "invented"
assert wilson(0, 0) is None and wilson(5, 10)[0] == 0.5
print("score.py self-check passed")
