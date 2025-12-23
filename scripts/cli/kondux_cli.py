#!/usr/bin/env python3
"""
Kondux NFT CLI Tool for Ethereum Mainnet
=========================================

Commands:
---------
1. create-offer: Create a Seaport listing for an NFT
2. transfer: Mass transfer NFTs to a recipient
3. burn: Mass burn NFTs

Environment Variables (.env):
-----------------------------
MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
PRIVATE_KEY=0x...  (your wallet private key)

Usage Examples:
---------------
# Create an offer for NFT #123 at 0.5 ETH
python kondux_cli.py create-offer --collection 0x5f056911b9FC29f991039e4322b7755ccc9CbE9D --token-id 123 --price 0.5

# Transfer specific NFTs to a recipient
python kondux_cli.py transfer --collection 0x5f056911b9FC29f991039e4322b7755ccc9CbE9D --token-ids 1,2,3 --to 0xRecipient

# Transfer all NFTs from a collection to a recipient
python kondux_cli.py transfer --collection 0x5f056911b9FC29f991039e4322b7755ccc9CbE9D --transfer-all --to 0xRecipient

# Burn specific NFTs
python kondux_cli.py burn --collection 0x5f056911b9FC29f991039e4322b7755ccc9CbE9D --token-ids 1,2,3

# Burn all NFTs from a collection
python kondux_cli.py burn --collection 0x5f056911b9FC29f991039e4322b7755ccc9CbE9D --burn-all
"""

import os
import sys
import time
import argparse
from dotenv import load_dotenv
from web3 import Web3
from eth_account import Account
from eth_account.messages import encode_typed_data

# Load environment variables
load_dotenv()

# Configuration - from environment (required)
RPC_URL = os.getenv("MAINNET_RPC_URL")
PRIVATE_KEY = os.getenv("PRIVATE_KEY")

if not RPC_URL:
    print("Error: MAINNET_RPC_URL environment variable required")
    sys.exit(1)

# Contract Addresses (Mainnet)
SEAPORT_ADDRESS = "0x0000000000000068F116a894984e2DB1123eB395"
SEAPORT_HELPER_ADDRESS = "0xc87b9e84BAe43aD76918b5d5FfC4c0DdE7031CCA"

# Default Kondux collection on mainnet (Kondux Test V2)
DEFAULT_KONDUX_COLLECTION = os.getenv("COLLECTION_ADDRESS", "0x167a45aaC7a4512089eC6d401547351d7c73e66F")

# ABIs
ERC721_ABI = [
    {
        "inputs": [{"internalType": "address", "name": "owner", "type": "address"}],
        "name": "balanceOf",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "address", "name": "owner", "type": "address"}, {"internalType": "uint256", "name": "index", "type": "uint256"}],
        "name": "tokenOfOwnerByIndex",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "uint256", "name": "tokenId", "type": "uint256"}],
        "name": "ownerOf",
        "outputs": [{"internalType": "address", "name": "", "type": "address"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "address", "name": "from", "type": "address"}, {"internalType": "address", "name": "to", "type": "address"}, {"internalType": "uint256", "name": "tokenId", "type": "uint256"}],
        "name": "transferFrom",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "address", "name": "from", "type": "address"}, {"internalType": "address", "name": "to", "type": "address"}, {"internalType": "uint256", "name": "tokenId", "type": "uint256"}],
        "name": "safeTransferFrom",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "uint256", "name": "tokenId", "type": "uint256"}],
        "name": "burn",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "address", "name": "operator", "type": "address"}, {"internalType": "bool", "name": "approved", "type": "bool"}],
        "name": "setApprovalForAll",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "address", "name": "owner", "type": "address"}, {"internalType": "address", "name": "operator", "type": "address"}],
        "name": "isApprovedForAll",
        "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
        "stateMutability": "view",
        "type": "function"
    },
    {
        "inputs": [{"internalType": "uint256", "name": "tokenId", "type": "uint256"}, {"internalType": "uint256", "name": "salePrice", "type": "uint256"}],
        "name": "royaltyInfo",
        "outputs": [{"internalType": "address", "name": "", "type": "address"}, {"internalType": "uint256", "name": "", "type": "uint256"}],
        "stateMutability": "view",
        "type": "function"
    }
]

