"""
Updated Seaport Router with OpenSea Compatibility

Key changes from original:
1. Added OpenSea fee (2.5%) as consideration item
2. Uses OpenSea conduit key for approvals
3. Correct API payload format for OpenSea listings API
"""

from datetime import datetime, timedelta
from decimal import Decimal
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException, Query, status
from pydantic import BaseModel, Field
from web3 import Web3
import httpx

# Assume these come from your config
# from core.config import settings

router = APIRouter(prefix="/seaport", tags=["seaport"])


# ---------------------------------------------------------------------------
# OpenSea / Seaport 1.6 constants (mainnet)
# ---------------------------------------------------------------------------

SEAPORT_ADDRESS = Web3.to_checksum_address(
    "0x0000000000000068F116a894984e2DB1123eB395"
)

# OpenSea's conduit - seller must approve THIS address for NFT transfers
OPENSEA_CONDUIT_ADDRESS = Web3.to_checksum_address(
    "0x1E0049783F008A0085193E00003D00cd54003c71"
)

# OpenSea's conduit key (used in order signing)
OPENSEA_CONDUIT_KEY = "0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000"

# OpenSea fee recipient (receives 2.5% platform fee)
OPENSEA_FEE_RECIPIENT = Web3.to_checksum_address(
    "0x0000a26b00c1F0DF003000390027140000fAa719"
)

# Your SeaportHelper contract
SEAPORT_HELPER_ADDRESS = Web3.to_checksum_address(
    "0xc87b9e84BAe43aD76918b5d5FfC4c0DdE7031CCA"  # Update after redeploying
)


# ---------------------------------------------------------------------------
# ABIs
# ---------------------------------------------------------------------------

ERC721_ABI = [
    {
        "inputs": [
            {"internalType": "uint256", "name": "tokenId", "type": "uint256"},
            {"internalType": "uint256", "name": "salePrice", "type": "uint256"},
        ],
        "name": "royaltyInfo",
        "outputs": [
            {"internalType": "address", "name": "", "type": "address"},
            {"internalType": "uint256", "name": "", "type": "uint256"},
        ],
        "stateMutability": "view",
        "type": "function",
    },
    {
        "inputs": [
            {"internalType": "address", "name": "owner", "type": "address"},
            {"internalType": "address", "name": "operator", "type": "address"},
        ],
        "name": "isApprovedForAll",
        "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
        "stateMutability": "view",
        "type": "function",
    },
]

# Updated helper ABI with prepareOrderForOpenSea
HELPER_ABI = [
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
# Helper Functions
# ---------------------------------------------------------------------------

def _get_w3(rpc_url: str) -> Web3:
    w3 = Web3(Web3.HTTPProvider(rpc_url))
    if not w3.is_connected():
        raise HTTPException(status_code=503, detail="RPC unavailable")
    return w3


def calculate_opensea_fee(price_wei: int) -> int:
    """Calculate OpenSea's 2.5% fee (250 basis points)."""
    return (price_wei * 250) // 10000


# ---------------------------------------------------------------------------
# Pydantic Models
# ---------------------------------------------------------------------------

class OfferItem(BaseModel):
    itemType: int
    token: str
    identifierOrCriteria: str | int
    startAmount: str | int
    endAmount: str | int


class ConsiderationItem(OfferItem):
    recipient: str


class OrderComponents(BaseModel):
    offerer: str
    zone: str
    offer: List[OfferItem]
    consideration: List[ConsiderationItem]
    orderType: int
    startTime: int
    endTime: int
    zoneHash: str
    salt: int
    conduitKey: str
    counter: int


class TypedData(BaseModel):
    types: Dict[str, Any]
    primaryType: str
    domain: Dict[str, Any]
    message: Dict[str, Any]


class PrepareResponse(BaseModel):
    chainId: int
    seaportAddress: str
    helperAddress: str
    conduitAddress: str  # NEW: For frontend approval
    priceWei: str
    openseaFee: str  # NEW
    royaltyReceiver: str
    royaltyAmount: str
    sellerAmount: str  # NEW
    components: OrderComponents
    typedData: TypedData
    startTime: int
    endTime: int
    requiresApproval: bool  # NEW: Check if conduit approval needed


class CreateOrderRequest(BaseModel):
    parameters: OrderComponents
    signature: str = Field(..., description="EIP-712 signature from the offerer")


class CreateOrderResponse(BaseModel):
    order: Dict[str, Any]


# ---------------------------------------------------------------------------
# EIP-712 Builder
# ---------------------------------------------------------------------------

def _build_eip712(chain_id: int, components: Dict[str, Any]) -> Dict[str, Any]:
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
            "verifyingContract": str(SEAPORT_ADDRESS),
        },
        "message": components,
    }


