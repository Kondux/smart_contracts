#!/usr/bin/env python3
"""
Seaport Listing CLI Tool
Creates and validates OpenSea listings via Seaport 1.6
"""

import argparse
import json
import os
import sys
import time
from dataclasses import dataclass
from typing import Optional
from eth_account import Account
from eth_account.messages import encode_typed_data
from web3 import Web3
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Constants
SEAPORT_ADDRESS = "0x0000000000000068F116a894984e2DB1123eB395"
OPENSEA_ZONE = "0x000056F7000000EcE9003ca63978907a00FFD100"
OPENSEA_FEE_RECIPIENT = "0x0000a26b00c1F0DF003000390027140000fAa719"
OPENSEA_CONDUIT_KEY = "0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000"

# Seaport ABI (minimal for what we need)
SEAPORT_ABI = [
    {
        "inputs": [{"internalType": "address", "name": "offerer", "type": "address"}],
        "name": "getCounter",
        "outputs": [{"internalType": "uint256", "name": "counter", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [],
        "name": "information",
        "outputs": [
            {"internalType": "string", "name": "version", "type": "string"},
            {"internalType": "bytes32", "name": "domainSeparator", "type": "bytes32"},
            {"internalType": "address", "name": "conduitController", "type": "address"}
        ],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [
            {
                "components": [
                    {
                        "components": [
                            {"internalType": "address", "name": "offerer", "type": "address"},
                            {"internalType": "address", "name": "zone", "type": "address"},
                            {
                                "components": [
                                    {"internalType": "uint8", "name": "itemType", "type": "uint8"},
                                    {"internalType": "address", "name": "token", "type": "address"},
                                    {"internalType": "uint256", "name": "identifierOrCriteria", "type": "uint256"},
                                    {"internalType": "uint256", "name": "startAmount", "type": "uint256"},
                                    {"internalType": "uint256", "name": "endAmount", "type": "uint256"}
                                ],
                                "internalType": "struct OfferItem[]",
                                "name": "offer",
                                "type": "tuple[]"
                            },
                            {
                                "components": [
                                    {"internalType": "uint8", "name": "itemType", "type": "uint8"},
                                    {"internalType": "address", "name": "token", "type": "address"},
                                    {"internalType": "uint256", "name": "identifierOrCriteria", "type": "uint256"},
                                    {"internalType": "uint256", "name": "startAmount", "type": "uint256"},
                                    {"internalType": "uint256", "name": "endAmount", "type": "uint256"},
                                    {"internalType": "address", "name": "recipient", "type": "address"}
                                ],
                                "internalType": "struct ConsiderationItem[]",
                                "name": "consideration",
                                "type": "tuple[]"
                            },
                            {"internalType": "uint8", "name": "orderType", "type": "uint8"},
                            {"internalType": "uint256", "name": "startTime", "type": "uint256"},
                            {"internalType": "uint256", "name": "endTime", "type": "uint256"},
                            {"internalType": "bytes32", "name": "zoneHash", "type": "bytes32"},
                            {"internalType": "uint256", "name": "salt", "type": "uint256"},
                            {"internalType": "bytes32", "name": "conduitKey", "type": "bytes32"},
                            {"internalType": "uint256", "name": "totalOriginalConsiderationItems", "type": "uint256"}
                        ],
                        "internalType": "struct OrderParameters",
                        "name": "parameters",
                        "type": "tuple"
                    },
                    {"internalType": "bytes", "name": "signature", "type": "bytes"}
                ],
                "internalType": "struct Order[]",
                "name": "orders",
                "type": "tuple[]"
            }
        ],
        "name": "validate",
        "outputs": [{"internalType": "bool", "name": "validated", "type": "bool"}],
        "stateMutability": "nonpayable",
        "type": "function"
    }
]


@dataclass
class ListingConfig:
    collection: str
    token_id: int
    price_wei: int
    royalty_recipient: str
    royalty_bps: int = 1000  # 10%
    opensea_fee_bps: int = 100  # 1%
    duration_days: int = 30


def get_web3(rpc_url: Optional[str] = None) -> Web3:
    """Initialize Web3 connection"""
    url = rpc_url or os.getenv("MAINNET_RPC_URL", "https://eth.merkle.io")
    return Web3(Web3.HTTPProvider(url))


def get_private_key() -> str:
    """Get private key from environment"""
    pk = os.getenv("PROD_DEPLOYER_PK")
    if not pk:
        raise ValueError("PROD_DEPLOYER_PK not set in environment")
    return pk if pk.startswith("0x") else f"0x{pk}"


def calculate_fees(price_wei: int, royalty_bps: int, opensea_fee_bps: int) -> tuple[int, int, int]:
    """Calculate fee amounts"""
    opensea_fee = (price_wei * opensea_fee_bps) // 10000
    royalty = (price_wei * royalty_bps) // 10000
    seller_amount = price_wei - opensea_fee - royalty
    return seller_amount, opensea_fee, royalty


def build_order_parameters(
    w3: Web3,
    offerer: str,
    config: ListingConfig,
    counter: int
) -> dict:
    """Build Seaport order parameters"""

    seller_amount, opensea_fee, royalty = calculate_fees(
        config.price_wei,
        config.royalty_bps,
        config.opensea_fee_bps
    )

    start_time = int(time.time())
    end_time = start_time + (config.duration_days * 24 * 60 * 60)

    # Generate salt
    salt_data = w3.keccak(
        w3.codec.encode(
            ['address', 'uint256', 'uint256', 'string'],
            [offerer, start_time, config.token_id, 'opensea_listing']
        )
    )
    salt = int.from_bytes(salt_data, 'big')

    return {
        "offerer": offerer,
        "zone": OPENSEA_ZONE,
        "offer": [{
            "itemType": 2,  # ERC721
            "token": config.collection,
            "identifierOrCriteria": str(config.token_id),
            "startAmount": "1",
            "endAmount": "1"
        }],
        "consideration": [
            {
                "itemType": 0,  # NATIVE (ETH)
                "token": "0x0000000000000000000000000000000000000000",
                "identifierOrCriteria": "0",
                "startAmount": str(seller_amount),
                "endAmount": str(seller_amount),
                "recipient": offerer
            },
            {
                "itemType": 0,
                "token": "0x0000000000000000000000000000000000000000",
                "identifierOrCriteria": "0",
                "startAmount": str(opensea_fee),
                "endAmount": str(opensea_fee),
                "recipient": OPENSEA_FEE_RECIPIENT
            },
            {
                "itemType": 0,
                "token": "0x0000000000000000000000000000000000000000",
                "identifierOrCriteria": "0",
                "startAmount": str(royalty),
                "endAmount": str(royalty),
                "recipient": config.royalty_recipient
            }
        ],
        "orderType": 2,  # FULL_RESTRICTED
        "startTime": str(start_time),
        "endTime": str(end_time),
        "zoneHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
        "salt": str(salt),
        "conduitKey": OPENSEA_CONDUIT_KEY,
        "counter": str(counter),
        "totalOriginalConsiderationItems": 3
    }


def sign_order(w3: Web3, private_key: str, order_params: dict) -> str:
    """Sign Seaport order using EIP-712"""

    seaport = w3.eth.contract(address=SEAPORT_ADDRESS, abi=SEAPORT_ABI)
    _, domain_separator, _ = seaport.functions.information().call()

    # EIP-712 domain
    domain = {
        "name": "Seaport",
        "version": "1.6",
        "chainId": w3.eth.chain_id,
        "verifyingContract": SEAPORT_ADDRESS
    }

    # EIP-712 types
    types = {
        "OrderComponents": [
            {"name": "offerer", "type": "address"},
            {"name": "zone", "type": "address"},
            {"name": "offer", "type": "OfferItem[]"},
            {"name": "consideration", "type": "ConsiderationItem[]"},
            {"name": "orderType", "type": "uint8"},
            {"name": "startTime", "type": "uint256"},
            {"name": "endTime", "type": "uint256"},
            {"name": "zoneHash", "type": "bytes32"},
            {"name": "salt", "type": "uint256"},
            {"name": "conduitKey", "type": "bytes32"},
            {"name": "counter", "type": "uint256"}
        ],
        "OfferItem": [
            {"name": "itemType", "type": "uint8"},
            {"name": "token", "type": "address"},
            {"name": "identifierOrCriteria", "type": "uint256"},
            {"name": "startAmount", "type": "uint256"},
            {"name": "endAmount", "type": "uint256"}
        ],
        "ConsiderationItem": [
            {"name": "itemType", "type": "uint8"},
            {"name": "token", "type": "address"},
            {"name": "identifierOrCriteria", "type": "uint256"},
            {"name": "startAmount", "type": "uint256"},
            {"name": "endAmount", "type": "uint256"},
            {"name": "recipient", "type": "address"}
        ]
    }

    # Convert order params to proper format for signing
    message = {
        "offerer": order_params["offerer"],
        "zone": order_params["zone"],
        "offer": [{
            "itemType": int(item["itemType"]),
            "token": item["token"],
            "identifierOrCriteria": int(item["identifierOrCriteria"]),
            "startAmount": int(item["startAmount"]),
            "endAmount": int(item["endAmount"])
        } for item in order_params["offer"]],
        "consideration": [{
            "itemType": int(item["itemType"]),
            "token": item["token"],
            "identifierOrCriteria": int(item["identifierOrCriteria"]),
            "startAmount": int(item["startAmount"]),
            "endAmount": int(item["endAmount"]),
            "recipient": item["recipient"]
        } for item in order_params["consideration"]],
        "orderType": int(order_params["orderType"]),
        "startTime": int(order_params["startTime"]),
        "endTime": int(order_params["endTime"]),
        "zoneHash": bytes.fromhex(order_params["zoneHash"][2:]),
        "salt": int(order_params["salt"]),
        "conduitKey": bytes.fromhex(order_params["conduitKey"][2:]),
        "counter": int(order_params["counter"])
    }

    # Sign using EIP-712
    signable = encode_typed_data(domain, types, message)
    account = Account.from_key(private_key)
    signed = account.sign_message(signable)

    return signed.signature.hex()


def validate_onchain(w3: Web3, private_key: str, order_params: dict) -> str:
    """Validate order on-chain via Seaport"""

    account = Account.from_key(private_key)
    seaport = w3.eth.contract(address=SEAPORT_ADDRESS, abi=SEAPORT_ABI)

    # Build order tuple for contract call
    order = {
        "parameters": {
            "offerer": order_params["offerer"],
            "zone": order_params["zone"],
            "offer": [(
                int(item["itemType"]),
                item["token"],
                int(item["identifierOrCriteria"]),
                int(item["startAmount"]),
                int(item["endAmount"])
            ) for item in order_params["offer"]],
            "consideration": [(
                int(item["itemType"]),
                item["token"],
                int(item["identifierOrCriteria"]),
                int(item["startAmount"]),
                int(item["endAmount"]),
                item["recipient"]
            ) for item in order_params["consideration"]],
            "orderType": int(order_params["orderType"]),
            "startTime": int(order_params["startTime"]),
            "endTime": int(order_params["endTime"]),
            "zoneHash": bytes.fromhex(order_params["zoneHash"][2:]),
            "salt": int(order_params["salt"]),
            "conduitKey": bytes.fromhex(order_params["conduitKey"][2:]),
            "totalOriginalConsiderationItems": int(order_params["totalOriginalConsiderationItems"])
        },
        "signature": b""  # Empty for self-validation
    }

    # Build transaction
    tx = seaport.functions.validate([order]).build_transaction({
        "from": account.address,
        "nonce": w3.eth.get_transaction_count(account.address),
        "gas": 100000,
        "maxFeePerGas": w3.eth.gas_price * 2,
        "maxPriorityFeePerGas": w3.to_wei(1, "gwei")
    })

    # Sign and send
    signed_tx = account.sign_transaction(tx)
    tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)

    print(f"Transaction sent: {tx_hash.hex()}")

    # Wait for receipt
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)

    if receipt["status"] == 1:
        print(f"Order validated successfully!")
        return tx_hash.hex()
    else:
        raise Exception("Transaction failed")