HELPER_ABI = [
    {
        "inputs": [
            {"internalType": "address", "name": "offerer", "type": "address"},
            {"internalType": "address", "name": "collection", "type": "address"},
            {"internalType": "uint256", "name": "tokenId", "type": "uint256"},
            {"internalType": "uint256", "name": "price", "type": "uint256"},
            {"internalType": "address", "name": "royaltyReceiver", "type": "address"},
            {"internalType": "uint256", "name": "royaltyAmount", "type": "uint256"},
            {"internalType": "uint256", "name": "startTime", "type": "uint256"},
            {"internalType": "uint256", "name": "endTime", "type": "uint256"}
        ],
        "name": "prepareOrderWithRoyalties",
        "outputs": [
            {
                "components": [
                    {"internalType": "address", "name": "offerer", "type": "address"},
                    {"internalType": "address", "name": "zone", "type": "address"},
                    {
                        "components": [
                            {"internalType": "enum ISeaport.ItemType", "name": "itemType", "type": "uint8"},
                            {"internalType": "address", "name": "token", "type": "address"},
                            {"internalType": "uint256", "name": "identifierOrCriteria", "type": "uint256"},
                            {"internalType": "uint256", "name": "startAmount", "type": "uint256"},
                            {"internalType": "uint256", "name": "endAmount", "type": "uint256"}
                        ],
                        "internalType": "struct ISeaport.OfferItem[]",
                        "name": "offer",
                        "type": "tuple[]"
                    },
                    {
                        "components": [
                            {"internalType": "enum ISeaport.ItemType", "name": "itemType", "type": "uint8"},
                            {"internalType": "address", "name": "token", "type": "address"},
                            {"internalType": "uint256", "name": "identifierOrCriteria", "type": "uint256"},
                            {"internalType": "uint256", "name": "startAmount", "type": "uint256"},
                            {"internalType": "uint256", "name": "endAmount", "type": "uint256"},
                            {"internalType": "address payable", "name": "recipient", "type": "address"}
                        ],
                        "internalType": "struct ISeaport.ConsiderationItem[]",
                        "name": "consideration",
                        "type": "tuple[]"
                    },
                    {"internalType": "enum ISeaport.OrderType", "name": "orderType", "type": "uint8"},
                    {"internalType": "uint256", "name": "startTime", "type": "uint256"},
                    {"internalType": "uint256", "name": "endTime", "type": "uint256"},
                    {"internalType": "bytes32", "name": "zoneHash", "type": "bytes32"},
                    {"internalType": "uint256", "name": "salt", "type": "uint256"},
                    {"internalType": "bytes32", "name": "conduitKey", "type": "bytes32"},
                    {"internalType": "uint256", "name": "counter", "type": "uint256"}
                ],
                "internalType": "struct ISeaport.OrderComponents",
                "name": "components",
                "type": "tuple"
            }
        ],
        "stateMutability": "view",
        "type": "function"
    }
]


def get_web3():
    """Initialize and return Web3 instance."""
    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    if not w3.is_connected():
        print("Error: Could not connect to RPC")
        sys.exit(1)
    return w3


def get_account():
    """Get account from private key."""
    if not PRIVATE_KEY:
        print("Error: PRIVATE_KEY not set in environment")
        sys.exit(1)
    return Account.from_key(PRIVATE_KEY)


def get_all_token_ids(w3, collection_address, owner_address):
    """Get all token IDs owned by an address for a collection."""
    contract = w3.eth.contract(address=collection_address, abi=ERC721_ABI)
    
    try:
        balance = contract.functions.balanceOf(owner_address).call()
        print(f"Found {balance} NFTs owned by {owner_address}")
        
        token_ids = []
        for i in range(balance):
            token_id = contract.functions.tokenOfOwnerByIndex(owner_address, i).call()
            token_ids.append(token_id)
        
        return token_ids
    except Exception as e:
        print(f"Error getting token IDs (collection may not support enumeration): {e}")
        sys.exit(1)


def get_eip712_data(chain_id, components):
    """Build EIP-712 typed data for Seaport order signing."""
    return {
        "types": {
            "EIP712Domain": [
                {"name": "name", "type": "string"},
                {"name": "version", "type": "string"},
                {"name": "chainId", "type": "uint256"},
                {"name": "verifyingContract", "type": "address"},
            ],
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
                {"name": "counter", "type": "uint256"},
            ],
            "OfferItem": [
                {"name": "itemType", "type": "uint8"},
                {"name": "token", "type": "address"},
                {"name": "identifierOrCriteria", "type": "uint256"},
                {"name": "startAmount", "type": "uint256"},
                {"name": "endAmount", "type": "uint256"},
            ],
            "ConsiderationItem": [
                {"name": "itemType", "type": "uint8"},
                {"name": "token", "type": "address"},
                {"name": "identifierOrCriteria", "type": "uint256"},
                {"name": "startAmount", "type": "uint256"},
                {"name": "endAmount", "type": "uint256"},
                {"name": "recipient", "type": "address"},
            ],
        },
        "primaryType": "OrderComponents",
        "domain": {
            "name": "Seaport",
            "version": "1.6",
            "chainId": chain_id,
            "verifyingContract": SEAPORT_ADDRESS,
        },
        "message": components,
    }


