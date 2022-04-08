// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

/* Signature Verification

How to Sign and Verify
# Signing
1. Create message to sign
2. Hash the message
3. Sign the hash (off chain, keep your private key secret)

# Verify
1. Recreate hash from the original message
2. Recover signer from signature and hash
3. Compare recovered signer to claimed signer
*/

contract VerifySignature is EIP712("VerifySignature", "1") {

    function verify(
        uint256 blocknumber,
        address wallet,
        uint256 nonce,
        bytes32 digest,
        bytes memory signature,
        address _signerAddress
    ) public view returns (bool) {
        bytes32 calculatedDigest = _hashTypedDataV4(keccak256(abi.encode(
            keccak256("Athorization(uint256 blocknumber,address wallet,uint256 nonce)"),
            blocknumber,
            wallet,
            nonce
        )));

        return calculatedDigest == digest &&
            recoverSigner(ECDSA.toEthSignedMessageHash(digest), signature) == _signerAddress;
            
    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature) 
        public
        pure
        returns (address)
    {
        return ECDSA.recover(_ethSignedMessageHash, _signature);
    }

}