def generate_opensea_payload(order_params: dict, signature: str = "") -> dict:
    """Generate payload for OpenSea API"""
    return {
        "parameters": order_params,
        "signature": signature if signature else "0x",
        "protocol_address": SEAPORT_ADDRESS
    }


def main():
    parser = argparse.ArgumentParser(description="Seaport Listing CLI Tool")
    parser.add_argument("--collection", "-c", required=True, help="NFT collection address")
    parser.add_argument("--token-id", "-t", type=int, required=True, help="Token ID to list")
    parser.add_argument("--price", "-p", required=True, help="Price in ETH (e.g., 0.0001)")
    parser.add_argument("--royalty-recipient", "-r", required=True, help="Royalty recipient address")
    parser.add_argument("--royalty-bps", type=int, default=1000, help="Royalty in basis points (default: 1000 = 10%%)")
    parser.add_argument("--opensea-fee-bps", type=int, default=100, help="OpenSea fee in basis points (default: 100 = 1%%)")
    parser.add_argument("--duration", "-d", type=int, default=30, help="Listing duration in days (default: 30)")
    parser.add_argument("--rpc-url", help="RPC URL (default: from MAINNET_RPC_URL env)")
    parser.add_argument("--validate", "-v", action="store_true", help="Validate order on-chain")
    parser.add_argument("--sign", "-s", action="store_true", help="Sign the order")
    parser.add_argument("--output", "-o", choices=["json", "curl"], default="json", help="Output format")

    args = parser.parse_args()

    # Initialize
    w3 = get_web3(args.rpc_url)
    private_key = get_private_key()
    account = Account.from_key(private_key)
    offerer = account.address

    print(f"=== Seaport Listing Tool ===")
    print(f"Offerer: {offerer}")
    print(f"Chain ID: {w3.eth.chain_id}")

    # Convert price to wei
    price_wei = w3.to_wei(float(args.price), "ether")

    # Build config
    config = ListingConfig(
        collection=args.collection,
        token_id=args.token_id,
        price_wei=price_wei,
        royalty_recipient=args.royalty_recipient,
        royalty_bps=args.royalty_bps,
        opensea_fee_bps=args.opensea_fee_bps,
        duration_days=args.duration
    )

    # Get counter
    seaport = w3.eth.contract(address=SEAPORT_ADDRESS, abi=SEAPORT_ABI)
    counter = seaport.functions.getCounter(offerer).call()
    print(f"Counter: {counter}")

    # Build order
    order_params = build_order_parameters(w3, offerer, config, counter)

    seller_amount, opensea_fee, royalty = calculate_fees(
        config.price_wei, config.royalty_bps, config.opensea_fee_bps
    )

    print(f"\n=== Order Details ===")
    print(f"Collection: {config.collection}")
    print(f"Token ID: {config.token_id}")
    print(f"Price: {args.price} ETH ({price_wei} wei)")
    print(f"Seller receives: {w3.from_wei(seller_amount, 'ether')} ETH")
    print(f"OpenSea fee: {w3.from_wei(opensea_fee, 'ether')} ETH ({args.opensea_fee_bps/100}%)")
    print(f"Royalty: {w3.from_wei(royalty, 'ether')} ETH ({args.royalty_bps/100}%)")
    print(f"Duration: {args.duration} days")
    print(f"Order Type: FULL_RESTRICTED (2)")

    signature = ""

    # Sign if requested
    if args.sign:
        print(f"\n=== Signing Order ===")
        signature = sign_order(w3, private_key, order_params)
        print(f"Signature: 0x{signature}")

    # Validate on-chain if requested
    if args.validate:
        print(f"\n=== Validating On-Chain ===")
        tx_hash = validate_onchain(w3, private_key, order_params)
        print(f"Transaction: https://etherscan.io/tx/{tx_hash}")

    # Output
    payload = generate_opensea_payload(order_params, signature)

    if args.output == "json":
        print(f"\n=== OpenSea API Payload ===")
        print(json.dumps(payload, indent=2))
    elif args.output == "curl":
        api_key = os.getenv("OPENSEA_API_KEY", "YOUR_API_KEY")
        curl_cmd = f'''curl -X POST "https://api.opensea.io/v2/orders/ethereum/seaport/listings" \\
  -H "Content-Type: application/json" \\
  -H "X-API-KEY: {api_key}" \\
  -d '{json.dumps(payload)}'
'''
        print(f"\n=== cURL Command ===")
        print(curl_cmd)


if __name__ == "__main__":
    main()
