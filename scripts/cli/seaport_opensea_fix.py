"""
OpenSea Seaport Integration Fix

This file documents the key changes needed to make Seaport listings appear on OpenSea.

## Key Issues Fixed:

1. **Missing OpenSea Fee (2.5%)**
   OpenSea requires their platform fee as a consideration item.
   
2. **OpenSea API Payload Format**
   The listing API expects a specific structure with proper field names.

3. **Conduit Key**
   Seller must approve OpenSea's conduit for transfers.

## OpenSea Constants (Mainnet):
"""

# ---------------------------------------------------------------------------
# OpenSea Constants (Mainnet)
# ---------------------------------------------------------------------------

# OpenSea Fee Recipient (receives 2.5% platform fee)
OPENSEA_FEE_RECIPIENT = "0x0000a26b00c1F0DF003000390027140000fAa719"

# OpenSea Conduit Address (approved operator for transfers)
OPENSEA_CONDUIT_ADDRESS = "0x1E0049783F008A0085193E00003D00cd54003c71"

# OpenSea Conduit Key (32 bytes)
OPENSEA_CONDUIT_KEY = "0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000"

# OpenSea Zone (for restricted orders, not needed for FULL_OPEN)
OPENSEA_ZONE = "0x0000000000000000000000000000000000000000"

# Seaport 1.6 Address
SEAPORT_ADDRESS = "0x0000000000000068F116a894984e2DB1123eB395"

# OpenSea API Base URLs
OPENSEA_API_BASE_MAINNET = "https://api.opensea.io"
OPENSEA_API_BASE_TESTNET = "https://testnets-api.opensea.io"

# ---------------------------------------------------------------------------
# Fee Calculation
# ---------------------------------------------------------------------------

def calculate_opensea_fee(price_wei: int) -> int:
    """Calculate OpenSea's 2.5% fee."""
    return (price_wei * 250) // 10000


def calculate_consideration_amounts(price_wei: int, royalty_amount: int) -> dict:
    """
    Calculate the breakdown of a sale price into:
    - Seller amount
    - OpenSea fee (2.5%)
    - Royalty amount
    """
    opensea_fee = calculate_opensea_fee(price_wei)
    seller_amount = price_wei - opensea_fee - royalty_amount
    
    return {
        "seller_amount": seller_amount,
        "opensea_fee": opensea_fee,
        "royalty_amount": royalty_amount,
        "total": seller_amount + opensea_fee + royalty_amount,
    }


# ---------------------------------------------------------------------------
# Updated Helper ABI (with prepareOrderForOpenSea)
# ---------------------------------------------------------------------------

HELPER_ABI_UPDATED = [
    {
        "inputs": [
            {"internalType": "address", "name": "offerer", "type": "address"},
            {"internalType": "address", "name": "collection", "type": "address"},
            {"internalType": "uint256", "name": "tokenId", "type": "uint256"},
            {"internalType": "uint256", "name": "price", "type": "uint256"},
            {"internalType": "address", "name": "royaltyReceiver", "type": "address"},
            {"internalType": "uint256", "name": "royaltyAmount", "type": "uint256"},
            {"internalType": "address", "name": "openseaFeeRecipient", "type": "address"},
            {"internalType": "uint256", "name": "openseaFeeAmount", "type": "uint256"},
            {"internalType": "bytes32", "name": "conduitKey", "type": "bytes32"},
            {"internalType": "uint256", "name": "startTime", "type": "uint256"},
            {"internalType": "uint256", "name": "endTime", "type": "uint256"},
        ],
        "name": "prepareOrderForOpenSea",
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
                            {"internalType": "uint256", "name": "endAmount", "type": "uint256"},
                        ],
                        "internalType": "struct ISeaport.OfferItem[]",
                        "name": "offer",
                        "type": "tuple[]",
                    },
                    {
                        "components": [
                            {"internalType": "enum ISeaport.ItemType", "name": "itemType", "type": "uint8"},
                            {"internalType": "address", "name": "token", "type": "address"},
                            {"internalType": "uint256", "name": "identifierOrCriteria", "type": "uint256"},
                            {"internalType": "uint256", "name": "startAmount", "type": "uint256"},
                            {"internalType": "uint256", "name": "endAmount", "type": "uint256"},
                            {"internalType": "address payable", "name": "recipient", "type": "address"},
                        ],
                        "internalType": "struct ISeaport.ConsiderationItem[]",
                        "name": "consideration",
                        "type": "tuple[]",
                    },
                    {"internalType": "enum ISeaport.OrderType", "name": "orderType", "type": "uint8"},
                    {"internalType": "uint256", "name": "startTime", "type": "uint256"},
                    {"internalType": "uint256", "name": "endTime", "type": "uint256"},
                    {"internalType": "bytes32", "name": "zoneHash", "type": "bytes32"},
                    {"internalType": "uint256", "name": "salt", "type": "uint256"},
                    {"internalType": "bytes32", "name": "conduitKey", "type": "bytes32"},
                    {"internalType": "uint256", "name": "counter", "type": "uint256"},
                ],
                "internalType": "struct ISeaport.OrderComponents",
                "name": "components",
                "type": "tuple",
            }
        ],
        "stateMutability": "view",
        "type": "function",
    }
]


