#!/bin/bash
export PATH=$PATH:~/.foundry/bin

echo "Checking royalty for 10 ETH sale..."
cast call 0x5f056911b9FC29f991039e4322b7755ccc9CbE9D \
  "royaltyInfo(uint256,uint256)" \
  0 \
  10000000000000000000 \
  --rpc-url https://eth-mainnet.g.alchemy.com/v2/NWbAcPvkpq7yLbeXhubWbhIRIKiH-oFf
