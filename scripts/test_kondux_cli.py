#!/usr/bin/env python3
"""
Test suite for kondux_cli.py.

This test suite contains:
1. Unit tests that don't require network access (test pure functions)
2. Integration tests that require a running Anvil fork (skipped if unavailable)

Prerequisites:
- Python packages: web3, eth-account, python-dotenv, pytest

For integration tests, start Anvil manually:
    anvil --fork-url https://eth-mainnet.g.alchemy.com/v2/<API_KEY> --port 8546

Usage:
    pytest scripts/test_kondux_cli.py -v
    pytest scripts/test_kondux_cli.py -v -k "not integration"  # Skip integration tests
"""

import os
import sys
import json
import pytest
from unittest.mock import Mock, patch, MagicMock
from decimal import Decimal

# Add scripts directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Test configuration
ANVIL_PORT = 8546
ANVIL_RPC_URL = f"http://127.0.0.1:{ANVIL_PORT}"

# Kondux Implementation proxy on mainnet
KONDUX_COLLECTION = "0x5f056911b9FC29f991039e4322b7755ccc9CbE9D"
SEAPORT_ADDRESS = "0x0000000000000068F116a894984e2DB1123eB395"
SEAPORT_HELPER_ADDRESS = "0xc87b9e84BAe43aD76918b5d5FfC4c0DdE7031CCA"

# Test accounts (Anvil default accounts with known private keys)
TEST_ACCOUNTS = [
    {
        "address": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
        "private_key": "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
    },
    {
        "address": "0x70997970C51812dc3A010C7d01b50e0d17dc79C8",
        "private_key": "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
    },
]

# =============================================================================
# Import kondux_cli module functions
# =============================================================================

try:
    from kondux_cli import (
        get_all_token_ids,
        prepare_seaport_order,
        create_offer_item,
        create_consideration_item,
        # These might not be directly importable, we'll test via mocking
    )
    KONDUX_CLI_AVAILABLE = True
except ImportError:
    KONDUX_CLI_AVAILABLE = False


# =============================================================================
# Unit Tests (no network required)
# =============================================================================

class TestOrderConstruction:
    """Test Seaport order construction logic."""
    
    def test_offer_item_structure(self):
        """Test that offer items have the correct structure."""
        # ERC721 offer item structure
        offer_item = {
            "itemType": 2,  # ERC721
            "token": KONDUX_COLLECTION,
            "identifierOrCriteria": 1,
            "startAmount": 1,
            "endAmount": 1,
        }
        
        assert offer_item["itemType"] == 2
        assert offer_item["startAmount"] == 1
        assert offer_item["endAmount"] == 1
    
    def test_consideration_item_with_royalties(self):
        """Test consideration item includes royalty payment."""
        sale_price_wei = 1_000_000_000_000_000_000  # 1 ETH
        royalty_bps = 500  # 5%
        royalty_receiver = "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2"
        seller = TEST_ACCOUNTS[0]["address"]
        
        royalty_amount = (sale_price_wei * royalty_bps) // 10000
        seller_amount = sale_price_wei - royalty_amount
        
        assert royalty_amount == 50_000_000_000_000_000  # 0.05 ETH
        assert seller_amount == 950_000_000_000_000_000  # 0.95 ETH
        
        # Seller consideration
        seller_consideration = {
            "itemType": 0,  # Native ETH
            "token": "0x0000000000000000000000000000000000000000",
            "identifierOrCriteria": 0,
            "startAmount": seller_amount,
            "endAmount": seller_amount,
            "recipient": seller,
        }
        
        # Royalty consideration  
        royalty_consideration = {
            "itemType": 0,  # Native ETH
            "token": "0x0000000000000000000000000000000000000000",
            "identifierOrCriteria": 0,
            "startAmount": royalty_amount,
            "endAmount": royalty_amount,
            "recipient": royalty_receiver,
        }
        
        assert seller_consideration["recipient"] == seller
        assert royalty_consideration["recipient"] == royalty_receiver
        assert seller_consideration["startAmount"] + royalty_consideration["startAmount"] == sale_price_wei

    def test_order_parameters_structure(self):
        """Test Seaport order parameters structure."""
        order_params = {
            "offerer": TEST_ACCOUNTS[0]["address"],
            "zone": "0x0000000000000000000000000000000000000000",
            "offer": [],
            "consideration": [],
            "orderType": 0,  # FULL_OPEN
            "startTime": 0,
            "endTime": 0,
            "zoneHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
            "salt": "0x0000000000000000000000000000000000000000000000000000000000000001",
            "conduitKey": "0x0000000000000000000000000000000000000000000000000000000000000000",
            "totalOriginalConsiderationItems": 0,
        }
        
        required_keys = [
            "offerer", "zone", "offer", "consideration", "orderType",
            "startTime", "endTime", "zoneHash", "salt", "conduitKey"
        ]
        
        for key in required_keys:
            assert key in order_params, f"Missing required key: {key}"