def cmd_create_offer(args):
    """Create a Seaport listing for an NFT."""
    w3 = get_web3()
    account = get_account()
    
    collection = Web3.to_checksum_address(args.collection)
    token_id = args.token_id
    price_eth = args.price
    duration_hours = args.duration
    
    print(f"\n=== Creating Seaport Offer ===")
    print(f"Collection: {collection}")
    print(f"Token ID: {token_id}")
    print(f"Price: {price_eth} ETH")
    print(f"Duration: {duration_hours} hours")
    print(f"Seller: {account.address}")
    
    nft_contract = w3.eth.contract(address=collection, abi=ERC721_ABI)
    helper = w3.eth.contract(address=SEAPORT_HELPER_ADDRESS, abi=HELPER_ABI)
    
    # Verify ownership
    try:
        owner = nft_contract.functions.ownerOf(token_id).call()
        if owner.lower() != account.address.lower():
            print(f"Error: You don't own token {token_id}. Owner is {owner}")
            sys.exit(1)
    except Exception as e:
        print(f"Error checking ownership: {e}")
        sys.exit(1)
    
    # Check and set approval if needed
    print("\n1. Checking Seaport approval...")
    is_approved = nft_contract.functions.isApprovedForAll(account.address, SEAPORT_ADDRESS).call()
    if not is_approved:
        print("   Approving Seaport...")
        nonce = w3.eth.get_transaction_count(account.address)
        tx = nft_contract.functions.setApprovalForAll(SEAPORT_ADDRESS, True).build_transaction({
            'from': account.address,
            'nonce': nonce,
            'gas': 100000,
            'maxFeePerGas': w3.eth.gas_price * 2,
            'maxPriorityFeePerGas': w3.to_wei(1, 'gwei')
        })
        signed_tx = w3.eth.account.sign_transaction(tx, PRIVATE_KEY)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        print(f"   Approval tx: {tx_hash.hex()}")
        w3.eth.wait_for_transaction_receipt(tx_hash)
        print("   Seaport approved!")
    else:
        print("   Already approved.")
    
    # Get royalty info
    print("\n2. Fetching royalty info...")
    price_wei = w3.to_wei(price_eth, 'ether')
    try:
        royalty_receiver, royalty_amount = nft_contract.functions.royaltyInfo(token_id, price_wei).call()
        print(f"   Royalty Receiver: {royalty_receiver}")
        print(f"   Royalty Amount: {w3.from_wei(royalty_amount, 'ether')} ETH ({royalty_amount * 100 // price_wei}%)")
    except Exception:
        print("   No royalty info (ERC2981 not supported), using zero royalties")
        royalty_receiver = "0x0000000000000000000000000000000000000000"
        royalty_amount = 0
    
    # Prepare order
    print("\n3. Preparing order...")
    start_time = int(time.time())
    end_time = start_time + (duration_hours * 3600)
    
    components_tuple = helper.functions.prepareOrderWithRoyalties(
        account.address,
        collection,
        token_id,
        price_wei,
        royalty_receiver,
        royalty_amount,
        start_time,
        end_time
    ).call()
    
    # Convert tuple to dict for EIP-712 signing
    def map_offer_item(item):
        return {
            "itemType": item[0],
            "token": item[1],
            "identifierOrCriteria": item[2],
            "startAmount": item[3],
            "endAmount": item[4]
        }

    def map_consideration_item(item):
        return {
            "itemType": item[0],
            "token": item[1],
            "identifierOrCriteria": item[2],
            "startAmount": item[3],
            "endAmount": item[4],
            "recipient": item[5]
        }

    components_dict = {
        "offerer": components_tuple[0],
        "zone": components_tuple[1],
        "offer": [map_offer_item(i) for i in components_tuple[2]],
        "consideration": [map_consideration_item(i) for i in components_tuple[3]],
        "orderType": components_tuple[4],
        "startTime": components_tuple[5],
        "endTime": components_tuple[6],
        "zoneHash": components_tuple[7],
        "salt": components_tuple[8],
        "conduitKey": components_tuple[9],
        "counter": components_tuple[10]
    }
    
    # Sign order
    print("\n4. Signing order...")
    eip712_data = get_eip712_data(w3.eth.chain_id, components_dict)
    encoded_data = encode_typed_data(full_message=eip712_data)
    signed_message = w3.eth.account.sign_message(encoded_data, private_key=PRIVATE_KEY)
    signature = signed_message.signature.hex()
    
    print("\n=== Offer Created Successfully ===")
    print(f"Signature: {signature}")
    print(f"\nOrder Details:")
    print(f"  Collection: {collection}")
    print(f"  Token ID: {token_id}")
    print(f"  Price: {price_eth} ETH")
    print(f"  Valid from: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(start_time))}")
    print(f"  Valid until: {time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(end_time))}")
    print(f"\nThis order is now valid and can be fulfilled on OpenSea or any Seaport-compatible marketplace.")
    
    # Output order data for potential API submission
    if args.output:
        import json
        order_data = {
            "parameters": {
                "offerer": components_dict["offerer"],
                "zone": components_dict["zone"],
                "offer": components_dict["offer"],
                "consideration": components_dict["consideration"],
                "orderType": components_dict["orderType"],
                "startTime": str(components_dict["startTime"]),
                "endTime": str(components_dict["endTime"]),
                "zoneHash": components_dict["zoneHash"].hex() if isinstance(components_dict["zoneHash"], bytes) else components_dict["zoneHash"],
                "salt": str(components_dict["salt"]),
                "conduitKey": components_dict["conduitKey"].hex() if isinstance(components_dict["conduitKey"], bytes) else components_dict["conduitKey"],
                "totalOriginalConsiderationItems": len(components_dict["consideration"])
            },
            "signature": signature
        }
        with open(args.output, 'w') as f:
            json.dump(order_data, f, indent=2, default=str)
        print(f"\nOrder data saved to: {args.output}")


