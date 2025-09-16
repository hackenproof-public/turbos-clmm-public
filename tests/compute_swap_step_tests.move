// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::compute_swap_step_tests {
    use turbos_clmm::math_swap;
    use sui::test_utils::{assert_eq};

    #[test]
    public fun compute_swap_max_liquidity_tests() {
        let price = 18446744073709551616;
        let price_target = 18212142134806087854; //1.01
        let liquidity = 18446744073709551616;
        let amount = 1000000000000;
        let fee = 10000;
        let (sqrt_price, step_amount_in, step_amount_out, step_fee_amount)  = math_swap::compute_swap(price, price_target, liquidity, amount, true, fee);

        assert_eq(sqrt_price, 18446743083709604748);
        assert_eq(step_amount_in, 990000000000);
        assert_eq(step_amount_out, 989999946868);
        assert_eq(step_fee_amount, 10000000000);
    }
}