# ---------------------------------------------------------------------------
# GET /seaport/order – Prepare order for OpenSea
# ---------------------------------------------------------------------------

@router.get("/order", response_model=PrepareResponse, status_code=status.HTTP_200_OK)
async def prepare_order(
    offerer: str = Query(..., description="Seller address"),
    token_id: int = Query(..., ge=0, description="Token ID to list"),
    collection: str = Query(..., description="ERC-721 collection address"),
    price_eth: Decimal = Query(..., gt=Decimal("0"), description="Price in ETH"),
    duration_hours: int = Query(168, ge=1, le=24 * 30, description="Duration (hours)"),
    rpc_url: str = Query(..., description="RPC URL"),
):
    """
    Prepare a Seaport order for OpenSea listing.
    
    This endpoint:
    1. Queries ERC2981 royalty info
    2. Calculates OpenSea 2.5% fee
    3. Prepares order with all consideration items
    4. Returns EIP-712 typed data for signing
    """
    chain_id = 1  # Mainnet
    w3 = _get_w3(rpc_url)
    
    try:
        offerer = Web3.to_checksum_address(offerer)
        collection = Web3.to_checksum_address(collection)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid address format")

    nft = w3.eth.contract(address=collection, abi=ERC721_ABI)
    helper = w3.eth.contract(address=SEAPORT_HELPER_ADDRESS, abi=HELPER_ABI)

    price_wei = int(w3.to_wei(price_eth, "ether"))
    
    # Calculate OpenSea fee (2.5%)
    opensea_fee = calculate_opensea_fee(price_wei)

    # Get ERC2981 royalty info
    royalty_receiver = "0x0000000000000000000000000000000000000000"
    royalty_amount = 0
    try:
        royalty_receiver, royalty_amount = nft.functions.royaltyInfo(token_id, price_wei).call()
    except Exception:
        pass  # No royalty if ERC2981 not supported
    
    # Calculate seller amount
    seller_amount = price_wei - opensea_fee - royalty_amount

    # Check if conduit approval is needed
    try:
        is_approved = nft.functions.isApprovedForAll(offerer, OPENSEA_CONDUIT_ADDRESS).call()
    except Exception:
        is_approved = False

    start_time = int(datetime.utcnow().timestamp())
    end_time = start_time + int(timedelta(hours=duration_hours).total_seconds())

    # Call the updated helper with OpenSea fee
    try:
        components_tuple = helper.functions.prepareOrderForOpenSea(
            offerer,
            collection,
            token_id,
            price_wei,
            royalty_receiver,
            royalty_amount,
            OPENSEA_FEE_RECIPIENT,
            opensea_fee,
            bytes.fromhex(OPENSEA_CONDUIT_KEY[2:]),  # Convert hex string to bytes32
            start_time,
            end_time,
        ).call()
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Helper call failed: {str(e)}")

    # Map tuple to dict
    def map_offer_item(item):
        return {
            "itemType": item[0],
            "token": item[1],
            "identifierOrCriteria": item[2],
            "startAmount": item[3],
            "endAmount": item[4],
        }

    def map_consideration_item(item):
        return {
            "itemType": item[0],
            "token": item[1],
            "identifierOrCriteria": item[2],
            "startAmount": item[3],
            "endAmount": item[4],
            "recipient": item[5],
        }

    components_dict = {
        "offerer": components_tuple[0],
        "zone": components_tuple[1],
        "offer": [map_offer_item(i) for i in components_tuple[2]],
        "consideration": [map_consideration_item(i) for i in components_tuple[3]],
        "orderType": components_tuple[4],
        "startTime": components_tuple[5],
        "endTime": components_tuple[6],
        "zoneHash": Web3.to_hex(components_tuple[7]) if isinstance(components_tuple[7], bytes) else components_tuple[7],
        "salt": components_tuple[8],
        "conduitKey": Web3.to_hex(components_tuple[9]) if isinstance(components_tuple[9], bytes) else components_tuple[9],
        "counter": components_tuple[10],
    }

    typed_data = _build_eip712(chain_id, components_dict)

    return PrepareResponse(
        chainId=chain_id,
        seaportAddress=str(SEAPORT_ADDRESS),
        helperAddress=str(SEAPORT_HELPER_ADDRESS),
        conduitAddress=str(OPENSEA_CONDUIT_ADDRESS),
        priceWei=str(price_wei),
        openseaFee=str(opensea_fee),
        royaltyReceiver=royalty_receiver,
        royaltyAmount=str(royalty_amount),
        sellerAmount=str(seller_amount),
        components=OrderComponents(**components_dict),
        typedData=TypedData(**typed_data),
        startTime=start_time,
        endTime=end_time,
        requiresApproval=not is_approved,
    )


