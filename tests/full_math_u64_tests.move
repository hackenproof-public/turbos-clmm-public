// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::full_math_u64_tests {
    use turbos_clmm::full_math_u64;

    #[test]
    public fun test_full_mul_basic() {
        // Basic multiplication tests
        assert!(full_math_u64::full_mul(0, 0) == 0, 1);
        assert!(full_math_u64::full_mul(1, 0) == 0, 2);
        assert!(full_math_u64::full_mul(0, 1) == 0, 3);
        assert!(full_math_u64::full_mul(1, 1) == 1, 4);
        assert!(full_math_u64::full_mul(1000, 2000) == 2000000, 5);
        assert!(full_math_u64::full_mul(123456, 789012) == 97408265472, 6);
    }

    #[test]
    public fun test_full_mul_boundary() {
        // Boundary value tests
        let max_u64 = 18446744073709551615u64; // 2^64 - 1
        
        // Test with max values
        assert!(full_math_u64::full_mul(max_u64, 1) == (max_u64 as u128), 7);
        assert!(full_math_u64::full_mul(1, max_u64) == (max_u64 as u128), 8);
        
        // Test large multiplication
        assert!(full_math_u64::full_mul(4294967296, 4294967296) == 18446744073709551616, 9); // 2^32 * 2^32 = 2^64
        
        // Test maximum possible multiplication (would be (2^64-1)^2)
        let large_num = 1000000000000u64;
        assert!(full_math_u64::full_mul(large_num, large_num) == 1000000000000000000000000u128, 10);
    }

    #[test]
    public fun test_mul_div_floor_basic() {
        // Basic mul_div_floor tests
        assert!(full_math_u64::mul_div_floor(1000, 2000, 500) == 4000, 11);
        assert!(full_math_u64::mul_div_floor(10000, 5000, 2500) == 20000, 12);
        assert!(full_math_u64::mul_div_floor(700, 300, 200) == 1050, 13); // 210000 / 200 = 1050 (exact)
    }

    #[test]
    public fun test_mul_div_floor_zero() {
        // Zero cases
        assert!(full_math_u64::mul_div_floor(0, 1000000, 500000) == 0, 14);
        assert!(full_math_u64::mul_div_floor(1000000, 0, 500000) == 0, 15);
    }

    #[test]
    public fun test_mul_div_floor_precision() {
        // Test precision and rounding down
        assert!(full_math_u64::mul_div_floor(1000, 300, 400) == 750, 16); // 300000 / 400 = 750 (exact)
        assert!(full_math_u64::mul_div_floor(500, 700, 300) == 1166, 17); // 350000 / 300 = 1166.67 -> 1166 (floor)
    }

    #[test]
    public fun test_mul_div_round_basic() {
        // Basic rounding tests
        assert!(full_math_u64::mul_div_round(1000, 2000, 500) == 4000, 18);
        assert!(full_math_u64::mul_div_round(1000, 300, 400) == 750, 19); // 300000 / 400 = 750 (exact)
        assert!(full_math_u64::mul_div_round(500, 700, 300) == 1167, 20); // 350000 / 300 = 1166.67 -> 1167 (round)
    }

    #[test]
    public fun test_mul_div_round_edge_cases() {
        // Edge cases for rounding
        assert!(full_math_u64::mul_div_round(100, 100, 200) == 50, 21); // 10000 / 200 = 50 (exact)
        assert!(full_math_u64::mul_div_round(100, 101, 200) == 51, 22); // 10100 / 200 = 50.5 -> 51 (round up)
        assert!(full_math_u64::mul_div_round(100, 99, 200) == 50, 23); // 9900 / 200 = 49.5 -> 50 (round up)
        assert!(full_math_u64::mul_div_round(100, 98, 200) == 49, 24); // 9800 / 200 = 49 (exact)
    }

    #[test]
    public fun test_mul_div_ceil_basic() {
        // Basic ceiling tests
        assert!(full_math_u64::mul_div_ceil(1000, 2000, 500) == 4000, 25);
        assert!(full_math_u64::mul_div_ceil(1000, 300, 400) == 750, 26); // 300000 / 400 = 750 (exact)
        assert!(full_math_u64::mul_div_ceil(500, 700, 300) == 1167, 27); // 350000 / 300 = 1166.67 -> 1167 (ceil)
    }

    #[test]
    public fun test_mul_div_ceil_edge_cases() {
        // Edge cases for ceiling
        assert!(full_math_u64::mul_div_ceil(100, 100, 200) == 50, 28); // 10000 / 200 = 50 (exact)
        assert!(full_math_u64::mul_div_ceil(100, 99, 200) == 50, 29); // 9900 / 200 = 49.5 -> 50 (ceil)
        assert!(full_math_u64::mul_div_ceil(100, 1, 200) == 1, 30); // 100 / 200 = 0.5 -> 1 (ceil)
        assert!(full_math_u64::mul_div_ceil(1, 1, 1) == 1, 31); // 1 / 1 = 1.0 -> 1 (exact)
    }

    #[test]
    public fun test_mul_shr_basic() {
        // Basic right shift tests
        assert!(full_math_u64::mul_shr(1600, 800, 1) == 640000, 32); // 1280000 >> 1 = 640000
        assert!(full_math_u64::mul_shr(3200, 400, 2) == 320000, 33); // 1280000 >> 2 = 320000
        assert!(full_math_u64::mul_shr(10000, 1000, 0) == 10000000, 34); // 10000000 >> 0 = 10000000
    }

    #[test]
    public fun test_mul_shr_edge_cases() {
        // Edge cases for right shift
        assert!(full_math_u64::mul_shr(0, 1000000, 5) == 0, 35);
        assert!(full_math_u64::mul_shr(1, 1, 64) == 0, 36); // Shift by 64 makes result 0
        assert!(full_math_u64::mul_shr(65536, 65536, 16) == 65536, 37); // 4294967296 >> 16 = 65536
    }

    #[test]
    public fun test_mul_shl_basic() {
        // Basic left shift tests
        assert!(full_math_u64::mul_shl(800, 400, 1) == 640000, 38); // 320000 << 1 = 640000
        assert!(full_math_u64::mul_shl(1000, 500, 2) == 2000000, 39); // 500000 << 2 = 2000000
        assert!(full_math_u64::mul_shl(10000, 1000, 0) == 10000000, 40); // 10000000 << 0 = 10000000
    }

    #[test]
    public fun test_mul_shl_edge_cases() {
        // Edge cases for left shift
        assert!(full_math_u64::mul_shl(0, 1000000, 5) == 0, 41);
        assert!(full_math_u64::mul_shl(1, 1, 20) == 1048576, 42); // 1 << 20 = 1048576
    }

    #[test]
    public fun test_rounding_comparison() {
        // Compare floor, round, and ceil for the same inputs
        let num1 = 10000u64;
        let num2 = 7777u64;
        let denom = 3333u64;
        
        let floor_result = full_math_u64::mul_div_floor(num1, num2, denom);
        let round_result = full_math_u64::mul_div_round(num1, num2, denom);
        let ceil_result = full_math_u64::mul_div_ceil(num1, num2, denom);
        
        // 77770000 / 3333 = 23333.33... -> floor: 23333, round: 23333, ceil: 23334
        assert!(floor_result == 23333, 43);
        assert!(round_result == 23333, 44); 
        assert!(ceil_result == 23334, 45);
        assert!(floor_result <= round_result, 46);
        assert!(round_result <= ceil_result, 47);
    }

    #[test]
    public fun test_high_precision_calculations() {
        // Test calculations that require the full u128 intermediate result
        let large_num1 = 1000000000000u64; // 10^12
        let large_num2 = 2000000u64; // 2 * 10^6
        let large_denom = 500000u64; // 5 * 10^5
        
        // 10^12 * 2*10^6 / 5*10^5 = 2*10^18 / 5*10^5 = 4*10^12
        let expected = 4000000000000u64;
        assert!(full_math_u64::mul_div_floor(large_num1, large_num2, large_denom) == expected, 48);
        assert!(full_math_u64::mul_div_round(large_num1, large_num2, large_denom) == expected, 49);
        assert!(full_math_u64::mul_div_ceil(large_num1, large_num2, large_denom) == expected, 50);
    }

    #[test]
    public fun test_shift_operations_consistency() {
        // Test that shift operations are consistent
        let num1 = 2560000u64;
        let num2 = 16384u64;
        
        // Verify: mul_shl(a, b, n) * mul_shr(c, d, n) relationship
        let shl_result = full_math_u64::mul_shl(num1, num2, 4); // (2560000 * 16384) << 4
        let shr_result = full_math_u64::mul_shr(num1, num2, 4); // (2560000 * 16384) >> 4
        
        let base_result = full_math_u64::full_mul(num1, num2);
        assert!(shl_result == ((base_result << 4) as u64), 51);
        assert!(shr_result == ((base_result >> 4) as u64), 52);
        assert!(shl_result / shr_result == 256, 53); // 2^8 relationship
    }

    #[test]
    public fun test_overflow_safety() {
        // Test that operations handle near-overflow cases properly
        let large_val = 4000000000u64; // 4 * 10^9
        
        // Test multiplication that would overflow u64 but fits in u128
        let result = full_math_u64::full_mul(large_val, large_val);
        assert!(result == 16000000000000000000u128, 54); // 16 * 10^18
        
        // Test div operations with large intermediate results
        assert!(full_math_u64::mul_div_floor(large_val, large_val, large_val) == large_val, 55);
        assert!(full_math_u64::mul_div_round(large_val, large_val, large_val) == large_val, 56);
        assert!(full_math_u64::mul_div_ceil(large_val, large_val, large_val) == large_val, 57);
    }

    #[test]
    public fun test_financial_precision() {
        // Test scenarios common in DeFi calculations
        let price = 1000000u64; // Price with 6 decimals: 1.0
        let amount = 50000000u64; // Amount with 6 decimals: 50.0
        let fee_rate = 3000u64; // 0.3% fee rate (3000 / 1000000)
        let fee_denom = 1000000u64;
        
        // Calculate fee: amount * price * fee_rate / fee_denom
        let fee = full_math_u64::mul_div_floor(amount, fee_rate, fee_denom);
        
        assert!(fee == 150000, 58); // 50 * 0.003 = 0.15 with 6 decimals = 150000
        
        // Test different rounding modes give expected results
        let floor_fee = full_math_u64::mul_div_floor(amount, fee_rate, fee_denom);
        let round_fee = full_math_u64::mul_div_round(amount, fee_rate, fee_denom);
        let ceil_fee = full_math_u64::mul_div_ceil(amount, fee_rate, fee_denom);
        
        assert!(floor_fee <= round_fee, 59);
        assert!(round_fee <= ceil_fee, 60);
    }
}