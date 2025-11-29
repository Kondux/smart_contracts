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

# Configuration
RPC_URL = os.getenv("RPC_URL", "https://rpc.sepolia.org")
SELLER_PK = os.getenv("SELLER_PK")
BUYER_PK = os.getenv("BUYER_PK")
MINTER_PK = os.getenv("MINTER_PK")
KONDUX_IMPL_ADDRESS = os.getenv("KONDUX_IMPL_ADDRESS")
SEAPORT_HELPER_ADDRESS = os.getenv("SEAPORT_HELPER_ADDRESS")

# Seaport 1.6 Address (Same on Mainnet and Sepolia)
SEAPORT_ADDRESS = "0x0000000000000068F116a894984e2DB1123eB395"

# ABIs (Minimal needed)
KONDUX_ABI = [
    {
        "inputs": [{"internalType": "address", "name": "to", "type": "address"}, {"internalType": "uint256", "name": "dna", "type": "uint256"}],
        "name": "safeMint",
        "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
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
        "anonymous": False,
        "inputs": [
            {"indexed": True, "internalType": "address", "name": "from", "type": "address"},
            {"indexed": True, "internalType": "address", "name": "to", "type": "address"},
            {"indexed": True, "internalType": "uint256", "name": "tokenId", "type": "uint256"}
        ],
        "name": "Transfer",
        "type": "event"
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
                            {"internalType": "uint256", "name": "totalOriginalConsiderationItems", "type": "uint256"}
                        ],
                        "internalType": "struct ISeaport.OrderParameters",
                        "name": "parameters",
                        "type": "tuple"
                    },
                    {"internalType": "bytes", "name": "signature", "type": "bytes"}
                ],
                "internalType": "struct ISeaport.Order",
                "name": "order",
                "type": "tuple"
            },
            {"internalType": "bytes32", "name": "fulfillerConduitKey", "type": "bytes32"}
        ],
        "name": "settleDeal",
        "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
        "stateMutability": "payable",
        "type": "function"
    }
]

def get_eip712_data(chain_id, components):
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

