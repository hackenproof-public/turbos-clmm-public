// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::full_math_u32_tests {
    use turbos_clmm::full_math_u32;

    #[test]
    public fun test_full_mul_basic() {
        // Basic multiplication tests
        assert!(full_math_u32::full_mul(0, 0) == 0, 1);
        assert!(full_math_u32::full_mul(1, 0) == 0, 2);
        assert!(full_math_u32::full_mul(0, 1) == 0, 3);
        assert!(full_math_u32::full_mul(1, 1) == 1, 4);
        assert!(full_math_u32::full_mul(10, 20) == 200, 5);
        assert!(full_math_u32::full_mul(123, 456) == 56088, 6);
    }

    #[test]
    public fun test_full_mul_boundary() {
        // Boundary value tests
        let max_u32 = 4294967295u32; // 2^32 - 1
        
        // Test with max values
        assert!(full_math_u32::full_mul(max_u32, 1) == (max_u32 as u64), 7);
        assert!(full_math_u32::full_mul(1, max_u32) == (max_u32 as u64), 8);
        
        // Test large multiplication
        assert!(full_math_u32::full_mul(65536, 65536) == 4294967296, 9); // 2^16 * 2^16 = 2^32
        assert!(full_math_u32::full_mul(max_u32, max_u32) == 18446744065119617025, 10); // (2^32-1)^2
    }

    #[test]
    public fun test_mul_div_floor_basic() {
        // Basic mul_div_floor tests
        assert!(full_math_u32::mul_div_floor(10, 20, 5) == 40, 11);
        assert!(full_math_u32::mul_div_floor(100, 50, 25) == 200, 12);
        assert!(full_math_u32::mul_div_floor(7, 3, 2) == 10, 13); // 21 / 2 = 10 (floor)
    }

    #[test]
    public fun test_mul_div_floor_zero() {
        // Zero cases
        assert!(full_math_u32::mul_div_floor(0, 100, 50) == 0, 14);
        assert!(full_math_u32::mul_div_floor(100, 0, 50) == 0, 15);
    }

    #[test]
    public fun test_mul_div_floor_precision() {
        // Test precision and rounding down
        assert!(full_math_u32::mul_div_floor(10, 3, 4) == 7, 16); // 30 / 4 = 7.5 -> 7 (floor)
        assert!(full_math_u32::mul_div_floor(5, 7, 3) == 11, 17); // 35 / 3 = 11.67 -> 11 (floor)
    }

    #[test]
    public fun test_mul_div_round_basic() {
        // Basic rounding tests
        assert!(full_math_u32::mul_div_round(10, 20, 5) == 40, 18);
        assert!(full_math_u32::mul_div_round(10, 3, 4) == 8, 19); // 30 / 4 = 7.5 -> 8 (round)
        assert!(full_math_u32::mul_div_round(5, 7, 3) == 12, 20); // 35 / 3 = 11.67 -> 12 (round)
    }

    #[test]
    public fun test_mul_div_round_edge_cases() {
        // Edge cases for rounding
        assert!(full_math_u32::mul_div_round(1, 1, 2) == 1, 21); // 1 / 2 = 0.5 -> 1 (round up)
        assert!(full_math_u32::mul_div_round(2, 1, 4) == 1, 22); // 2 / 4 = 0.5 -> 1 (round up)
        assert!(full_math_u32::mul_div_round(1, 1, 4) == 0, 23); // 1 / 4 = 0.25 -> 0 (round down)
    }

    #[test]
    public fun test_mul_div_ceil_basic() {
        // Basic ceiling tests
        assert!(full_math_u32::mul_div_ceil(10, 20, 5) == 40, 24);
        assert!(full_math_u32::mul_div_ceil(10, 3, 4) == 8, 25); // 30 / 4 = 7.5 -> 8 (ceil)
        assert!(full_math_u32::mul_div_ceil(5, 7, 3) == 12, 26); // 35 / 3 = 11.67 -> 12 (ceil)
    }

    #[test]
    public fun test_mul_div_ceil_edge_cases() {
        // Edge cases for ceiling
        assert!(full_math_u32::mul_div_ceil(1, 1, 2) == 1, 27); // 1 / 2 = 0.5 -> 1 (ceil)
        assert!(full_math_u32::mul_div_ceil(1, 1, 4) == 1, 28); // 1 / 4 = 0.25 -> 1 (ceil)
        assert!(full_math_u32::mul_div_ceil(1, 1, 1) == 1, 29); // 1 / 1 = 1.0 -> 1 (exact)
    }

    #[test]
    public fun test_mul_shr_basic() {
        // Basic right shift tests
        assert!(full_math_u32::mul_shr(16, 8, 1) == 64, 30); // 128 >> 1 = 64
        assert!(full_math_u32::mul_shr(32, 4, 2) == 32, 31); // 128 >> 2 = 32
        assert!(full_math_u32::mul_shr(100, 10, 0) == 1000, 32); // 1000 >> 0 = 1000
    }

    #[test]
    public fun test_mul_shr_edge_cases() {
        // Edge cases for right shift
        assert!(full_math_u32::mul_shr(0, 100, 5) == 0, 33);
        assert!(full_math_u32::mul_shr(1, 1, 32) == 0, 34); // Shift by 32 makes result 0
        assert!(full_math_u32::mul_shr(256, 256, 8) == 256, 35); // 65536 >> 8 = 256
    }

    #[test]
    public fun test_mul_shl_basic() {
        // Basic left shift tests
        assert!(full_math_u32::mul_shl(8, 4, 1) == 64, 36); // 32 << 1 = 64
        assert!(full_math_u32::mul_shl(10, 5, 2) == 200, 37); // 50 << 2 = 200
        assert!(full_math_u32::mul_shl(100, 10, 0) == 1000, 38); // 1000 << 0 = 1000
    }

    #[test]
    public fun test_mul_shl_edge_cases() {
        // Edge cases for left shift
        assert!(full_math_u32::mul_shl(0, 100, 5) == 0, 39);
        assert!(full_math_u32::mul_shl(1, 1, 10) == 1024, 40); // 1 << 10 = 1024
    }

    #[test]
    public fun test_rounding_comparison() {
        // Compare floor, round, and ceil for the same inputs
        let num1 = 10u32;
        let num2 = 7u32;
        let denom = 3u32;
        
        let floor_result = full_math_u32::mul_div_floor(num1, num2, denom);
        let round_result = full_math_u32::mul_div_round(num1, num2, denom);
        let ceil_result = full_math_u32::mul_div_ceil(num1, num2, denom);
        
        // 70 / 3 = 23.33... -> floor: 23, round: 23, ceil: 24
        assert!(floor_result == 23, 41);
        assert!(round_result == 23, 42); 
        assert!(ceil_result == 24, 43);
        assert!(floor_result <= round_result, 44);
        assert!(round_result <= ceil_result, 45);
    }

    #[test]
    public fun test_high_precision_calculations() {
        // Test calculations that require the full u64 intermediate result
        let large_num1 = 1000000u32;
        let large_num2 = 2000u32;
        let large_denom = 500u32;
        
        // 1000000 * 2000 / 500 = 4000000
        assert!(full_math_u32::mul_div_floor(large_num1, large_num2, large_denom) == 4000000, 46);
        assert!(full_math_u32::mul_div_round(large_num1, large_num2, large_denom) == 4000000, 47);
        assert!(full_math_u32::mul_div_ceil(large_num1, large_num2, large_denom) == 4000000, 48);
    }

    #[test]
    public fun test_shift_operations_consistency() {
        // Test that shift operations are consistent
        let num1 = 256u32;
        let num2 = 16u32;
        
        // Verify: mul_shl(a, b, n) * mul_shr(c, d, n) relationship
        let shl_result = full_math_u32::mul_shl(num1, num2, 2); // (256 * 16) << 2 = 16384
        let shr_result = full_math_u32::mul_shr(num1, num2, 2); // (256 * 16) >> 2 = 1024
        
        assert!(shl_result == 16384, 49);
        assert!(shr_result == 1024, 50);
        assert!(shl_result / shr_result == 16, 51); // 2^4 relationship
    }
}