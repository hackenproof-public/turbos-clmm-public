// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::full_math_u128_comprehensive_tests {
    use turbos_clmm::full_math_u128::{Self};

    #[test]
    public fun test_full_mul_basic() {
        // Basic multiplication tests
        assert!(full_math_u128::full_mul(0, 0) == 0, 1);
        assert!(full_math_u128::full_mul(1, 1) == 1, 2);
        assert!(full_math_u128::full_mul(10, 5) == 50, 3);
        assert!(full_math_u128::full_mul(100, 200) == 20000, 4);
    }
    
    #[test]
    public fun test_full_mul_large_numbers() {
        // Test with larger u128 values
        let max_u64 = (0xffffffffffffffff as u128); // 2^64 - 1
        let result = full_math_u128::full_mul(max_u64, max_u64);
        
        // (2^64 - 1)^2 = 0xfffffffffffffffeffffffffffffffff
        let expected = 340282366920938463426481119284349108225u256;
        assert!(result == expected, 5);
        
        // Test with max u128
        let max_u128 = 340282366920938463463374607431768211455u128; // max u128
        let result_max = full_math_u128::full_mul(max_u128, 1);
        assert!(result_max == (max_u128 as u256), 6);
    }
    
    #[test]
    public fun test_full_mul_edge_cases() {
        // Test with zero
        let large = 340282366920938463463374607431768211455u128; // max u128
        assert!(full_math_u128::full_mul(large, 0) == 0, 7);
        assert!(full_math_u128::full_mul(0, large) == 0, 8);
        
        // Test with one
        assert!(full_math_u128::full_mul(large, 1) == (large as u256), 9);
        assert!(full_math_u128::full_mul(1, large) == (large as u256), 10);
    }
    
    #[test]
    public fun test_mul_div_floor_basic() {
        // Basic floor division tests
        assert!(full_math_u128::mul_div_floor(10, 5, 2) == 25, 11); // (10*5)/2 = 25
        assert!(full_math_u128::mul_div_floor(7, 3, 2) == 10, 12); // (7*3)/2 = 21/2 = 10 (floor)
        assert!(full_math_u128::mul_div_floor(100, 200, 50) == 400, 13); // (100*200)/50 = 400
    }
    
    #[test]
    public fun test_mul_div_floor_precision() {
        // Test precision and rounding behavior
        assert!(full_math_u128::mul_div_floor(1, 1, 3) == 0, 14); // 1/3 = 0 (floor)
        assert!(full_math_u128::mul_div_floor(2, 1, 3) == 0, 15); // 2/3 = 0 (floor)
        assert!(full_math_u128::mul_div_floor(3, 1, 3) == 1, 16); // 3/3 = 1
        assert!(full_math_u128::mul_div_floor(4, 1, 3) == 1, 17); // 4/3 = 1 (floor)
        assert!(full_math_u128::mul_div_floor(5, 1, 3) == 1, 18); // 5/3 = 1 (floor)
        assert!(full_math_u128::mul_div_floor(6, 1, 3) == 2, 19); // 6/3 = 2
    }
    
    #[test]
    public fun test_mul_div_round_basic() {
        // Basic round division tests  
        assert!(full_math_u128::mul_div_round(10, 5, 2) == 25, 20); // (10*5)/2 = 25
        assert!(full_math_u128::mul_div_round(7, 3, 2) == 11, 21); // (7*3)/2 = 21/2 = 10.5 -> 11 (round)
        assert!(full_math_u128::mul_div_round(100, 200, 50) == 400, 22); // (100*200)/50 = 400
    }
    
    #[test]
    public fun test_mul_div_round_precision() {
        // Test rounding behavior (rounds to nearest, .5 rounds up)
        assert!(full_math_u128::mul_div_round(1, 1, 3) == 0, 23); // 1/3 = 0.33... -> 0
        assert!(full_math_u128::mul_div_round(2, 1, 3) == 1, 24); // 2/3 = 0.66... -> 1  
        assert!(full_math_u128::mul_div_round(3, 1, 3) == 1, 25); // 3/3 = 1
        assert!(full_math_u128::mul_div_round(4, 1, 3) == 1, 26); // 4/3 = 1.33... -> 1
        assert!(full_math_u128::mul_div_round(5, 1, 3) == 2, 27); // 5/3 = 1.66... -> 2
        assert!(full_math_u128::mul_div_round(6, 1, 3) == 2, 28); // 6/3 = 2
    }
    
    #[test]
    public fun test_mul_div_ceil_basic() {
        // Basic ceiling division tests
        assert!(full_math_u128::mul_div_ceil(10, 5, 2) == 25, 29); // (10*5)/2 = 25
        assert!(full_math_u128::mul_div_ceil(7, 3, 2) == 11, 30); // (7*3)/2 = 21/2 = 10.5 -> 11 (ceil)
        assert!(full_math_u128::mul_div_ceil(100, 200, 50) == 400, 31); // (100*200)/50 = 400
    }
    
    #[test]
    public fun test_mul_div_ceil_precision() {
        // Test ceiling behavior
        assert!(full_math_u128::mul_div_ceil(1, 1, 3) == 1, 32); // 1/3 = 0.33... -> 1 (ceil)
        assert!(full_math_u128::mul_div_ceil(2, 1, 3) == 1, 33); // 2/3 = 0.66... -> 1 (ceil)
        assert!(full_math_u128::mul_div_ceil(3, 1, 3) == 1, 34); // 3/3 = 1
        assert!(full_math_u128::mul_div_ceil(4, 1, 3) == 2, 35); // 4/3 = 1.33... -> 2 (ceil)
        assert!(full_math_u128::mul_div_ceil(5, 1, 3) == 2, 36); // 5/3 = 1.66... -> 2 (ceil)
        assert!(full_math_u128::mul_div_ceil(6, 1, 3) == 2, 37); // 6/3 = 2
    }
    
    #[test]
    public fun test_rounding_modes_comparison() {
        // Compare all three rounding modes for the same computation
        test_rounding_comparison(7, 3, 2, 10, 11, 11, 38); // 21/2 = 10.5
        test_rounding_comparison(5, 1, 3, 1, 2, 2, 42); // 5/3 = 1.66...
        test_rounding_comparison(1, 1, 3, 0, 0, 1, 46); // 1/3 = 0.33...
        test_rounding_comparison(8, 1, 4, 2, 2, 2, 50); // 8/4 = 2 (exact)
    }
    
    fun test_rounding_comparison(
        num1: u128, num2: u128, denom: u128,
        expected_floor: u128, expected_round: u128, expected_ceil: u128,
        error_base: u64
    ) {
        let floor_result = full_math_u128::mul_div_floor(num1, num2, denom);
        let round_result = full_math_u128::mul_div_round(num1, num2, denom);
        let ceil_result = full_math_u128::mul_div_ceil(num1, num2, denom);
        
        assert!(floor_result == expected_floor, error_base);
        assert!(round_result == expected_round, error_base + 1);
        assert!(ceil_result == expected_ceil, error_base + 2);
        
        // Verify mathematical properties: floor <= round <= ceil
        assert!(floor_result <= round_result, error_base + 3);
        assert!(round_result <= ceil_result, error_base + 4);
    }
    
    #[test]
    public fun test_mul_shr_basic() {
        // Basic right shift tests
        assert!(full_math_u128::mul_shr(16, 1, 4) == 1, 54); // (16*1) >> 4 = 16 >> 4 = 1
        assert!(full_math_u128::mul_shr(32, 2, 5) == 2, 55); // (32*2) >> 5 = 64 >> 5 = 2
        assert!(full_math_u128::mul_shr(100, 200, 8) == 78, 56); // (100*200) >> 8 = 20000 >> 8 = 78
    }
    
    #[test]
    public fun test_mul_shr_edge_cases() {
        // Test with shift of 0 (no shift)
        assert!(full_math_u128::mul_shr(10, 5, 0) == 50, 57);
        
        // Test with large shifts
        assert!(full_math_u128::mul_shr(0xffffffff, 0xffffffff, 32) == 0xfffffffe, 58);
        
        // Test shift by 64
        let large_val = (0xffffffffffffffff as u128); // 2^64 - 1
        let result = full_math_u128::mul_shr(large_val, large_val, 64);
        // (2^64-1)^2 >> 64 should be approximately 2^64-2
        assert!(result == 0xfffffffffffffffe, 59);
    }
    
    #[test]
    public fun test_mul_shl_basic() {
        // Basic left shift tests
        assert!(full_math_u128::mul_shl(1, 1, 4) == 16, 60); // (1*1) << 4 = 1 << 4 = 16
        assert!(full_math_u128::mul_shl(2, 3, 5) == 192, 61); // (2*3) << 5 = 6 << 5 = 192
        assert!(full_math_u128::mul_shl(10, 20, 2) == 800, 62); // (10*20) << 2 = 200 << 2 = 800
    }
    
    #[test]
    public fun test_mul_shl_edge_cases() {
        // Test with shift of 0 (no shift)
        assert!(full_math_u128::mul_shl(10, 5, 0) == 50, 63);
        
        // Test with small values and larger shifts
        assert!(full_math_u128::mul_shl(1, 1, 10) == 1024, 64); // 1 << 10 = 2^10 = 1024
        assert!(full_math_u128::mul_shl(3, 4, 8) == 3072, 65); // (3*4) << 8 = 12 << 8 = 3072
    }
    
    #[test]
    public fun test_shift_operations_inverse() {
        // Test that shl followed by shr returns to original (when possible)
        test_shift_inverse(10, 20, 4, 66);
        test_shift_inverse(100, 300, 8, 67);
        test_shift_inverse(1, 1, 10, 68);
    }
    
    fun test_shift_inverse(num1: u128, num2: u128, shift: u8, error_code: u64) {
        let original_product = num1 * num2;
        let shifted_left = full_math_u128::mul_shl(num1, num2, shift);
        let back_to_original = full_math_u128::mul_shr(1, shifted_left, shift);
        
        // Should be close to original product (exact if no truncation)
        assert!(back_to_original == original_product, error_code);
    }
    
    #[test]
    public fun test_large_number_operations() {
        // Test with large u128 values
        let large1 = 1208925819614629174706175u128; // Large value
        let large2 = 4503599627370495u128; // Another large value
        
        // Test mul_div operations with large numbers
        let floor_result = full_math_u128::mul_div_floor(large1, large2, large1);
        assert!(floor_result == large2, 69); // (a*b)/a should equal b
        
        let ceil_result = full_math_u128::mul_div_ceil(large1, large2, large1);
        assert!(ceil_result == large2, 70);
        
        let round_result = full_math_u128::mul_div_round(large1, large2, large1);
        assert!(round_result == large2, 71);
    }
    
    #[test] 
    public fun test_division_by_one() {
        // Test division by 1 (should return the product)
        assert!(full_math_u128::mul_div_floor(123, 456, 1) == 123 * 456, 72);
        assert!(full_math_u128::mul_div_round(123, 456, 1) == 123 * 456, 73);
        assert!(full_math_u128::mul_div_ceil(123, 456, 1) == 123 * 456, 74);
        
        // Test with larger numbers
        let a = 281474976710655u128; // 0xffffffffffff
        let b = 281474976710655u128; // 0xffffffffffff
        let product = a * b; // This fits in u128
        
        assert!(full_math_u128::mul_div_floor(a, b, 1) == product, 75);
        assert!(full_math_u128::mul_div_round(a, b, 1) == product, 76);
        assert!(full_math_u128::mul_div_ceil(a, b, 1) == product, 77);
    }
    
    #[test]
    public fun test_zero_multiplication() {
        // Test multiplication with zero
        assert!(full_math_u128::mul_div_floor(0, 12345, 100) == 0, 78);
        assert!(full_math_u128::mul_div_round(0, 12345, 100) == 0, 79);
        assert!(full_math_u128::mul_div_ceil(0, 12345, 100) == 0, 80);
        
        assert!(full_math_u128::mul_div_floor(12345, 0, 100) == 0, 81);
        assert!(full_math_u128::mul_div_round(12345, 0, 100) == 0, 82);
        assert!(full_math_u128::mul_div_ceil(12345, 0, 100) == 0, 83);
        
        // Test shift operations with zero
        assert!(full_math_u128::mul_shr(0, 12345, 8) == 0, 84);
        assert!(full_math_u128::mul_shl(0, 12345, 8) == 0, 85);
        assert!(full_math_u128::mul_shr(12345, 0, 8) == 0, 86);
        assert!(full_math_u128::mul_shl(12345, 0, 8) == 0, 87);
    }
    
    #[test]
    public fun test_mathematical_properties() {
        // Test various mathematical properties
        test_mathematical_invariants(100, 200, 50, 88);
        test_mathematical_invariants(7, 11, 3, 92);
        test_mathematical_invariants(1000, 2000, 333, 96);
    }
    
    fun test_mathematical_invariants(num1: u128, num2: u128, denom: u128, error_base: u64) {
        let floor_result = full_math_u128::mul_div_floor(num1, num2, denom);
        let ceil_result = full_math_u128::mul_div_ceil(num1, num2, denom);
        
        // Ceiling should be >= floor
        assert!(ceil_result >= floor_result, error_base);
        
        // For exact divisions, all methods should give same result
        if ((num1 * num2) % denom == 0) {
            let round_result = full_math_u128::mul_div_round(num1, num2, denom);
            assert!(floor_result == ceil_result, error_base + 1);
            assert!(floor_result == round_result, error_base + 2);
        } else {
            // For non-exact divisions, ceil should be exactly floor + 1
            assert!(ceil_result == floor_result + 1, error_base + 3);
        }
    }
    
    #[test]
    public fun test_precision_preservation() {
        // Test that full precision multiplication preserves accuracy
        let a = 1000000000000u128; // 10^12
        let b = 1000000000000u128; // 10^12  
        let c = 1000000000u128; // 10^9
        
        // (10^12 * 10^12) / 10^9 = 10^15
        let expected = 1000000000000000u128; // 10^15
        
        let floor_result = full_math_u128::mul_div_floor(a, b, c);
        let round_result = full_math_u128::mul_div_round(a, b, c);
        let ceil_result = full_math_u128::mul_div_ceil(a, b, c);
        
        // Should all be exact since this is an exact division
        assert!(floor_result == expected, 100);
        assert!(round_result == expected, 101);
        assert!(ceil_result == expected, 102);
        
        // Verify using full_mul directly
        let full_product = full_math_u128::full_mul(a, b);
        let expected_u256 = (expected as u256) * (c as u256);
        assert!(full_product == expected_u256, 103);
    }
    
    #[test]
    public fun test_boundary_conditions() {
        // Test near maximum u128 values
        let near_max = 340282366920938463463374607431768211200u128; // Close to max u128
        
        // Test operations that should fit in u128
        assert!(full_math_u128::mul_div_floor(near_max, 1, near_max) == 1, 104);
        assert!(full_math_u128::mul_div_ceil(near_max, 1, near_max) == 1, 105);
        assert!(full_math_u128::mul_div_round(near_max, 1, near_max) == 1, 106);
        
        // Test shift operations at boundaries
        let shifted_right = full_math_u128::mul_shr(near_max, 1, 120); // Large right shift
        assert!(shifted_right == (near_max >> 120), 107);
        
        let small_val = 255u128; // 0xff
        let shifted_left = full_math_u128::mul_shl(small_val, 1, 8);
        assert!(shifted_left == (small_val << 8), 108);
    }
}