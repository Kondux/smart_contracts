# Helix Token (HLX)

Helix Token (HLX) is an ERC20 token with additional restrictions and features built on top of the Ethereum blockchain. It is designed to provide controlled token transfers and role-based access control for minting and burning. The token is suitable for projects that require more granular control over token transfers and specific actions, such as minting and burning.

## Usage

The Helix Token (HLX) can be used in various applications, such as decentralized finance (DeFi) platforms, digital collectibles, or any other project that requires a token with additional transfer restrictions and role-based access control.

## Restrictions

1. Direct transfers between users are not allowed by default. This means that users cannot send tokens directly to other users without involving a whitelisted contract or having the global unrestricted transfers enabled.

2. Transfers can only be initiated on behalf of users by contracts that have been explicitly whitelisted by an admin. This allows specific contracts to facilitate token transfers, such as decentralized exchanges or other DeFi protocols.

3. The unrestricted transfers feature can be enabled by an admin to allow transfers between users without restrictions. However, this feature should be used with caution, as it removes one of the primary security features of the token.

## Roles and Rules

The Helix Token has the following roles:

1. **Admin**: The admin role is responsible for managing the token's settings and configurations, such as adding or removing contracts from the whitelist and toggling the unrestricted transfers feature.

2. **Minter**: The minter role is responsible for minting new tokens. Only addresses with the minter role can create new tokens, which can then be distributed to users or other addresses.

3. **Burner**: The burner role is responsible for burning tokens. Only addresses with the burner role can destroy tokens, effectively removing them from the total supply.

Each role has specific rules and restrictions that must be followed to ensure the proper functioning of the token:

- Only the admin can manage the whitelist of allowed contracts and enable or disable the unrestricted transfers feature.

- Only minters can create new tokens.

- Only burners can destroy tokens.

These roles and rules provide a foundation for building a secure and controlled token ecosystem with Helix Token (HLX).