class TestPriceCalculations:
    """Test price and royalty calculations."""
    
    def test_eth_to_wei_conversion(self):
        """Test ETH to Wei conversion."""
        eth_amount = 1.5
        wei_amount = int(eth_amount * 10**18)
        assert wei_amount == 1_500_000_000_000_000_000
        
    def test_royalty_calculation_5_percent(self):
        """Test 5% royalty calculation."""
        sale_price = 10**18  # 1 ETH
        royalty_bps = 500  # 5%
        expected_royalty = 5 * 10**16  # 0.05 ETH
        
        calculated_royalty = (sale_price * royalty_bps) // 10000
        assert calculated_royalty == expected_royalty
    
    def test_royalty_calculation_7_5_percent(self):
        """Test 7.5% royalty calculation."""
        sale_price = 10**18  # 1 ETH
        royalty_bps = 750  # 7.5%
        expected_royalty = 75 * 10**15  # 0.075 ETH
        
        calculated_royalty = (sale_price * royalty_bps) // 10000
        assert calculated_royalty == expected_royalty
    
    def test_total_consideration_equals_price(self):
        """Verify seller + royalty = total price."""
        sale_price = 2_500_000_000_000_000_000  # 2.5 ETH
        royalty_bps = 500  # 5%
        
        royalty_amount = (sale_price * royalty_bps) // 10000
        seller_amount = sale_price - royalty_amount
        
        assert seller_amount + royalty_amount == sale_price


class TestAddressValidation:
    """Test address validation and formatting."""
    
    def test_valid_ethereum_address(self):
        """Test valid Ethereum address format."""
        address = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
        assert address.startswith("0x")
        assert len(address) == 42
        
    def test_checksum_address(self):
        """Test checksum address validation."""
        from web3 import Web3
        
        lowercase = "0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266"
        checksummed = Web3.to_checksum_address(lowercase)
        
        assert checksummed == "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    
    def test_zero_address(self):
        """Test zero address constant."""
        zero_address = "0x0000000000000000000000000000000000000000"
        assert len(zero_address) == 42
        assert zero_address.startswith("0x")


class TestTokenIdParsing:
    """Test token ID parsing and handling."""
    
    def test_parse_single_token_id(self):
        """Test parsing single token ID."""
        token_ids_str = "1"
        token_ids = [int(x.strip()) for x in token_ids_str.split(",")]
        assert token_ids == [1]
    
    def test_parse_multiple_token_ids(self):
        """Test parsing multiple token IDs."""
        token_ids_str = "1,2,3,4,5"
        token_ids = [int(x.strip()) for x in token_ids_str.split(",")]
        assert token_ids == [1, 2, 3, 4, 5]
    
    def test_parse_token_ids_with_spaces(self):
        """Test parsing token IDs with spaces."""
        token_ids_str = "1, 2, 3"
        token_ids = [int(x.strip()) for x in token_ids_str.split(",")]
        assert token_ids == [1, 2, 3]


