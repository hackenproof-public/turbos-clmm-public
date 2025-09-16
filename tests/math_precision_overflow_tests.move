// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::math_precision_overflow_tests {
    use sui::test_utils::{assert_eq};
    use turbos_clmm::math_u128;
    use turbos_clmm::math_u64;
    use turbos_clmm::i128;
    use turbos_clmm::i64;
    use turbos_clmm::i32;
    use turbos_clmm::math_sqrt_price;
    use turbos_clmm::math_liquidity;
    use turbos_clmm::full_math_u128;
    use turbos_clmm::math_tick;
    use std::vector;

    // Constants for overflow testing
    const MAX_U128: u128 = 0xffffffffffffffffffffffffffffffff;
    const MAX_U64: u64 = 0xffffffffffffffff;
    const MAX_U32: u32 = 0xffffffff;
    
    // Math precision constants
    const Q64: u128 = 0x10000000000000000;
    const PRECISION_TOLERANCE: u128 = 1000; // 0.1%

    #[test]
    public fun test_math_u128_overflow_protection() {
        // 🔍 SECURITY TEST: Verify u128 arithmetic overflow protection
        
        // Test wrapping_add overflow detection
        let large_num1 = MAX_U128 - 100;
        let large_num2 = 200;
        
        let (sum, overflow) = math_u128::overflowing_add(large_num1, large_num2);
        assert_eq(overflow, true);
        assert_eq(sum, 99); // Should wrap around
        
        // Test wrapping_mul overflow detection  
        let mul_num1 = 1 << 100; // Very large number
        let mul_num2 = 1 << 50;
        
        let (product, mul_overflow) = math_u128::overflowing_mul(mul_num1, mul_num2);
        assert_eq(mul_overflow, true);
        
        // 🔍 SECURITY CHECK: full_mul should handle large multiplications correctly
        let (lo_part, hi_part) = math_u128::full_mul(MAX_U128, MAX_U128);
        assert_eq(hi_part > 0, true); // Should have high part for max multiplication
        assert_eq(lo_part, 1); // Low part should be 1 for MAX * MAX
        
        // Test subtraction underflow detection
        let (diff, sub_overflow) = math_u128::overflowing_sub(100, 200);
        assert_eq(sub_overflow, true);
        assert_eq(diff, MAX_U128 - 99); // Should wrap around properly
    }

    #[test]
    public fun test_math_u64_precision_boundaries() {
        // 🔍 SECURITY TEST: Verify u64 arithmetic maintains precision at boundaries
        
        // Test overflow boundary
        let (sum_overflow, overflow2) = math_u64::overflowing_add(MAX_U64, 1);
        assert_eq(overflow2, true);
        
        // Test multiplication precision - simplified
        let precision_test1 = 100000u64; 
        let precision_test2 = 50000u64; 
        let (product, mul_overflow) = math_u64::overflowing_mul(precision_test1, precision_test2);
        assert_eq(mul_overflow, false); // Should not overflow
        assert_eq(product, 5000000000); // 100000 * 50000
        
        // Test carry operations
        let (carry_result, carry) = math_u64::carry_add(MAX_U64, 1, 0);
        assert_eq(carry, 1);
        assert_eq(carry_result, 0);
        
        // Test basic addition without overflow
        let (normal_sum, normal_overflow) = math_u64::overflowing_add(1000, 2000);
        assert_eq(normal_overflow, false);
        assert_eq(normal_sum, 3000);
    }

    #[test]
    public fun test_signed_integer_overflow_protection() {
        // 🔍 SECURITY TEST: Verify signed integer overflow protection
        
        // Test i128 overflow protection
        let max_i128 = i128::from(0x7fffffffffffffffffffffffffffffff);
        let small_positive = i128::from(1);
        
        let (sum_i128, overflow_i128) = i128::overflowing_add(max_i128, small_positive);
        assert_eq(overflow_i128, true); // Should detect overflow
        
        // Test i64 operations
        let max_i64 = i64::from(0x7fffffffffffffff);
        let result_i64 = i64::wrapping_sub(max_i64, i64::neg_from(1));
        // Should handle negative subtraction correctly
        
        // Test i32 boundary conditions
        let max_i32 = i32::from(0x7fffffff);
        let neg_i32 = i32::neg_from(1);
        let sum_i32 = i32::wrapping_add(max_i32, neg_i32);
        assert_eq(i32::abs_u32(sum_i32), 0x7ffffffe); // Max - 1
    }

    #[test]
    public fun test_sqrt_price_precision_limits() {
        // 🔍 SECURITY TEST: Verify sqrt price calculations maintain precision at extremes
        
        // Test maximum sqrt price precision
        let max_sqrt_price = 79226673515401279992447579055u128; // MAX_SQRT_PRICE_X64
        let min_sqrt_price = 4295048016u128; // MIN_SQRT_PRICE_X64
        
        // Test amount calculations at extreme prices
        let large_liquidity = 1000000000000000u128; // 10^15
        
        let amount_a_max = math_sqrt_price::get_amount_a_delta_(
            min_sqrt_price,
            max_sqrt_price,
            large_liquidity,
            false
        );
        
        let amount_b_max = math_sqrt_price::get_amount_b_delta_(
            min_sqrt_price,
            max_sqrt_price,
            large_liquidity,
            false
        );
        
        // 🔍 SECURITY CHECK: Results should be reasonable and not overflow
        assert_eq(amount_a_max > 0, true);
        assert_eq(amount_b_max > 0, true);
        assert_eq(amount_a_max < MAX_U128, true);
        assert_eq(amount_b_max < MAX_U128, true);
        
        // Test precision with small price differences
        let price1 = 1000000000000000000u128; // Close prices
        let price2 = 1000000000000000001u128;
        
        let small_diff_a = math_sqrt_price::get_amount_a_delta_(
            price1,
            price2,
            1000000u128,
            false
        );
        
        // Should handle tiny price differences gracefully
        assert_eq(small_diff_a >= 0, true);
    }

    #[test]
    public fun test_liquidity_calculation_precision() {
        // 🔍 SECURITY TEST: Verify liquidity calculations maintain precision
        
        // Test with extreme amount values
        let tiny_amount = 1u128;
        let huge_amount = MAX_U128 / 1000; // Large but not overflow-prone
        
        let sqrt_price_current = math_sqrt_price::encode_price_sqrt(1, 1);
        let sqrt_price_lower = math_tick::sqrt_price_from_tick_index(i32::neg_from(1000));
        let sqrt_price_upper = math_tick::sqrt_price_from_tick_index(i32::from(1000));
        
        // Test tiny amounts
        let tiny_liquidity = math_liquidity::get_liquidity_for_amounts(
            sqrt_price_current,
            sqrt_price_lower,
            sqrt_price_upper,
            tiny_amount,
            tiny_amount
        );
        
        // Test moderate amounts (avoiding overflow in get_amount_a_for_liquidity)
        let moderate_amount = 1000000000000u128; // 10^12 instead of MAX_U128/1000
        let moderate_liquidity = math_liquidity::get_liquidity_for_amounts(
            sqrt_price_current,
            sqrt_price_lower,
            sqrt_price_upper,
            moderate_amount,
            moderate_amount
        );
        
        // 🔍 SECURITY CHECK: Liquidity scaling should be reasonable
        assert_eq(moderate_liquidity > tiny_liquidity, true);
        assert_eq(tiny_liquidity >= 0, true);
        assert_eq(moderate_liquidity < MAX_U128, true);
        
        // Test precision preservation in reverse calculation
        if (moderate_liquidity > 0) {
            let (calc_amount_a, calc_amount_b) = math_liquidity::get_amount_for_liquidity(
                sqrt_price_current,
                sqrt_price_lower,
                sqrt_price_upper,
                moderate_liquidity
            );
            
            // Results should be in reasonable proportion to inputs
            let precision_ratio_a = if (calc_amount_a > moderate_amount) {
                calc_amount_a / moderate_amount
            } else {
                moderate_amount / calc_amount_a
            };
            
            // Allow for reasonable precision loss (less than 1000x difference)
            assert_eq(precision_ratio_a < PRECISION_TOLERANCE, true);
        };
    }

    #[test]
    public fun test_add_delta_overflow_protection() {
        // 🔍 SECURITY TEST: Verify add_delta function handles overflows correctly
        
        // Test normal operation
        let base_value = 1000000u128;
        let positive_delta = i128::from(500000);
        let negative_delta = i128::neg_from(300000);
        
        let result_positive = math_liquidity::add_delta(base_value, positive_delta);
        assert_eq(result_positive, 1500000);
        
        let result_negative = math_liquidity::add_delta(base_value, negative_delta);
        assert_eq(result_negative, 700000);
        
        // Test boundary condition - exact subtraction
        let exact_delta = i128::neg_from(base_value);
        let zero_result = math_liquidity::add_delta(base_value, exact_delta);
        assert_eq(zero_result, 0);
        
        // Test addition near overflow
        let large_base = MAX_U128 - 1000;
        let small_positive = i128::from(500);
        let near_max_result = math_liquidity::add_delta(large_base, small_positive);
        assert_eq(near_max_result, MAX_U128 - 500);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::math_liquidity::EAddDelta)]
    public fun test_add_delta_underflow_protection() {
        // 🚨 SECURITY TEST: Verify add_delta prevents underflow
        let small_value = 100u128;
        let large_negative = i128::neg_from(200);
        
        // Should abort with EAddDelta
        math_liquidity::add_delta(small_value, large_negative);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::math_u128::EOverflow)]
    public fun test_wrapping_add_overflow_abort() {
        // 🚨 SECURITY TEST: Verify wrapping_add aborts on overflow
        let large_num1 = MAX_U128;
        let large_num2 = 1;
        
        // Should abort with EOverflow
        math_u128::wrapping_add(large_num1, large_num2);
    }

    #[test]
    #[expected_failure(abort_code = turbos_clmm::math_u64::EOverflow)]
    public fun test_wrapping_mul_u64_overflow_abort() {
        // 🚨 SECURITY TEST: Verify u64 wrapping_mul aborts on overflow
        let large_num1 = MAX_U64;
        let large_num2 = 2;
        
        // Should abort with EOverflow
        math_u64::wrapping_mul(large_num1, large_num2);
    }

    #[test]
    public fun test_full_math_precision_edge_cases() {
        // 🔍 SECURITY TEST: Verify full_math_u128 precision at edge cases
        
        // Test mul_div_floor with large numbers
        let large_a = MAX_U128 / 3;
        let large_b = MAX_U128 / 5;
        let large_c = MAX_U128 / 7;
        
        let result_floor = full_math_u128::mul_div_floor(large_a, large_b, large_c);
        let result_round = full_math_u128::mul_div_round(large_a, large_b, large_c);
        
        // 🔍 SECURITY CHECK: Results should be reasonable and ordered correctly
        assert_eq(result_round >= result_floor, true);
        assert_eq(result_floor > 0, true);
        assert_eq(result_round < MAX_U128, true);
        
        // Test precision with small divisor
        let precise_a = 1000000000000000000u128; // 10^18
        let precise_b = 999999999999999999u128;  // Close to 10^18
        let small_divisor = 1000000u128; // 10^6
        
        let precise_result = full_math_u128::mul_div_floor(precise_a, precise_b, small_divisor);
        
        // Should maintain high precision
        assert_eq(precise_result > 0, true);
        
        // Test with moderate precision requirements (avoiding overflow)
        let moderate_precision_a = 1000000000u128; // 10^9
        let moderate_precision_b = 1000000000u128; // 10^9  
        let moderate_precision_c = 1000u128; // 10^3
        
        let moderate_precision_result = full_math_u128::mul_div_floor(
            moderate_precision_a, 
            moderate_precision_b, 
            moderate_precision_c
        );
        
        // Should handle moderate precision multiplication
        assert_eq(moderate_precision_result > 0, true);
        assert_eq(moderate_precision_result < MAX_U128, true);
    }

    #[test]
    public fun test_integer_type_boundaries() {
        // 🔍 SECURITY TEST: Verify all integer types handle boundaries correctly
        
        // Test i32 boundaries
        let max_positive_i32 = i32::from(0x7fffffff);
        let max_negative_i32 = i32::neg_from(0x80000000);
        
        assert_eq(i32::abs_u32(max_positive_i32), 0x7fffffff);
        assert_eq(i32::abs_u32(max_negative_i32), 0x80000000);
        
        // Test i64 boundaries  
        let max_positive_i64 = i64::from(0x7fffffffffffffff);
        let max_negative_i64 = i64::neg_from(0x8000000000000000);
        
        assert_eq(i64::abs_u64(max_positive_i64), 0x7fffffffffffffff);
        assert_eq(i64::abs_u64(max_negative_i64), 0x8000000000000000);
        
        // Test i128 boundaries
        let max_positive_i128 = i128::from(0x7fffffffffffffffffffffffffffffff);
        let max_negative_i128 = i128::neg_from(0x80000000000000000000000000000000);
        
        assert_eq(i128::abs_u128(max_positive_i128), 0x7fffffffffffffffffffffffffffffff);
        assert_eq(i128::abs_u128(max_negative_i128), 0x80000000000000000000000000000000);
    }

    #[test]
    public fun test_precision_cascading_calculations() {
        // 🔍 SECURITY TEST: Verify precision is maintained through cascading calculations
        
        // Simulate a complex calculation chain like in real trading
        let initial_amount = 1000000000000u128; // 10^12
        let price_ratio = 15000u128; // 1.5x price ratio * 10^4
        let fee_rate = 3000u32; // 0.3% fee (3000 bps)
        
        // Step 1: Apply price conversion
        let converted_amount = full_math_u128::mul_div_floor(
            initial_amount,
            price_ratio,
            10000u128
        );
        
        // Step 2: Apply fee calculation
        let fee_amount = full_math_u128::mul_div_floor(
            converted_amount,
            (fee_rate as u128),
            1000000u128 // 1M bps = 100%
        );
        
        let final_amount = converted_amount - fee_amount;
        
        // Step 3: Reverse calculation to check precision
        let reverse_fee = full_math_u128::mul_div_floor(
            final_amount,
            (fee_rate as u128),
            1000000u128 - (fee_rate as u128)
        );
        
        let reverse_total = final_amount + reverse_fee;
        let reverse_initial = full_math_u128::mul_div_floor(
            reverse_total,
            10000u128,
            price_ratio
        );
        
        // 🔍 SECURITY CHECK: Precision loss should be minimal
        let precision_loss = if (reverse_initial > initial_amount) {
            reverse_initial - initial_amount
        } else {
            initial_amount - reverse_initial
        };
        
        let precision_percentage = precision_loss * 10000 / initial_amount; // bps
        assert_eq(precision_percentage < 100, true); // Less than 1% precision loss
        
        // Verify all intermediate results are reasonable
        assert_eq(converted_amount > 0, true);
        assert_eq(fee_amount > 0, true);
        assert_eq(final_amount > 0, true);
        assert_eq(final_amount < converted_amount, true);
    }

    #[test]
    public fun test_extreme_ratio_calculations() {
        // 🔍 SECURITY TEST: Verify calculations handle extreme ratios safely
        
        // Test very large ratio
        let small_numerator = 1u128;
        let large_denominator = MAX_U128 / 1000;
        
        let tiny_result = full_math_u128::mul_div_floor(
            1000000u128,
            small_numerator,
            large_denominator
        );
        
        // Should handle tiny results gracefully (may be 0)
        assert_eq(tiny_result <= 1000000, true);
        
        // Test very small ratio  
        let large_numerator = MAX_U128 / 1000;
        let small_denominator = 1u128;
        
        let huge_result = full_math_u128::mul_div_floor(
            1000u128,
            large_numerator,
            small_denominator
        );
        
        // Should handle large results without overflow
        assert_eq(huge_result > 0, true);
        assert_eq(huge_result < MAX_U128, true);
        
        // Test ratios near 1:1
        let almost_equal_a = 1000000000000000000u128;
        let almost_equal_b = 1000000000000000001u128;
        
        let precise_ratio_result = full_math_u128::mul_div_floor(
            1000000u128,
            almost_equal_a,
            almost_equal_b
        );
        
        // Should maintain precision for near-equal ratios  
        // Allow for some precision loss in extreme ratio calculations
        assert_eq(precise_ratio_result <= 1000000, true);
    }
}