def cmd_transfer(args):
    """Mass transfer NFTs to a recipient."""
    w3 = get_web3()
    account = get_account()
    
    collection = Web3.to_checksum_address(args.collection)
    recipient = Web3.to_checksum_address(args.to)
    
    print(f"\n=== Mass Transfer NFTs ===")
    print(f"Collection: {collection}")
    print(f"From: {account.address}")
    print(f"To: {recipient}")
    
    # Get token IDs
    if args.transfer_all:
        print("\nFetching all owned tokens...")
        token_ids = get_all_token_ids(w3, collection, account.address)
    else:
        if not args.token_ids:
            print("Error: Must specify --token-ids or --transfer-all")
            sys.exit(1)
        token_ids = [int(x.strip()) for x in args.token_ids.split(',')]
    
    if not token_ids:
        print("No tokens to transfer.")
        return
    
    print(f"Tokens to transfer: {token_ids}")
    
    if not args.yes:
        confirm = input(f"\nTransfer {len(token_ids)} NFTs to {recipient}? (yes/no): ")
        if confirm.lower() != 'yes':
            print("Cancelled.")
            return
    
    nft_contract = w3.eth.contract(address=collection, abi=ERC721_ABI)
    
    successful = 0
    failed = 0
    
    for i, token_id in enumerate(token_ids):
        print(f"\n[{i+1}/{len(token_ids)}] Transferring token {token_id}...")
        try:
            nonce = w3.eth.get_transaction_count(account.address)
            tx = nft_contract.functions.safeTransferFrom(
                account.address,
                recipient,
                token_id
            ).build_transaction({
                'from': account.address,
                'nonce': nonce,
                'gas': 150000,
                'maxFeePerGas': w3.eth.gas_price * 2,
                'maxPriorityFeePerGas': w3.to_wei(1, 'gwei')
            })
            signed_tx = w3.eth.account.sign_transaction(tx, PRIVATE_KEY)
            tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
            print(f"   Tx: {tx_hash.hex()}")
            receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
            if receipt.status == 1:
                print(f"   ✓ Success")
                successful += 1
            else:
                print(f"   ✗ Failed (reverted)")
                failed += 1
        except Exception as e:
            print(f"   ✗ Error: {e}")
            failed += 1
    
    print(f"\n=== Transfer Complete ===")
    print(f"Successful: {successful}")
    print(f"Failed: {failed}")