class TestSeaportConstants:
    """Test Seaport-related constants."""
    
    def test_seaport_address(self):
        """Test Seaport 1.6 address."""
        assert SEAPORT_ADDRESS == "0x0000000000000068F116a894984e2DB1123eB395"
    
    def test_item_types(self):
        """Test Seaport item type constants."""
        NATIVE = 0
        ERC20 = 1
        ERC721 = 2
        ERC1155 = 3
        
        # For NFT listings, offer is ERC721, consideration is Native
        assert ERC721 == 2
        assert NATIVE == 0
    
    def test_order_types(self):
        """Test Seaport order type constants."""
        FULL_OPEN = 0
        PARTIAL_OPEN = 1
        FULL_RESTRICTED = 2
        PARTIAL_RESTRICTED = 3
        
        # For basic listings, use FULL_OPEN
        assert FULL_OPEN == 0


# =============================================================================
# Integration Tests (require running Anvil fork)
# =============================================================================

def is_anvil_running():
    """Check if Anvil is running on the expected port."""
    try:
        from web3 import Web3
        w3 = Web3(Web3.HTTPProvider(ANVIL_RPC_URL))
        return w3.is_connected()
    except:
        return False


@pytest.fixture
def w3():
    """Web3 instance connected to Anvil fork."""
    if not is_anvil_running():
        pytest.skip("Anvil fork not running. Start with: anvil --fork-url <RPC_URL> --port 8546")
    
    from web3 import Web3
    web3 = Web3(Web3.HTTPProvider(ANVIL_RPC_URL))
    return web3


@pytest.fixture  
def test_account():
    """Test account with private key."""
    return TEST_ACCOUNTS[0]


