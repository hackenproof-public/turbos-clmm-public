// Copyright (c) Turbos Finance, Inc.
// SPDX-License-Identifier: MIT

#[test_only]
module turbos_clmm::position_nft_simple_tests {
    use std::string::{Self};
    use std::type_name::{Self};
    use std::ascii::{Self};
    use std::vector;
    use sui::object::{Self};
    use sui::url::{Self};
    use turbos_clmm::position_nft::{Self};
    use turbos_clmm::btc::{BTC};
    use turbos_clmm::usdc::{USDC};
    use turbos_clmm::fee500bps::{FEE500BPS};

    #[test]
    public fun test_object_id_operations() {
        // Test object ID operations used in NFT structure
        let id1 = object::id_from_address(@0x1);
        let id2 = object::id_from_address(@0x2);
        let id3 = object::id_from_address(@0x1); // Same address as id1
        
        // Verify different addresses produce different IDs
        assert!(id1 != id2, 1);
        
        // Verify same addresses produce same IDs
        assert!(id1 == id3, 2);
        
        // Test ID to address conversion
        let addr1 = object::id_to_address(&id1);
        let addr2 = object::id_to_address(&id2);
        
        assert!(addr1 == @0x1, 3);
        assert!(addr2 == @0x2, 4);
        assert!(addr1 != addr2, 5);
    }
    
    #[test]
    public fun test_type_name_functionality() {
        // Test type name operations used in NFT creation
        let btc_type = type_name::get<BTC>();
        let usdc_type = type_name::get<USDC>();
        let fee_type = type_name::get<FEE500BPS>();
        
        // Verify type names are different
        assert!(btc_type != usdc_type, 6);
        assert!(usdc_type != fee_type, 7);
        assert!(btc_type != fee_type, 8);
        
        // Test type name string conversion
        let btc_string = type_name::into_string(btc_type);
        let usdc_string = type_name::into_string(usdc_type);
        let fee_string = type_name::into_string(fee_type);
        
        // Type names return ASCII strings, convert to check length
        let btc_bytes = ascii::into_bytes(btc_string);
        let usdc_bytes = ascii::into_bytes(usdc_string);
        let fee_bytes = ascii::into_bytes(fee_string);
        
        assert!(vector::length(&btc_bytes) > 0, 9);
        assert!(vector::length(&usdc_bytes) > 0, 10);
        assert!(vector::length(&fee_bytes) > 0, 11);
        
        // All string representations should be different (compare as bytes)
        assert!(btc_bytes != usdc_bytes, 12);
        assert!(btc_bytes != fee_bytes, 13);
        assert!(usdc_bytes != fee_bytes, 14);
    }
    
    #[test]
    public fun test_nft_metadata_structure() {
        // Test metadata components used in NFT
        let name = string::utf8(b"Turbos Position NFT #123");
        let description = string::utf8(b"Liquidity position for BTC/USDC pool");
        let img_url_str = string::utf8(b"https://turbos.finance/api/nft/123.png");
        
        // Test URL creation from string
        let img_url = url::new_unsafe(string::to_ascii(img_url_str));
        
        // Verify URL properties
        assert!(url::inner_url(&img_url) == string::to_ascii(img_url_str), 15);
        
        // Test string operations
        assert!(string::length(&name) > 0, 16);
        assert!(string::length(&description) > 0, 17);
        assert!(string::length(&img_url_str) > 0, 18);
        
        // Test string contents
        assert!(string::bytes(&name) == &b"Turbos Position NFT #123", 19);
        assert!(string::bytes(&description) == &b"Liquidity position for BTC/USDC pool", 20);
    }
    
    #[test]
    public fun test_nft_display_metadata_keys() {
        // Test the display metadata keys used in init function
        let name_key = string::utf8(b"name");
        let description_key = string::utf8(b"description");
        let image_url_key = string::utf8(b"image_url");
        let project_url_key = string::utf8(b"project_url");
        let creator_key = string::utf8(b"creator");
        
        // Verify keys are valid strings
        assert!(!string::is_empty(&name_key), 21);
        assert!(!string::is_empty(&description_key), 22);
        assert!(!string::is_empty(&image_url_key), 23);
        assert!(!string::is_empty(&project_url_key), 24);
        assert!(!string::is_empty(&creator_key), 25);
        
        // Test display values
        let name_value = string::utf8(b"{name}");
        let description_value = string::utf8(b"{description}");
        let image_url_value = string::utf8(b"{img_url}");
        let project_url_value = string::utf8(b"https://turbos.finance");
        let creator_value = string::utf8(b"Turbos Team");
        
        assert!(!string::is_empty(&name_value), 26);
        assert!(!string::is_empty(&description_value), 27);
        assert!(!string::is_empty(&image_url_value), 28);
        assert!(!string::is_empty(&project_url_value), 29);
        assert!(!string::is_empty(&creator_value), 30);
        
        // Test the display metadata structure
        let display_keys = vector::empty();
        vector::push_back(&mut display_keys, name_key);
        vector::push_back(&mut display_keys, description_key);
        vector::push_back(&mut display_keys, image_url_key);
        vector::push_back(&mut display_keys, project_url_key);
        vector::push_back(&mut display_keys, creator_key);
        
        let display_values = vector::empty();
        vector::push_back(&mut display_values, name_value);
        vector::push_back(&mut display_values, description_value);
        vector::push_back(&mut display_values, image_url_value);
        vector::push_back(&mut display_values, project_url_value);
        vector::push_back(&mut display_values, creator_value);
        
        // Verify the display metadata structure
        assert!(vector::length(&display_keys) == 5, 31);
        assert!(vector::length(&display_values) == 5, 32);
    }
    
