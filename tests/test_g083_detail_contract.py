"""Guard against a probe silently omitting production collision or signal work."""
from pathlib import Path
import importlib.util
import unittest

spec = importlib.util.spec_from_file_location("g083_contract", Path(__file__).resolve().parents[1] / "tools/audit_g083_detail.py")
contract = importlib.util.module_from_spec(spec)
spec.loader.exec_module(contract)
ROOT = Path(__file__).resolve().parents[1]


class ProbeContractTests(unittest.TestCase):
    def test_current_methods_and_receipts(self):
        failures = [row["check"] for row in contract.audit(ROOT) if not row["passed"]]
        self.assertEqual(failures, [])

    def test_removing_collision_query_is_detected(self):
        path, name = contract.METHODS["game"]
        original = contract.method(contract.normalized(ROOT / path), name)
        timed = contract.method(contract.normalized(ROOT / "tests/g083_detail/game.gd"), name)
        changed = timed.replace("space.intersect_shape(query, 1).is_empty()", "true")
        self.assertNotEqual(contract.without_timing(changed), original)

    def test_removing_settlement_signal_is_detected(self):
        path, name = contract.METHODS["flow"]
        original = contract.method(contract.normalized(ROOT / path), name)
        timed = contract.method(contract.normalized(ROOT / "tests/g083_detail/flow.gd"), name)
        changed = timed.replace("\tarena.manager.settled.connect(_on_settled)\n", "")
        self.assertNotEqual(contract.without_timing(changed), original)


if __name__ == "__main__":
    unittest.main()