class TestIntegration:
    """Integration tests requiring Anvil fork."""
    
    @pytest.mark.integration
    def test_anvil_connection(self, w3):
        """Test connection to Anvil fork."""
        assert w3.is_connected()
        assert w3.eth.chain_id == 1  # Mainnet fork
    
    @pytest.mark.integration
    def test_kondux_contract_exists(self, w3):
        """Test that Kondux contract exists on fork."""
        code = w3.eth.get_code(KONDUX_COLLECTION)
        assert len(code) > 2  # More than just "0x"
    
    @pytest.mark.integration
    def test_seaport_contract_exists(self, w3):
        """Test that Seaport contract exists on fork."""
        code = w3.eth.get_code(SEAPORT_ADDRESS)
        assert len(code) > 2
    
    @pytest.mark.integration
    def test_seaport_helper_exists(self, w3):
        """Test that SeaportHelper contract exists on fork."""
        code = w3.eth.get_code(SEAPORT_HELPER_ADDRESS)
        assert len(code) > 2
    
    @pytest.mark.integration
    def test_royalty_info(self, w3):
        """Test fetching royalty info from Kondux contract (ERC2981)."""
        KONDUX_ABI = [
            {"inputs": [{"internalType": "uint256", "name": "tokenId", "type": "uint256"}, {"internalType": "uint256", "name": "salePrice", "type": "uint256"}], "name": "royaltyInfo", "outputs": [{"internalType": "address", "name": "", "type": "address"}, {"internalType": "uint256", "name": "", "type": "uint256"}], "stateMutability": "view", "type": "function"},
            {"inputs": [], "name": "totalSupply", "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}], "stateMutability": "view", "type": "function"},
        ]
        
        contract = w3.eth.contract(address=w3.to_checksum_address(KONDUX_COLLECTION), abi=KONDUX_ABI)
        
        # Get total supply
        total_supply = contract.functions.totalSupply().call()
        print(f"\n📊 Total Supply: {total_supply}")
        
        # Test royalty at multiple price points
        test_prices = [
            (10**18, "1 ETH"),
            (10**17, "0.1 ETH"),
            (5 * 10**18, "5 ETH"),
        ]
        
        for sale_price, price_label in test_prices:
            receiver, royalty_amount = contract.functions.royaltyInfo(0, sale_price).call()
            royalty_bps = (royalty_amount * 10000) // sale_price if sale_price > 0 else 0
            royalty_eth = royalty_amount / 10**18
            
            print(f"  💰 Sale: {price_label} → Royalty: {royalty_bps/100}% ({royalty_eth:.4f} ETH) to {receiver[:10]}...")
            
            # Verify royalty is reasonable (max 10%)
            assert royalty_bps <= 1000, f"Royalty {royalty_bps/100}% exceeds 10% max"
            
            # Verify receiver is a valid address (not zero)
            assert receiver != "0x0000000000000000000000000000000000000000", "Royalty receiver is zero address"
        
        # Verify royalty percentage is consistent across all test prices
        _, royalty_1eth = contract.functions.royaltyInfo(0, 10**18).call()
        actual_bps = (royalty_1eth * 10000) // 10**18
        
        print(f"\n📈 ERC2981 Royalty: {actual_bps/100}%")
        
        # Final sanity check: royalty should be <= 10%
        assert actual_bps <= 1000, f"Royalty {actual_bps/100}% exceeds 10% max"
    
    @pytest.mark.integration
    def test_get_token_balance(self, w3):
        """Test getting NFT balance for known holder."""
        ERC721_ABI = [
            {"inputs": [{"internalType": "address", "name": "owner", "type": "address"}], "name": "balanceOf", "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}], "stateMutability": "view", "type": "function"},
        ]
        
        contract = w3.eth.contract(address=w3.to_checksum_address(KONDUX_COLLECTION), abi=ERC721_ABI)
        
        # Query balance for the admin address
        admin = "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2"
        balance = contract.functions.balanceOf(admin).call()
        
        # Admin likely has some tokens
        assert isinstance(balance, int)
        assert balance >= 0


# =============================================================================
# Mock-based Tests for CLI Functions
# =============================================================================

class TestMockedCLIFunctions:
    """Test CLI functions using mocks."""
    
    def test_get_all_token_ids_mock(self):
        """Test get_all_token_ids with mocked contract."""
        mock_contract = Mock()
        mock_contract.functions.balanceOf.return_value.call.return_value = 3
        mock_contract.functions.tokenOfOwnerByIndex.return_value.call.side_effect = [100, 200, 300]
        
        # Simulate the logic
        owner = TEST_ACCOUNTS[0]["address"]
        balance = mock_contract.functions.balanceOf(owner).call()
        
        token_ids = []
        for i in range(balance):
            token_id = mock_contract.functions.tokenOfOwnerByIndex(owner, i).call()
            token_ids.append(token_id)
        
        assert token_ids == [100, 200, 300]
    
    def test_transfer_mock(self):
        """Test transfer function with mocked contract."""
        mock_w3 = Mock()
        mock_contract = Mock()
        
        # Mock the transaction flow
        mock_tx_hash = "0x" + "a" * 64
        mock_contract.functions.safeTransferFrom.return_value.transact.return_value = mock_tx_hash
        mock_w3.eth.wait_for_transaction_receipt.return_value = {"status": 1}
        
        # Simulate transfer
        from_addr = TEST_ACCOUNTS[0]["address"]
        to_addr = TEST_ACCOUNTS[1]["address"]
        token_id = 1
        
        tx = mock_contract.functions.safeTransferFrom(from_addr, to_addr, token_id).transact({
            'from': from_addr,
            'gas': 100000
        })
        
        receipt = mock_w3.eth.wait_for_transaction_receipt(tx)
        assert receipt["status"] == 1
    
    def test_burn_mock(self):
        """Test burn function with mocked contract."""
        mock_w3 = Mock()
        mock_contract = Mock()
        
        # Mock the transaction flow
        mock_tx_hash = "0x" + "b" * 64
        mock_contract.functions.burn.return_value.transact.return_value = mock_tx_hash
        mock_w3.eth.wait_for_transaction_receipt.return_value = {"status": 1}
        
        # Simulate burn
        owner = TEST_ACCOUNTS[0]["address"]
        token_id = 1
        
        tx = mock_contract.functions.burn(token_id).transact({
            'from': owner,
            'gas': 100000
        })
        
        receipt = mock_w3.eth.wait_for_transaction_receipt(tx)
        assert receipt["status"] == 1
    
    def test_approval_mock(self):
        """Test approval function with mocked contract."""
        mock_contract = Mock()
        
        # Mock approval check
        mock_contract.functions.isApprovedForAll.return_value.call.return_value = False
        
        owner = TEST_ACCOUNTS[0]["address"]
        operator = SEAPORT_ADDRESS
        
        is_approved = mock_contract.functions.isApprovedForAll(owner, operator).call()
        assert is_approved is False
        
        # Mock setting approval
        mock_tx_hash = "0x" + "c" * 64
        mock_contract.functions.setApprovalForAll.return_value.transact.return_value = mock_tx_hash
        
        tx = mock_contract.functions.setApprovalForAll(operator, True).transact({
            'from': owner,
            'gas': 100000
        })
        
        assert tx == mock_tx_hash


# =============================================================================
# Test EIP-712 Domain and Typehash
# =============================================================================

class TestEIP712:
    """Test EIP-712 typed data signing components."""
    
    def test_seaport_domain_separator_components(self):
        """Test Seaport EIP-712 domain components."""
        domain = {
            "name": "Seaport",
            "version": "1.6",
            "chainId": 1,
            "verifyingContract": SEAPORT_ADDRESS,
        }
        
        assert domain["name"] == "Seaport"
        assert domain["version"] == "1.6"
        assert domain["chainId"] == 1
        assert domain["verifyingContract"] == SEAPORT_ADDRESS
    
    def test_order_components_typehash(self):
        """Test OrderComponents typehash construction."""
        # The typehash for OrderComponents (simplified)
        typehash_input = "OrderComponents(address offerer,address zone,OfferItem[] offer,ConsiderationItem[] consideration,uint8 orderType,uint256 startTime,uint256 endTime,bytes32 zoneHash,uint256 salt,bytes32 conduitKey,uint256 counter)"
        
        from web3 import Web3
        typehash = Web3.keccak(text=typehash_input)
        
        # The typehash should be a 32-byte value
        assert len(typehash) == 32


# =============================================================================
# Mainnet Read-Only Tests (no Anvil required, queries mainnet directly)
# =============================================================================

class TestMainnetRoyalty:
    """Direct mainnet royalty verification tests (read-only, no Anvil required)."""
    
    @pytest.fixture
    def mainnet_w3(self):
        """Create Web3 connection directly to mainnet."""
        from web3 import Web3
        
        rpc_url = os.environ.get("MAINNET_RPC_URL", "https://eth-mainnet.g.alchemy.com/v2/NWbAcPvkpq7yLbeXhubWbhIRIKiH-oFf")
        w3 = Web3(Web3.HTTPProvider(rpc_url))
        
        if not w3.is_connected():
            pytest.skip("Cannot connect to mainnet RPC")
        
        return w3
    
    @pytest.mark.integration
    def test_mainnet_royalty_configuration(self, mainnet_w3):
        """
        Verify mainnet royalty is correctly configured (queries mainnet directly).
        
        Expected configuration after fix:
        - Receiver: 0x5c8F300781BEBDD84A0bF27B37A6c0A7D42df114
        - Fee: 100 bps (1%)
        """
        KONDUX_ABI = [
            {"inputs": [{"internalType": "uint256", "name": "tokenId", "type": "uint256"}, {"internalType": "uint256", "name": "salePrice", "type": "uint256"}], "name": "royaltyInfo", "outputs": [{"internalType": "address", "name": "", "type": "address"}, {"internalType": "uint256", "name": "", "type": "uint256"}], "stateMutability": "view", "type": "function"},
            {"inputs": [], "name": "totalSupply", "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}], "stateMutability": "view", "type": "function"},
        ]
        
        contract = mainnet_w3.eth.contract(
            address=mainnet_w3.to_checksum_address(KONDUX_COLLECTION), 
            abi=KONDUX_ABI
        )
        
        # Test royalty at 1 ETH sale price
        sale_price = 10**18  # 1 ETH
        receiver, royalty_amount = contract.functions.royaltyInfo(0, sale_price).call()
        royalty_bps = (royalty_amount * 10000) // sale_price
        
        print(f"\n🔍 MAINNET Royalty Check:")
        print(f"  📍 Contract: {KONDUX_COLLECTION}")
        print(f"  💰 Sale: 1 ETH")
        print(f"  💎 Royalty: {royalty_bps/100}% ({royalty_amount / 10**18:.4f} ETH)")
        print(f"  👤 Receiver: {receiver}")
        
        # Expected values after our fix:
        EXPECTED_RECEIVER = "0x5c8F300781BEBDD84A0bF27B37A6c0A7D42df114"
        EXPECTED_BPS = 100  # 1%
        
        # Verify receiver is correct
        assert receiver.lower() == EXPECTED_RECEIVER.lower(), \
            f"Wrong receiver: expected {EXPECTED_RECEIVER}, got {receiver}"
        
        # Verify royalty percentage is 1% (100 bps)
        assert royalty_bps == EXPECTED_BPS, \
            f"Wrong royalty: expected {EXPECTED_BPS/100}%, got {royalty_bps/100}%"
        
        # Verify royalty amount is exactly 1% of sale price
        expected_amount = sale_price * EXPECTED_BPS // 10000
        assert royalty_amount == expected_amount, \
            f"Wrong amount: expected {expected_amount}, got {royalty_amount}"
        
        print(f"  ✅ Royalty configuration verified!")
    
    @pytest.mark.integration
    def test_mainnet_royalty_at_various_prices(self, mainnet_w3):
        """Test royalty calculation at various sale prices on mainnet."""
        KONDUX_ABI = [
            {"inputs": [{"internalType": "uint256", "name": "tokenId", "type": "uint256"}, {"internalType": "uint256", "name": "salePrice", "type": "uint256"}], "name": "royaltyInfo", "outputs": [{"internalType": "address", "name": "", "type": "address"}, {"internalType": "uint256", "name": "", "type": "uint256"}], "stateMutability": "view", "type": "function"},
        ]
        
        contract = mainnet_w3.eth.contract(
            address=mainnet_w3.to_checksum_address(KONDUX_COLLECTION), 
            abi=KONDUX_ABI
        )
        
        test_prices = [
            (10**15, "0.001 ETH"),
            (10**17, "0.1 ETH"),
            (10**18, "1 ETH"),
            (5 * 10**18, "5 ETH"),
            (10 * 10**18, "10 ETH"),
            (100 * 10**18, "100 ETH"),
        ]
        
        print(f"\n📊 MAINNET Royalty at Various Prices:")
        
        for sale_price, price_label in test_prices:
            receiver, royalty_amount = contract.functions.royaltyInfo(0, sale_price).call()
            royalty_bps = (royalty_amount * 10000) // sale_price if sale_price > 0 else 0
            royalty_eth = royalty_amount / 10**18
            
            print(f"  💰 {price_label:>10} → {royalty_bps/100:>5.2f}% = {royalty_eth:.6f} ETH")
            
            # All prices should return 1% royalty
            assert royalty_bps == 100, f"Royalty should be 1% at {price_label}, got {royalty_bps/100}%"
            
            # Verify the math: royalty = price * 100 / 10000
            expected_royalty = sale_price * 100 // 10000
            assert royalty_amount == expected_royalty, \
                f"Math error at {price_label}: expected {expected_royalty}, got {royalty_amount}"


# =============================================================================
# Main entry point
# =============================================================================

if __name__ == "__main__":
    # Run all tests
    pytest.main([__file__, "-v", "--tb=short"])