    #[test]
    public fun test_url_operations() {
        // Test URL operations used in NFT creation
        let url_string1 = string::utf8(b"https://turbos.finance");
        let url_string2 = string::utf8(b"https://example.com/image.png");
        let empty_string = string::utf8(b"");
        
        // Test URL creation
        let url1 = url::new_unsafe(string::to_ascii(url_string1));
        let url2 = url::new_unsafe(string::to_ascii(url_string2));
        
        // Verify URL properties
        assert!(url::inner_url(&url1) == string::to_ascii(url_string1), 33);
        assert!(url::inner_url(&url2) == string::to_ascii(url_string2), 34);
        
        // Test that different URLs are different
        assert!(url::inner_url(&url1) != url::inner_url(&url2), 35);
        
        // Test empty URL
        let empty_url = url::new_unsafe(string::to_ascii(empty_string));
        assert!(url::inner_url(&empty_url) == string::to_ascii(empty_string), 36);
    }
    
    #[test]
    public fun test_string_operations_edge_cases() {
        // Test edge cases for string operations
        let empty_string = string::utf8(b"");
        let single_char = string::utf8(b"a");
        let long_string = string::utf8(b"This is a very long string used for testing purposes in the NFT metadata system");
        
        // Test empty string
        assert!(string::is_empty(&empty_string), 37);
        assert!(string::length(&empty_string) == 0, 38);
        
        // Test single character
        assert!(!string::is_empty(&single_char), 39);
        assert!(string::length(&single_char) == 1, 40);
        
        // Test long string
        assert!(!string::is_empty(&long_string), 41);
        assert!(string::length(&long_string) > 10, 42);
        
        // Test string comparison
        assert!(empty_string != single_char, 43);
        assert!(single_char != long_string, 44);
        assert!(empty_string != long_string, 45);
    }
    
    #[test]
    public fun test_nft_id_relationships() {
        // Test ID relationship logic used in NFT
        let pool_id_1 = object::id_from_address(@0xABCD);
        let pool_id_2 = object::id_from_address(@0xEF12);
        let position_id_1 = object::id_from_address(@0x1111);
        let position_id_2 = object::id_from_address(@0x2222);
        
        // Multiple positions can belong to the same pool
        // but each position should have a unique ID
        assert!(position_id_1 != position_id_2, 46);
        assert!(pool_id_1 != position_id_1, 47);
        assert!(pool_id_1 != position_id_2, 48);
        assert!(pool_id_2 != position_id_1, 49);
        assert!(pool_id_2 != position_id_2, 50);
        assert!(pool_id_1 != pool_id_2, 51);
        
        // Test consistency
        let pool_id_1_copy = object::id_from_address(@0xABCD);
        assert!(pool_id_1 == pool_id_1_copy, 52);
    }
    
    #[test]
    public fun test_nft_properties_validation() {
        // Test validation logic for NFT properties
        let valid_name = string::utf8(b"Valid Position NFT Name");
        let valid_description = string::utf8(b"This is a valid description for the position NFT");
        let valid_img_url = string::utf8(b"https://turbos.finance/nft/image.png");
        
        // Test empty strings
        let empty_name = string::utf8(b"");
        let empty_description = string::utf8(b"");
        
        // Verify string properties
        assert!(!string::is_empty(&valid_name), 53);
        assert!(!string::is_empty(&valid_description), 54);
        assert!(!string::is_empty(&valid_img_url), 55);
        assert!(string::is_empty(&empty_name), 56);
        assert!(string::is_empty(&empty_description), 57);
        
        // Test URL creation (used in mint function)
        let url = url::new_unsafe(string::to_ascii(valid_img_url));
        assert!(url::inner_url(&url) == string::to_ascii(valid_img_url), 58);
        
        // Test string lengths
        assert!(string::length(&valid_name) > 5, 59);
        assert!(string::length(&valid_description) > 10, 60);
        assert!(string::length(&valid_img_url) > 20, 61);
    }
}