// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::math_bit_tests {
    use turbos_clmm::math_bit;
    use sui::test_utils::{assert_eq};

    const MAX_U256: u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    #[test]
    public fun test_most_significant_bit() {
        assert_eq(math_bit::most_significant_bit(1), 0);
        assert_eq(math_bit::most_significant_bit(2), 1);
        //uint256(-1)
        assert_eq(math_bit::most_significant_bit(MAX_U256), 255);
    }

    #[test]
    public fun test_least_significant_bit() {
        assert_eq(math_bit::least_significant_bit(1), 0);
        assert_eq(math_bit::least_significant_bit(2), 1);
        //uint256(-1)
        assert_eq(math_bit::least_significant_bit(MAX_U256), 0);
    }
    
    #[test]
    #[expected_failure(abort_code = turbos_clmm::math_bit::EXMustGtZero)]
    public fun test_least_significant_bit_revert() {
        assert_eq(math_bit::least_significant_bit(0), 0);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::math_bit::EXMustGtZero)]
    public fun test_most_significant_bit_revert() {
        assert_eq(math_bit::most_significant_bit(0), 0);
    }
}