# ---------------------------------------------------------------------------
# OpenSea Listing API Payload Format
# ---------------------------------------------------------------------------

def build_opensea_listing_payload(order_params: dict, signature: str) -> dict:
    """
    Build the correct payload format for OpenSea's listing API.
    
    OpenSea expects:
    {
        "parameters": {
            "offerer": "0x...",
            "zone": "0x...",
            "offer": [...],
            "consideration": [...],
            "orderType": 0,
            "startTime": "1234567890",
            "endTime": "1234567890",
            "zoneHash": "0x...",
            "salt": "123456",
            "conduitKey": "0x...",
            "totalOriginalConsiderationItems": 3,
            "counter": "0"
        },
        "signature": "0x...",
        "protocol_address": "0x0000000000000068F116a894984e2DB1123eB395"
    }
    """
    return {
        "parameters": {
            "offerer": order_params["offerer"],
            "zone": order_params["zone"],
            "offer": order_params["offer"],
            "consideration": order_params["consideration"],
            "orderType": order_params["orderType"],
            "startTime": str(order_params["startTime"]),
            "endTime": str(order_params["endTime"]),
            "zoneHash": order_params["zoneHash"],
            "salt": str(order_params["salt"]),
            "conduitKey": order_params["conduitKey"],
            "totalOriginalConsiderationItems": len(order_params["consideration"]),
            "counter": str(order_params.get("counter", 0)),
        },
        "signature": signature,
        "protocol_address": SEAPORT_ADDRESS,
    }


# ---------------------------------------------------------------------------
# Example: Full Flow
# ---------------------------------------------------------------------------

EXAMPLE_FLOW = """
## Complete OpenSea Listing Flow:

### 1. Frontend: Get order parameters
```javascript
const response = await fetch(`/seaport/order?offerer=${wallet}&token_id=${tokenId}&price_eth=${price}`);
const { components, typedData } = await response.json();
```

### 2. Frontend: Sign the order (EIP-712)
```javascript
const signature = await wallet.signTypedData(
    typedData.domain,
    typedData.types,
    typedData.message
);
```

### 3. Frontend: Ensure approval for OpenSea conduit
```javascript
const isApproved = await nftContract.isApprovedForAll(wallet, OPENSEA_CONDUIT_ADDRESS);
if (!isApproved) {
    await nftContract.setApprovalForAll(OPENSEA_CONDUIT_ADDRESS, true);
}
```

### 4. Backend: Submit to OpenSea
```python
payload = build_opensea_listing_payload(components, signature)
response = await httpx.post(
    "https://api.opensea.io/v2/orders/ethereum/seaport/listings",
    headers={"X-API-KEY": OPENSEA_API_KEY},
    json=payload
)
```

### 5. Verification
- Check OpenSea collection page
- Order should appear within 1-2 minutes
- Verify consideration items include seller + OpenSea fee + royalty
"""


if __name__ == "__main__":
    # Example calculation
    price_eth = 1.0
    price_wei = int(price_eth * 10**18)
    royalty_bps = 100  # 1%
    royalty_amount = (price_wei * royalty_bps) // 10000
    
    amounts = calculate_consideration_amounts(price_wei, royalty_amount)
    
    print("=" * 60)
    print("OpenSea Listing Fee Breakdown")
    print("=" * 60)
    print(f"Sale Price:    {price_eth} ETH ({price_wei} wei)")
    print(f"OpenSea Fee:   {amounts['opensea_fee'] / 10**18:.4f} ETH (2.5%)")
    print(f"Royalty:       {amounts['royalty_amount'] / 10**18:.4f} ETH ({royalty_bps/100}%)")
    print(f"Seller Gets:   {amounts['seller_amount'] / 10**18:.4f} ETH")
    print(f"Total:         {amounts['total'] / 10**18:.4f} ETH")
    print("=" * 60)
    print()
    print("Required Consideration Items:")
    print(f"  1. Seller:   {amounts['seller_amount']} wei → offerer")
    print(f"  2. OpenSea:  {amounts['opensea_fee']} wei → {OPENSEA_FEE_RECIPIENT}")
    print(f"  3. Royalty:  {amounts['royalty_amount']} wei → royalty_receiver")