def main():
    parser = argparse.ArgumentParser(description="Execute a Seaport trade for Kondux NFT")
    parser.add_argument("--price", type=float, required=True, help="Selling price in ETH")
    parser.add_argument("--token-id", type=int, help="Token ID to sell (optional, will mint if not provided)")
    args = parser.parse_args()

    if not all([SELLER_PK, BUYER_PK, MINTER_PK, KONDUX_IMPL_ADDRESS, SEAPORT_HELPER_ADDRESS]):
        print("Error: Missing environment variables. Please check .env")
        sys.exit(1)

    w3 = Web3(Web3.HTTPProvider(RPC_URL))
    if not w3.is_connected():
        print("Error: Could not connect to RPC")
        sys.exit(1)

    seller = Account.from_key(SELLER_PK)
    buyer = Account.from_key(BUYER_PK)
    minter = Account.from_key(MINTER_PK)

    print(f"Seller: {seller.address}")
    print(f"Buyer: {buyer.address}")
    print(f"Minter: {minter.address}")

    kondux = w3.eth.contract(address=KONDUX_IMPL_ADDRESS, abi=KONDUX_ABI)
    helper = w3.eth.contract(address=SEAPORT_HELPER_ADDRESS, abi=HELPER_ABI)

    token_id = args.token_id

    if token_id is None:
        # 1. Mint NFT to Seller
        print("\n1. Minting NFT to Seller...")
        nonce = w3.eth.get_transaction_count(minter.address)
        tx = kondux.functions.safeMint(seller.address, 1).build_transaction({
            'from': minter.address,
            'nonce': nonce,
            'gas': 2000000,
            'gasPrice': w3.eth.gas_price
        })
        signed_tx = w3.eth.account.sign_transaction(tx, MINTER_PK)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
        print(f"Mint tx hash: {tx_hash.hex()}")
        receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
        
        # Extract Token ID from logs
        transfer_event_signature = w3.keccak(text="Transfer(address,address,uint256)").hex()
        for log in receipt['logs']:
            if log['topics'][0].hex() == transfer_event_signature:
                token_id = int(log['topics'][3].hex(), 16)
                break
        
        if token_id is None:
            print("Error: Could not find Token ID in mint receipt")
            sys.exit(1)
        print(f"Minted Token ID: {token_id}")
    else:
        print(f"\n1. Using existing Token ID: {token_id}")

    # 2. Approve Seaport
    print("\n2. Approving Seaport...")
    nonce = w3.eth.get_transaction_count(seller.address)
    tx = kondux.functions.setApprovalForAll(SEAPORT_ADDRESS, True).build_transaction({
        'from': seller.address,
        'nonce': nonce,
        'gas': 500000,
        'gasPrice': w3.eth.gas_price
    })
    signed_tx = w3.eth.account.sign_transaction(tx, SELLER_PK)
    tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
    print(f"Approval tx hash: {tx_hash.hex()}")
    w3.eth.wait_for_transaction_receipt(tx_hash)
    print("Seaport approved.")

    # 3. Prepare Order
    print("\n3. Preparing Order...")
    price_wei = w3.to_wei(args.price, 'ether')
    
    # Get royalty info to pass to helper (helper calculates it too, but we need to pass it)
    # Actually helper takes royaltyReceiver and royaltyAmount as inputs to construct the order
    royalty_receiver, royalty_amount = kondux.functions.royaltyInfo(token_id, price_wei).call()
    print(f"Royalty Receiver: {royalty_receiver}")
    print(f"Royalty Amount: {w3.from_wei(royalty_amount, 'ether')} ETH")

    start_time = int(time.time())
    end_time = start_time + 3600 # 1 hour

    # Call helper to get components
    components_tuple = helper.functions.prepareOrderWithRoyalties(
        seller.address,
        KONDUX_IMPL_ADDRESS,
        token_id,
        price_wei,
        royalty_receiver,
        royalty_amount,
        start_time,
        end_time
    ).call()

    # Convert tuple to dict for EIP-712 signing
    # Tuple structure: (offerer, zone, offer[], consideration[], orderType, startTime, endTime, zoneHash, salt, conduitKey, counter)
    # OfferItem: (itemType, token, identifierOrCriteria, startAmount, endAmount)
    # ConsiderationItem: (itemType, token, identifierOrCriteria, startAmount, endAmount, recipient)

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

    # 4. Sign Order
    print("\n4. Signing Order...")
    eip712_data = get_eip712_data(w3.eth.chain_id, components_dict)
    encoded_data = encode_typed_data(full_message=eip712_data)
    signed_message = w3.eth.account.sign_message(encoded_data, private_key=SELLER_PK)
    signature = signed_message.signature.hex()
    print(f"Signature: {signature}")

    # 5. Settle Deal
    print("\n5. Settling Deal...")
    
    # Construct Order struct for settleDeal
    # Order: (parameters, signature)
    # OrderParameters: same as components but with totalOriginalConsiderationItems instead of counter
    
    order_parameters = list(components_tuple)
    # Replace counter (index 10) with totalOriginalConsiderationItems (length of consideration array)
    order_parameters[10] = len(components_tuple[3]) 
    
    order_struct = (tuple(order_parameters), signature)

    nonce = w3.eth.get_transaction_count(buyer.address)
    tx = helper.functions.settleDeal(
        order_struct,
        bytes([0] * 32) # fulfillerConduitKey (0 for none)
    ).build_transaction({
        'from': buyer.address,
        'value': price_wei,
        'nonce': nonce,
        'gas': 500000, # Estimate gas might be better, but 500k should be enough
        'gasPrice': w3.eth.gas_price
    })
    
    signed_tx = w3.eth.account.sign_transaction(tx, BUYER_PK)
    tx_hash = w3.eth.send_raw_transaction(signed_tx.raw_transaction)
    print(f"Settlement tx hash: {tx_hash.hex()}")
    
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    if receipt.status == 1:
        print("\nTrade Successful!")
        print(f"NFT {token_id} transferred to {buyer.address}")
    else:
        print("\nTrade Failed!")

if __name__ == "__main__":
    main()
