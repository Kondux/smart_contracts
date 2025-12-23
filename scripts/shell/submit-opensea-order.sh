#!/bin/bash
cd /mnt/d/git/smart_contracts
sed -i "s/\r$//" .env
set -a && source .env && set +a

# Order with 3 consideration items: seller (94%), OpenSea fee (1%), creator fee (5%)
ORDER_JSON='{
  "parameters": {
    "offerer": "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2",
    "zone": "0x000056F7000000EcE9003ca63978907a00FFD100",
    "zoneHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "startTime": "1766419319",
    "endTime": "1769011319",
    "orderType": 2,
    "offer": [
      {
        "itemType": 2,
        "token": "0xdC75300bAbaC28BA2A28393D3494DeEeE452E361",
        "identifierOrCriteria": "1",
        "startAmount": "1",
        "endAmount": "1"
      }
    ],
    "consideration": [
      {
        "itemType": 0,
        "token": "0x0000000000000000000000000000000000000000",
        "identifierOrCriteria": "0",
        "startAmount": "940000000000000",
        "endAmount": "940000000000000",
        "recipient": "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2"
      },
      {
        "itemType": 0,
        "token": "0x0000000000000000000000000000000000000000",
        "identifierOrCriteria": "0",
        "startAmount": "10000000000000",
        "endAmount": "10000000000000",
        "recipient": "0x0000a26b00c1F0DF003000390027140000fAa719"
      },
      {
        "itemType": 0,
        "token": "0x0000000000000000000000000000000000000000",
        "identifierOrCriteria": "0",
        "startAmount": "50000000000000",
        "endAmount": "50000000000000",
        "recipient": "0xEA4F2710def06Ee87acDC8d449A198A08E650B64"
      }
    ],
    "totalOriginalConsiderationItems": 3,
    "salt": "0x24bc5ac3d04c9a5549f4e39ee7709cf206cc9804661075dd272d4e76c559d454",
    "conduitKey": "0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000",
    "counter": "379992764601292891473010049456058744763"
  },
  "signature": "0xcc6fe025b6df6ca08f06e1f30a2158f39b362a77b62210ad4bae8fe9c2a4f74631a33e2bf2a0618595ceb9653ea1cc238cd93f62b8bf515dbbf88e5b9306ae281c",
  "protocol_address": "0x0000000000000068F116a894984e2DB1123eB395"
}'

echo "=== Submitting Order to OpenSea ==="
curl -X POST "https://api.opensea.io/api/v2/orders/ethereum/seaport/listings" \
  -H "Content-Type: application/json" \
  -H "X-API-KEY: $OPENSEA_API_KEY" \
  -d "$ORDER_JSON"
echo ""
