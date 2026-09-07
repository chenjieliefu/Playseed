import unittest

from validation_cases import CASES, validate_cases


class ValidationCaseTests(unittest.TestCase):
    def test_p0_matrix_has_five_distinct_gameplay_families_and_three_revisions(self):
        cases = validate_cases()
        self.assertEqual(
            {case["genre"] for case in cases},
            {"平台跳跃", "俯视射击", "经营", "解谜", "塔防"},
        )
        self.assertTrue(all(len(case["revisions"]) == 3 for case in cases))

    def test_invalid_matrix_is_rejected_before_using_model_quota(self):
        broken = [dict(case) for case in CASES]
        broken[0]["revisions"] = ["只有一轮"]
        with self.assertRaisesRegex(ValueError, "三轮连续修改"):
            validate_cases(broken)


if __name__ == "__main__":
    unittest.main()
