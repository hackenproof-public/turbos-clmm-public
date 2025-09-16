// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::math_u256_comprehensive_tests {
    use std::vector;
    use turbos_clmm::math_u256::{Self};

    #[test]
    public fun test_div_mod_basic() {
        // Basic division tests
        let (quotient, remainder) = math_u256::div_mod(10u256, 3u256);
        assert!(quotient == 3u256, 1);
        assert!(remainder == 1u256, 2);
        
        // Perfect division
        let (quotient, remainder) = math_u256::div_mod(15u256, 3u256);
        assert!(quotient == 5u256, 3);
        assert!(remainder == 0u256, 4);
        
        // Division by 1
        let (quotient, remainder) = math_u256::div_mod(100u256, 1u256);
        assert!(quotient == 100u256, 5);
        assert!(remainder == 0u256, 6);
    }
    
    #[test]
    public fun test_div_mod_edge_cases() {
        // Division where numerator < denominator
        let (quotient, remainder) = math_u256::div_mod(5u256, 10u256);
        assert!(quotient == 0u256, 7);
        assert!(remainder == 5u256, 8);
        
        // Self division
        let (quotient, remainder) = math_u256::div_mod(42u256, 42u256);
        assert!(quotient == 1u256, 9);
        assert!(remainder == 0u256, 10);
    }
    
    #[test]
    public fun test_div_mod_large_numbers() {
        // Test with larger numbers
        let large_num = 0xffffffffffffffffffffffffffffffffu256;
        let divisor = 0x10000000000000000u256;
        let (quotient, remainder) = math_u256::div_mod(large_num, divisor);
        
        // Verify the invariant: num = quotient * divisor + remainder
        let reconstructed = quotient * divisor + remainder;
        assert!(reconstructed == large_num, 11);
        assert!(remainder < divisor, 12); // remainder should be less than divisor
    }
    
    #[test]
    public fun test_shlw_basic() {
        // Shift left by 64 bits (equivalent to multiplying by 2^64)
        let result = math_u256::shlw(1u256);
        assert!(result == 0x10000000000000000u256, 13); // 2^64
        
        let result = math_u256::shlw(2u256);
        assert!(result == 0x20000000000000000u256, 14); // 2 * 2^64
        
        let result = math_u256::shlw(0u256);
        assert!(result == 0u256, 15);
    }
    
    #[test]
    public fun test_shlw_various_inputs() {
        // Test with hex values
        let result = math_u256::shlw(0xffffu256);
        assert!(result == 0xffff0000000000000000u256, 16);
        
        // Test with larger input
        let result = math_u256::shlw(0x123456789abcdefu256);
        assert!(result == 0x123456789abcdef0000000000000000u256, 17);
    }
    
    #[test]
    public fun test_shrw_basic() {
        // Shift right by 64 bits (equivalent to dividing by 2^64)
        let result = math_u256::shrw(0x10000000000000000u256); // 2^64
        assert!(result == 1u256, 18);
        
        let result = math_u256::shrw(0x20000000000000000u256); // 2 * 2^64
        assert!(result == 2u256, 19);
        
        let result = math_u256::shrw(0u256);
        assert!(result == 0u256, 20);
    }
    
    #[test]
    public fun test_shrw_various_inputs() {
        // Test with larger values
        let result = math_u256::shrw(0xffffffffffffffff0000000000000000u256);
        assert!(result == 0xffffffffffffffffu256, 21);
        
        // Test truncation behavior
        let result = math_u256::shrw(0xffffffffffffffffu256); // Max u64 value
        assert!(result == 0u256, 22); // Should truncate to 0
        
        // Test with mid-range value
        let result = math_u256::shrw(0x123456789abcdef0000000000000000u256);
        assert!(result == 0x123456789abcdefu256, 23);
    }
    
    #[test]
    public fun test_shlw_shrw_inverse() {
        // Test that shlw and shrw are inverses (when no truncation occurs)
        let original = 0x123456789abcdefu256;
        let shifted_left = math_u256::shlw(original);
        let back_to_original = math_u256::shrw(shifted_left);
        assert!(back_to_original == original, 24);
        
        // Test with another value
        let original = 0xffffffffu256;
        let shifted_left = math_u256::shlw(original);
        let back_to_original = math_u256::shrw(shifted_left);
        assert!(back_to_original == original, 25);
    }
    
    #[test]
    public fun test_checked_shlw_safe_cases() {
        // Safe shift that doesn't overflow
        let (result, overflow) = math_u256::checked_shlw(1u256);
        assert!(result == 0x10000000000000000u256, 26); // 2^64
        assert!(!overflow, 27);
        
        // Another safe case
        let (result, overflow) = math_u256::checked_shlw(0xffffu256);
        assert!(result == 0xffff0000000000000000u256, 28);
        assert!(!overflow, 29);
        
        // Zero case
        let (result, overflow) = math_u256::checked_shlw(0u256);
        assert!(result == 0u256, 30);
        assert!(!overflow, 31);
    }
    
    #[test]
    public fun test_checked_shlw_overflow_cases() {
        // Test overflow boundary - 2^192 should cause overflow
        let mask = 1u256 << 192;
        let (result, overflow) = math_u256::checked_shlw(mask);
        assert!(result == 0u256, 32);
        assert!(overflow, 33);
        
        // Test with value above the mask
        let large_val = mask + 1u256;
        let (result, overflow) = math_u256::checked_shlw(large_val);
        assert!(result == 0u256, 34);
        assert!(overflow, 35);
        
        // Test with maximum possible u256
        let max_u256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffu256;
        let (result, overflow) = math_u256::checked_shlw(max_u256);
        assert!(result == 0u256, 36);
        assert!(overflow, 37);
    }
    
    #[test]
    public fun test_checked_shlw_boundary() {
        // Test just below the overflow boundary
        let mask = 1u256 << 192;
        let just_below = mask - 1u256;
        let (result, overflow) = math_u256::checked_shlw(just_below);
        assert!(!overflow, 38); // Should not overflow
        assert!(result != 0u256, 39); // Should have a valid result
    }
    
    #[test]
    public fun test_div_round_no_rounding() {
        // Perfect division, no rounding needed
        assert!(math_u256::div_round(10u256, 2u256, false) == 5u256, 40);
        assert!(math_u256::div_round(10u256, 2u256, true) == 5u256, 41);
        
        // Another perfect division
        assert!(math_u256::div_round(100u256, 25u256, false) == 4u256, 42);
        assert!(math_u256::div_round(100u256, 25u256, true) == 4u256, 43);
    }
    
    #[test]
    public fun test_div_round_with_remainder_round_down() {
        // Division with remainder, round_up = false
        assert!(math_u256::div_round(10u256, 3u256, false) == 3u256, 44);
        assert!(math_u256::div_round(7u256, 2u256, false) == 3u256, 45);
        assert!(math_u256::div_round(99u256, 10u256, false) == 9u256, 46);
    }
    
    #[test]
    public fun test_div_round_with_remainder_round_up() {
        // Division with remainder, round_up = true
        assert!(math_u256::div_round(10u256, 3u256, true) == 4u256, 47);
        assert!(math_u256::div_round(7u256, 2u256, true) == 4u256, 48);
        assert!(math_u256::div_round(99u256, 10u256, true) == 10u256, 49);
    }
    
    #[test]
    public fun test_div_round_edge_cases() {
        // Division by 1
        assert!(math_u256::div_round(42u256, 1u256, false) == 42u256, 50);
        assert!(math_u256::div_round(42u256, 1u256, true) == 42u256, 51);
        
        // Numerator smaller than denominator
        assert!(math_u256::div_round(3u256, 10u256, false) == 0u256, 52);
        assert!(math_u256::div_round(3u256, 10u256, true) == 1u256, 53);
        
        // Self division
        assert!(math_u256::div_round(42u256, 42u256, false) == 1u256, 54);
        assert!(math_u256::div_round(42u256, 42u256, true) == 1u256, 55);
    }
    
    #[test]
    public fun test_div_round_large_numbers() {
        // Test with larger numbers
        let large_num = 0xffffffffffffffffffffffffu256;
        let divisor = 0x1000000000000000u256;
        
        // Test both rounding modes
        let result_down = math_u256::div_round(large_num, divisor, false);
        let result_up = math_u256::div_round(large_num, divisor, true);
        
        // result_up should be >= result_down
        assert!(result_up >= result_down, 56);
        
        // If there's a remainder, result_up should be exactly result_down + 1
        let (quotient, remainder) = math_u256::div_mod(large_num, divisor);
        assert!(result_down == quotient, 57);
        if (remainder != 0) {
            assert!(result_up == quotient + 1, 58);
        } else {
            assert!(result_up == quotient, 59);
        }
    }
    
    #[test]
    public fun test_comprehensive_function_interactions() {
        // Test combinations of functions to ensure they work together
        let original = 0x123456789abcdefu256;
        
        // Apply shlw then div_mod
        let shifted = math_u256::shlw(original);
        let (quotient, remainder) = math_u256::div_mod(shifted, 0x1000u256);
        
        // Verify result makes sense
        assert!(quotient * 0x1000u256 + remainder == shifted, 60);
        
        // Test checked_shlw with div_round
        let (shifted_checked, overflow) = math_u256::checked_shlw(0xffffu256);
        assert!(!overflow, 61);
        
        let rounded_result = math_u256::div_round(shifted_checked, 0x1000000000000000u256, true);
        assert!(rounded_result > 0, 62);
    }
    
    #[test] 
    public fun test_bit_manipulation_consistency() {
        // Test specific values for bit operation consistency
        test_bit_consistency(1u256, 63);
        test_bit_consistency(0xffffu256, 64);
        test_bit_consistency(0xffffffffu256, 65);
        test_bit_consistency(0xffffffffffffffffu256, 66);
        test_bit_consistency(0x123456789abcdef0u256, 67);
    }
    
    fun test_bit_consistency(val: u256, error_code: u64) {
        // Test shlw/shrw consistency
        let shifted_left = math_u256::shlw(val);
        let shifted_back = math_u256::shrw(shifted_left);
        assert!(shifted_back == val, error_code);
        
        // Test checked_shlw consistency for safe values
        let (checked_result, overflow) = math_u256::checked_shlw(val);
        if (!overflow) {
            assert!(checked_result == shifted_left, error_code + 5);
        }
    }
    
    #[test]
    public fun test_division_properties() {
        // Test mathematical properties of division operations with specific pairs
        test_division_pair(100u256, 7u256, 73);
        test_division_pair(1000u256, 13u256, 76);
        test_division_pair(0xffffffffu256, 17u256, 79);
        test_division_pair(255u256, 16u256, 82);
    }
    
    fun test_division_pair(num: u256, denom: u256, error_base: u64) {
        // Test div_mod properties
        let (quotient, remainder) = math_u256::div_mod(num, denom);
        assert!(remainder < denom, error_base); // remainder should be less than divisor
        assert!(quotient * denom + remainder == num, error_base + 1); // fundamental division property
        
        // Test div_round consistency
        let round_down = math_u256::div_round(num, denom, false);
        let round_up = math_u256::div_round(num, denom, true);
        assert!(round_down == quotient, error_base + 2); // round_down should equal quotient from div_mod
        
        if (remainder == 0) {
            assert!(round_up == round_down, error_base + 3); // no rounding needed if no remainder
        } else {
            assert!(round_up == round_down + 1, error_base + 4); // round_up should be quotient + 1 if there's remainder
        }
    }
}