# ---------------------------------------------------------------------------
# POST /seaport/order – Create signed order object
# ---------------------------------------------------------------------------

@router.post("/order", response_model=CreateOrderResponse, status_code=status.HTTP_201_CREATED)
async def create_order(req: CreateOrderRequest):
    """
    Accept signed order and return formatted order for OpenSea API.
    """
    order = {
        "parameters": {
            "offerer": req.parameters.offerer,
            "zone": req.parameters.zone,
            "offer": [i.model_dump() for i in req.parameters.offer],
            "consideration": [i.model_dump() for i in req.parameters.consideration],
            "orderType": req.parameters.orderType,
            "startTime": str(req.parameters.startTime),
            "endTime": str(req.parameters.endTime),
            "zoneHash": req.parameters.zoneHash,
            "salt": str(req.parameters.salt),
            "conduitKey": req.parameters.conduitKey,
            "totalOriginalConsiderationItems": len(req.parameters.consideration),
            "counter": str(req.parameters.counter),
        },
        "signature": req.signature,
        "protocol_address": str(SEAPORT_ADDRESS),
    }
    return CreateOrderResponse(order=order)


# ---------------------------------------------------------------------------
# POST /seaport/listing – Submit to OpenSea
# ---------------------------------------------------------------------------

@router.post("/listing", status_code=status.HTTP_201_CREATED)
async def post_listing(
    order: Dict[str, Any],
    opensea_api_key: str = Query(..., description="OpenSea API Key"),
) -> Dict[str, Any]:
    """
    Submit order to OpenSea listings API.
    """
    url = "https://api.opensea.io/v2/orders/ethereum/seaport/listings"
    headers = {
        "X-API-KEY": opensea_api_key,
        "Content-Type": "application/json",
    }

    # Ensure protocol_address is set
    order.setdefault("protocol_address", str(SEAPORT_ADDRESS))

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(url, headers=headers, json=order)
    except httpx.RequestError as e:
        raise HTTPException(status_code=503, detail=f"OpenSea unreachable: {str(e)}")

    if resp.status_code >= 400:
        try:
            detail = resp.json()
        except Exception:
            detail = resp.text
        raise HTTPException(status_code=resp.status_code, detail=detail)

    return resp.json()