def cmd_burn(args):
    """Mass burn NFTs."""
    w3 = get_web3()
    account = get_account()
    
    collection = Web3.to_checksum_address(args.collection)
    
    print(f"\n=== Mass Burn NFTs ===")
    print(f"Collection: {collection}")
    print(f"Owner: {account.address}")
    
    # Get token IDs
    if args.burn_all:
        print("\nFetching all owned tokens...")
        token_ids = get_all_token_ids(w3, collection, account.address)
    else:
        if not args.token_ids:
            print("Error: Must specify --token-ids or --burn-all")
            sys.exit(1)
        token_ids = [int(x.strip()) for x in args.token_ids.split(',')]
    
    if not token_ids:
        print("No tokens to burn.")
        return
    
    print(f"Tokens to burn: {token_ids}")
    
    if not args.yes:
        confirm = input(f"\n⚠️  PERMANENTLY BURN {len(token_ids)} NFTs? This cannot be undone! (yes/no): ")
        if confirm.lower() != 'yes':
            print("Cancelled.")
            return
    
    nft_contract = w3.eth.contract(address=collection, abi=ERC721_ABI)
    
    successful = 0
    failed = 0
    
    for i, token_id in enumerate(token_ids):
        print(f"\n[{i+1}/{len(token_ids)}] Burning token {token_id}...")
        try:
            nonce = w3.eth.get_transaction_count(account.address)
            tx = nft_contract.functions.burn(token_id).build_transaction({
                'from': account.address,
                'nonce': nonce,
                'gas': 100000,
                'maxFeePerGas': w3.eth.gas_price * 2,
                'maxPriorityFeePerGas': w3.to_wei(1, 'gwei')
            })
            signed_tx = w3.eth.account.sign_transaction(tx, PRIVATE_KEY)
            tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
            print(f"   Tx: {tx_hash.hex()}")
            receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
            if receipt.status == 1:
                print(f"   🔥 Burned")
                successful += 1
            else:
                print(f"   ✗ Failed (reverted)")
                failed += 1
        except Exception as e:
            print(f"   ✗ Error: {e}")
            failed += 1
    
    print(f"\n=== Burn Complete ===")
    print(f"Burned: {successful}")
    print(f"Failed: {failed}")


def main():
    parser = argparse.ArgumentParser(
        description="Kondux NFT CLI Tool for Ethereum Mainnet",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Create Offer command
    offer_parser = subparsers.add_parser('create-offer', help='Create a Seaport listing for an NFT')
    offer_parser.add_argument('--collection', type=str, default=DEFAULT_KONDUX_COLLECTION,
                              help=f'NFT collection address (default: {DEFAULT_KONDUX_COLLECTION})')
    offer_parser.add_argument('--token-id', type=int, required=True, help='Token ID to list')
    offer_parser.add_argument('--price', type=float, required=True, help='Listing price in ETH')
    offer_parser.add_argument('--duration', type=int, default=168, help='Listing duration in hours (default: 168 = 1 week)')
    offer_parser.add_argument('--output', type=str, help='Output file for order JSON data')
    
    # Transfer command
    transfer_parser = subparsers.add_parser('transfer', help='Mass transfer NFTs to a recipient')
    transfer_parser.add_argument('--collection', type=str, default=DEFAULT_KONDUX_COLLECTION,
                                 help=f'NFT collection address (default: {DEFAULT_KONDUX_COLLECTION})')
    transfer_parser.add_argument('--token-ids', type=str, help='Comma-separated list of token IDs (e.g., 1,2,3)')
    transfer_parser.add_argument('--transfer-all', action='store_true', help='Transfer all owned tokens from collection')
    transfer_parser.add_argument('--to', type=str, required=True, help='Recipient address')
    transfer_parser.add_argument('--yes', '-y', action='store_true', help='Skip confirmation prompt')
    
    # Burn command
    burn_parser = subparsers.add_parser('burn', help='Mass burn NFTs')
    burn_parser.add_argument('--collection', type=str, default=DEFAULT_KONDUX_COLLECTION,
                             help=f'NFT collection address (default: {DEFAULT_KONDUX_COLLECTION})')
    burn_parser.add_argument('--token-ids', type=str, help='Comma-separated list of token IDs (e.g., 1,2,3)')
    burn_parser.add_argument('--burn-all', action='store_true', help='Burn all owned tokens from collection')
    burn_parser.add_argument('--yes', '-y', action='store_true', help='Skip confirmation prompt')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    if args.command == 'create-offer':
        cmd_create_offer(args)
    elif args.command == 'transfer':
        cmd_transfer(args)
    elif args.command == 'burn':
        cmd_burn(args)


if __name__ == "__main__":
    main()
