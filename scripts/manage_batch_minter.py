#!/usr/bin/env python3
"""High-level wrapper around the Forge Kondux batch minter deployment script.

This utility centralises common tasks:
- network-aware deployments using Alchemy RPC endpoints derived from `.env`
- local smoke tests against a mainnet fork
- standalone contract verification leveraging the address book
- persistence helpers for the deployment address log

Usage examples:
    python scripts/manage_batch_minter.py deploy --network sepolia
    python scripts/manage_batch_minter.py smoke --port 8545
    python scripts/manage_batch_minter.py verify --network mainnet
"""

from __future__ import annotations

import argparse
import json
import os
import shlex
import shutil
import string
import subprocess
import sys
import time
from pathlib import Path
from dataclasses import dataclass
from typing import Any, Callable, Dict, List, Mapping, Optional, Sequence, Tuple, cast

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_TARGET = "script/DeployKonduxBatchMinter.s.sol:DeployKonduxBatchMinterScript"
ADDRESS_BOOK_PATH = ROOT / "docs" / "deployments" / "kondux-batchminter" / "address-book.json"
ENV_PATH = ROOT / ".env"
FORGE_BIN_OVERRIDE = os.environ.get("FORGE_BIN")
ANVIL_BIN_OVERRIDE = os.environ.get("ANVIL_BIN")

CHAIN_ID_TO_NETWORK = {
    1: "mainnet",
    11155111: "sepolia",
    31337: "hardhat",
}

ALCHEMY_ENDPOINTS = {
    "mainnet": (
        ["ALCHEMY_MAINNET_API_KEY", "ALCHEMY_API_KEY"],
        "https://eth-mainnet.g.alchemy.com/v2/{key}",
    ),
    "sepolia": (
        ["ALCHEMY_SEPOLIA_API_KEY", "ALCHEMY_API_KEY"],
        "https://eth-sepolia.g.alchemy.com/v2/{key}",
    ),
}

NETWORK_DEFAULTS: Dict[str, Dict[str, object]] = {
    "mainnet": {
        "label": "Ethereum Mainnet",
        "kondux": {
            "name": "Kondux kNFT",
            "symbol": "kNFT",
            "maxSupply": 0,
            "baseURI": "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/getMetadataKNFT/",
        },
        "addresses": {
            "AUTHORITY_ADDRESS": "0x6A005c11217863c4e300Ce009c5Ddc7e1672150A",
            "ADMIN_ADDRESS": "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2",
            "LEGACY_KNFT_ADDRESS": "0x5aD180dF8619CE4f888190C3a926111a723632ce",
            "TREASURY_ADDRESS": "0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E",
            "FOUNDERSPASS_ADDRESS": "0xD3f011f1768B38CcC0faA7B00E59B0E29920194b",
            "KNDX_ADDRESS": "0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1",
            "PAYMENT_TOKEN_ADDRESS": "0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1",
            "UNISWAP_PAIR_ADDRESS": "0x79dd15aD871b0fE18040a52F951D757Ef88cfe72",
            "UNISWAP_V2_ROUTER_ADDRESS": "0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD",
            "WETH_ADDRESS": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
            "PARTNER_WALLET_ADDRESS": "0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E",
            "HELIX_ADDRESS": None,
        },
        "options": {
            "createPairIfMissing": False,
            "batchRoleRecipients": ["0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2"],
            "konduxRoleRecipients": ["0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2"],
            "revokeDeployerAdmin": True,
            "enableFreeMinting": False,
        },
    },
    "sepolia": {
        "label": "Ethereum Sepolia",
        "kondux": {
            "name": "Kondux kNFT (Sepolia)",
            "symbol": "kNFTs",
            "maxSupply": 0,
            "baseURI": "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/getMetadataKNFT/",
        },
        "addresses": {
            "AUTHORITY_ADDRESS": "0xfF0b8218353F088173779B0079263F672Aa3B548",
            "ADMIN_ADDRESS": "0x9767a2B120614F526e923DAAF89843EC7C2292d7",
            "LEGACY_KNFT_ADDRESS": None,
            "TREASURY_ADDRESS": "0xD5A6Af8F9C20CAF7872611D6773152AA50180F83",
            "FOUNDERSPASS_ADDRESS": "0x434Fd7feeC752C4Bfa4A59D0272c503FFd313499",
            "KNDX_ADDRESS": "0x2fA9e338cFe579fF4575BeD2E1ea407e811F35Bc",
            "PAYMENT_TOKEN_ADDRESS": "0x2fA9e338cFe579fF4575BeD2E1ea407e811F35Bc",
            "UNISWAP_PAIR_ADDRESS": None,
            "UNISWAP_V2_ROUTER_ADDRESS": "0xC532a74256D3Db42D0Bf7a0400fEFDbad7694008",
            "WETH_ADDRESS": "0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9",
            "PARTNER_WALLET_ADDRESS": "0xD5A6Af8F9C20CAF7872611D6773152AA50180F83",
            "HELIX_ADDRESS": "0xb94F89750D9889656a6d081A0f06CBD3fA3Ad04b",
        },
        "options": {
            "createPairIfMissing": True,
            "batchRoleRecipients": ["0x9767a2B120614F526e923DAAF89843EC7C2292d7"],
            "konduxRoleRecipients": ["0x9767a2B120614F526e923DAAF89843EC7C2292d7"],
            "revokeDeployerAdmin": False,
            "enableFreeMinting": False,
        },
    },
    "hardhat": {
        "label": "Hardhat (Mainnet Fork)",
        "kondux": {
            "name": "Kondux kNFT",
            "symbol": "kNFT",
            "maxSupply": 0,
            "baseURI": "https://h7af1y611a.execute-api.us-east-1.amazonaws.com/getMetadataKNFT/",
        },
        "addresses": {
            "AUTHORITY_ADDRESS": "0x6A005c11217863c4e300Ce009c5Ddc7e1672150A",
            "ADMIN_ADDRESS": "0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2",
            "LEGACY_KNFT_ADDRESS": "0x5aD180dF8619CE4f888190C3a926111a723632ce",
            "TREASURY_ADDRESS": "0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E",
            "FOUNDERSPASS_ADDRESS": "0xD3f011f1768B38CcC0faA7B00E59B0E29920194b",
            "KNDX_ADDRESS": "0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1",
            "PAYMENT_TOKEN_ADDRESS": "0x7CA5af5bA3472AF6049F63c1AbC324475D44EFC1",
            "UNISWAP_PAIR_ADDRESS": "0x79dd15aD871b0fE18040a52F951D757Ef88cfe72",
            "UNISWAP_V2_ROUTER_ADDRESS": "0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD",
            "WETH_ADDRESS": "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
            "PARTNER_WALLET_ADDRESS": "0xaD2E62E90C63D5c2b905C3F709cC3045AecDAa1E",
            "HELIX_ADDRESS": None,
        },
        "options": {
            "createPairIfMissing": False,
            "batchRoleRecipients": ["0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2"],
            "konduxRoleRecipients": ["0x41BC231d1e2eB583C24cee022A6CBCE5168c9FD2"],
            "revokeDeployerAdmin": False,
            "enableFreeMinting": False,
        },
    },
}


def _empty_address_book() -> Dict[str, Any]:
    return {
        "schema": "kondux-batchminter-address-book",
        "networks": {"mainnet": [], "sepolia": [], "hardhat": []},
    }


def _normalise_entry(entry: Any) -> Dict[str, Any]:
    result: Dict[str, Any]
    if isinstance(entry, dict):
        result = {str(k): v for k, v in entry.items()}
    elif isinstance(entry, str):
        try:
            parsed = json.loads(entry)
        except json.JSONDecodeError:
            result = {"raw": entry}
        else:
            if isinstance(parsed, dict):
                result = {str(k): v for k, v in parsed.items()}
            else:
                result = {"raw": entry}
    else:
        result = {"raw": entry}

    verification = result.get("verification")
    if not isinstance(verification, dict):
        verification = {}
    verification.setdefault("status", "unverified")
    verification.setdefault("components", {})
    result["verification"] = verification

    return result


def _normalise_address_book(raw: Dict[str, Any]) -> Dict[str, Any]:
    schema = cast(str, raw.get("schema", "kondux-batchminter-address-book"))
    networks: Dict[str, List[Dict[str, Any]]] = {}

    raw_networks = raw.get("networks")
    if isinstance(raw_networks, dict):
        for name, entries in raw_networks.items():
            normalised: List[Dict[str, Any]] = []
            if isinstance(entries, list):
                normalised = [_normalise_entry(item) for item in entries]
            elif entries is not None:
                normalised = [_normalise_entry(entries)]
            networks[name] = normalised

    for key, value in raw.items():
        if not key.startswith("networks.") or not key.endswith("[]"):
            continue
        name = key[len("networks.") : -2]
        items: List[Any]
        if isinstance(value, list):
            items = value
        else:
            items = [value]
        normalised = networks.setdefault(name, [])
        normalised.extend(_normalise_entry(item) for item in items)

    for name in ("mainnet", "sepolia", "hardhat"):
        networks.setdefault(name, [])

    return {"schema": schema, "networks": networks}


def load_address_book_data(create_if_missing: bool = True) -> Dict[str, Any]:
    if not ADDRESS_BOOK_PATH.exists():
        if not create_if_missing:
            raise SystemExit("Address book file not found. Run a deployment first.")
        return _empty_address_book()

    try:
        raw = json.loads(ADDRESS_BOOK_PATH.read_text())
    except json.JSONDecodeError as exc:
        raise SystemExit(f"address-book.json is not valid JSON: {exc}") from exc

    if not isinstance(raw, dict):
        raise SystemExit("address-book.json must contain a JSON object at the root")

    return _normalise_address_book(raw)


def save_address_book_data(data: Dict[str, Any]) -> None:
    normalised = _normalise_address_book(data)
    ADDRESS_BOOK_PATH.write_text(json.dumps(normalised, indent=2, sort_keys=True) + "\n")


def update_latest_entry(network: str, mutator: Callable[[Dict[str, Any]], None]) -> None:
    data = load_address_book_data(create_if_missing=False)
    networks = cast(Dict[str, List[Dict[str, Any]]], data.get("networks", {}))
    entries = networks.get(network, [])
    if not entries:
        raise SystemExit(f"No entries found in address book for network '{network}'")
    mutator(entries[-1])
    save_address_book_data(data)


def _truncate(text: str, limit: int = 2000) -> str:
    if len(text) <= limit:
        return text
    return text[: limit - 3] + "..."


def _mask_secrets(value: str, replacements: Mapping[str, str]) -> str:
    masked = value
    for secret, placeholder in replacements.items():
        if secret:
            masked = masked.replace(secret, placeholder)
    return masked


def _format_command(parts: Sequence[str], replacements: Mapping[str, str]) -> str:
    return " ".join(shlex.quote(_mask_secrets(part, replacements)) for part in parts)


@dataclass
class VerificationResult:
    component: str
    label: str
    success: bool
    command: str
    output: str
    address: str


def load_env_from_file(path: Path = ENV_PATH) -> Dict[str, str]:
    """Parse a dotenv-style file into a dictionary."""
    values: Dict[str, str] = {}
    if not path.exists():
        return values

    for raw_line in path.read_text().splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export ") :].strip()
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip("'\"")
        values[key] = value
    return values


def merge_env(overrides: Dict[str, str]) -> Dict[str, str]:
    env = os.environ.copy()
    for key, value in overrides.items():
        if key not in env:
            env[key] = value
    return env


def _update_env_file_value(key: str, value: str, path: Path = ENV_PATH) -> None:
    if not path.exists():
        return
    lines = path.read_text().splitlines()
    updated_lines: List[str] = []
    changed = False
    for original in lines:
        line = original
        prefix = ""
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            updated_lines.append(original)
            continue
        if stripped.startswith("export "):
            prefix = "export "
            stripped = stripped[len("export ") :].strip()
        if "=" not in stripped:
            updated_lines.append(original)
            continue
        name, current_value = stripped.split("=", 1)
        name = name.strip()
        if name != key:
            updated_lines.append(original)
            continue
        candidate = f"{prefix}{key}={value}"
        if candidate != original:
            changed = True
            updated_lines.append(candidate)
        else:
            updated_lines.append(original)
    if changed:
        path.write_text("\n".join(updated_lines) + "\n")


def _canonicalise_private_key(raw: str, key_name: str) -> str:
    trimmed = raw.strip()
    if not trimmed:
        raise ValueError("value is empty")

    if trimmed.lower().startswith("0x"):
        hex_part = trimmed[2:]
    else:
        hex_part = trimmed

    hex_part = hex_part.strip()
    if not hex_part:
        raise ValueError("value is empty after removing 0x prefix")

    if any(ch not in string.hexdigits for ch in hex_part):
        raise ValueError("must contain only hex characters (0-9, a-f)")

    if len(hex_part) != 64:
        raise ValueError(f"must be 64 hex characters (found {len(hex_part)})")

    return "0x" + hex_part.lower()


def ensure_private_key_prefix(env: Dict[str, str], key: str) -> None:
    value = env.get(key)
    if not value:
        return
    try:
        normalised = _canonicalise_private_key(value, key)
    except ValueError as err:
        raise SystemExit(f"Invalid {key}: {err}") from err
    env[key] = normalised
    os.environ[key] = normalised
    _update_env_file_value(key, normalised)
    hex_part = normalised[2:]
    preview = f"0x{hex_part[:4]}...{hex_part[-4:]}"
    print(f"{key} normalised -> {preview} ({len(hex_part)} hex chars)")


def _maybe_resolve(path_str: str) -> Optional[str]:
    expanded = Path(path_str).expanduser()
    if expanded.exists():
        return str(expanded)
    if os.name == "nt" and not expanded.suffix:
        for suffix in (".exe", ".cmd", ".bat"):
            candidate = expanded.with_suffix(suffix)
            if candidate.exists():
                return str(candidate)
    return None


@dataclass
class ToolSpec:
    prefix: Sequence[str]
    executable: str
    join_args: bool = False

    def build(self, args: Sequence[str]) -> List[str]:
        if self.join_args:
            command_str = shlex.join([self.executable, *args])
            return [*self.prefix, command_str]
        return [*self.prefix, self.executable, *args]


def _search_native_binary(candidate: Optional[str], fallback: str) -> Optional[str]:
    search_terms: List[str] = []
    if candidate:
        search_terms.append(candidate)
    search_terms.append(fallback)

    for term in search_terms:
        resolved = shutil.which(term)
        if resolved:
            return resolved
        if Path(term).is_absolute() or term.startswith("."):
            found = _maybe_resolve(term)
            if found:
                return found

    default_dirs: List[Path] = []
    home = Path.home()
    default_dirs.append(home / ".foundry" / "bin")
    default_dirs.append(home / "AppData" / "Local" / "foundry" / "bin")
    default_dirs.append(home / ".cargo" / "bin")

    suffixes = [""]
    if os.name == "nt":
        suffixes = [".exe", ".cmd", ".bat", ""]

    for directory in default_dirs:
        for suffix in suffixes:
            candidate_path = directory / f"{fallback}{suffix}"
            if candidate_path.exists():
                return str(candidate_path)

    return None


def _search_wsl_binary(name: str) -> Optional[ToolSpec]:
    wsl = shutil.which("wsl")
    if not wsl:
        return None
    try:
        result = subprocess.run(
            [wsl, "bash", "-lc", f"command -v {shlex.quote(name)}"],
            check=False,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError:
        return None
    if result.returncode != 0:
        return None
    return ToolSpec(prefix=[wsl, "bash", "-lc"], executable=name, join_args=True)


def resolve_tool(candidate: Optional[str], fallback: str) -> ToolSpec:
    native = _search_native_binary(candidate, fallback)
    if native:
        return ToolSpec(prefix=[], executable=native)

    wsl_spec = _search_wsl_binary(fallback)
    if wsl_spec:
        return wsl_spec

    msg = (
        f"Required binary '{fallback}' is not available on PATH. "
        f"Set the {fallback.upper()}_BIN environment variable to the executable path or install it."
    )
    raise SystemExit(msg)


def print_network_defaults(network: str) -> None:
    data = NETWORK_DEFAULTS.get(network)
    if not data:
        print(f"\nNo default configuration recorded for network '{network}'")
        return

    print(f"\nDefault configuration for {network} ({data['label']}):")
    kondux = cast(Dict[str, object], data.get("kondux", {}))
    if kondux:
        print("  Kondux settings:")
        for key, value in kondux.items():
            print(f"    {key}: {value}")

    addresses = cast(Dict[str, Optional[str]], data.get("addresses", {}))
    if addresses:
        print("  Addresses:")
        for key, value in addresses.items():
            print(f"    {key}: {value}")

    options = cast(Dict[str, object], data.get("options", {}))
    if options:
        print("  Options:")
        for key, value in options.items():
            print(f"    {key}: {value}")


def resolve_alchemy_rpc(network: str, env: Dict[str, str]) -> Tuple[str, str]:
    mapping = ALCHEMY_ENDPOINTS.get(network)
    if not mapping:
        raise ValueError(f"No Alchemy endpoint mapping for network '{network}'")
    keys, template = mapping
    for candidate in keys:
        value = env.get(candidate) or os.environ.get(candidate)
        if value:
            return template.format(key=value), candidate
    raise SystemExit(
        f"Missing Alchemy API key for {network}. Define one of {', '.join(keys)} in the environment or .env"
    )


def build_forge_command(
    forge_tool: ToolSpec,
    rpc_url: str,
    broadcast: bool,
    slow: bool,
    dry_run: bool,
    extra: Optional[List[str]] = None,
) -> List[str]:
    args: List[str] = [
        "script",
        SCRIPT_TARGET,
        "--rpc-url",
        rpc_url,
        "--ffi",
    ]
    if broadcast:
        args.append("--broadcast")
    if dry_run:
        args.append("--dry-run")
    if slow:
        args.append("--slow")
    if extra:
        args.extend(extra)
    return forge_tool.build(args)


def run_subprocess(cmd: List[str], env: Dict[str, str], cwd: Path = ROOT) -> None:
    printable = " ".join(shlex.quote(part) for part in cmd)
    print(f"\n> {printable}\n")
    subprocess.run(cmd, check=True, env=env, cwd=cwd)


def load_address_book() -> Dict[str, List[Dict[str, Any]]]:
    data = load_address_book_data(create_if_missing=False)
    return cast(Dict[str, List[Dict[str, Any]]], data.get("networks", {}))


def latest_entry(network: str) -> Optional[Dict[str, Any]]:
    networks = load_address_book()
    entries = networks.get(network, [])
    if not entries:
        return None
    return entries[-1]


def print_entry(entry: Dict[str, str], label: str) -> None:
    print(f"\nLatest {label} entry:")
    for key, value in entry.items():
        print(f"  {key}: {value}")


def encode_constructor_args(kondux: str, authority: str) -> str:
    def normalise(addr: str) -> str:
        if not addr.startswith("0x"):
            raise ValueError(f"Address {addr} must start with 0x")
        return addr[2:].lower().rjust(64, "0")

    return "0x" + normalise(kondux) + normalise(authority)


def command_deploy(args: argparse.Namespace) -> None:
    forge_tool = resolve_tool(FORGE_BIN_OVERRIDE, "forge")
    env = merge_env(load_env_from_file())
    env.setdefault("FOUNDRY_FFI", "1")
    env["VERIFY"] = "0" if args.skip_verify else "1"

    ensure_private_key_prefix(env, "DEPLOYER_PK")
    ensure_private_key_prefix(env, "PROD_DEPLOYER_PK")

    if args.show_defaults:
        print_network_defaults(args.network)

    if args.rpc_url:
        rpc_url = args.rpc_url
        rpc_hint = "custom"
    else:
        rpc_url, rpc_hint = resolve_alchemy_rpc(args.network, env)
    print(f"Resolved RPC provider ({args.network}): {rpc_hint} -> {rpc_url}")

    broadcast = not args.dry_run and not args.no_broadcast
    cmd = build_forge_command(
        forge_tool=forge_tool,
        rpc_url=rpc_url,
        broadcast=broadcast,
        slow=args.slow,
        dry_run=args.dry_run,
    )
    run_subprocess(cmd, env)

    entry = latest_entry(args.network)
    if entry:
        print_entry(entry, args.network)


def command_smoke(args: argparse.Namespace) -> None:
    forge_tool = resolve_tool(FORGE_BIN_OVERRIDE, "forge")
    anvil_tool = resolve_tool(ANVIL_BIN_OVERRIDE, "anvil")
    env = merge_env(load_env_from_file())
    env.setdefault("FOUNDRY_FFI", "1")
    env["VERIFY"] = "0" if args.skip_verify else "1"

    ensure_private_key_prefix(env, "PROD_DEPLOYER_PK")
    ensure_private_key_prefix(env, "DEPLOYER_PK")

    if args.show_defaults:
        print_network_defaults("hardhat")

    rpc_url, rpc_hint = resolve_alchemy_rpc("mainnet", env)
    print(f"Starting anvil fork from {rpc_hint} -> {rpc_url}")

    anvil_args: List[str] = [
        "--fork-url",
        rpc_url,
        "--port",
        str(args.port),
    ]
    if args.block_number is not None:
        anvil_args.extend(["--fork-block-number", str(args.block_number)])
    if args.anvil_args:
        anvil_args.extend(args.anvil_args)

    anvil_cmd = anvil_tool.build(anvil_args)

    anvil_proc = subprocess.Popen(anvil_cmd, cwd=ROOT)
    try:
        time.sleep(args.startup_delay)
        forge_cmd = build_forge_command(
            forge_tool=forge_tool,
            rpc_url=f"http://127.0.0.1:{args.port}",
            broadcast=True,
            slow=args.slow,
            dry_run=False,
        )
        run_subprocess(forge_cmd, env)
    finally:
        anvil_proc.terminate()
        try:
            anvil_proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            anvil_proc.kill()

    entry = latest_entry("hardhat")
    if entry:
        print_entry(entry, "hardhat fork")


def command_verify(args: argparse.Namespace) -> None:
    forge_tool = resolve_tool(FORGE_BIN_OVERRIDE, "forge")
    env = merge_env(load_env_from_file())
    etherscan_key = env.get("ETHERSCAN_API_KEY") or os.environ.get("ETHERSCAN_API_KEY")
    if not etherscan_key:
        raise SystemExit("ETHERSCAN_API_KEY is required for verification")

    secret_replacements = {etherscan_key: "$ETHERSCAN_API_KEY"}

    if args.show_defaults:
        print_network_defaults(args.network)

    entry = latest_entry(args.network)
    if not entry:
        raise SystemExit(f"No entries found in address book for network '{args.network}'")

    chain_id = entry.get("chainId")
    if isinstance(chain_id, str):
        chain_id = int(chain_id)
    if chain_id not in CHAIN_ID_TO_NETWORK:
        raise SystemExit(f"Unsupported chain id in address book entry: {chain_id}")

    kondux_proxy_opt = entry.get("konduxImplementationProxy")
    kondux_logic_opt = entry.get("konduxImplementationLogic")
    batch_minter_opt = entry.get("konduxBatchMinter")
    authority_opt = entry.get("authority")
    if not all([kondux_proxy_opt, kondux_logic_opt, batch_minter_opt, authority_opt]):
        raise SystemExit("Address book entry missing required fields for verification")

    kondux_proxy = cast(str, kondux_proxy_opt)
    kondux_logic = cast(str, kondux_logic_opt)
    batch_minter = cast(str, batch_minter_opt)
    authority = cast(str, authority_opt)

    constructor_args = encode_constructor_args(kondux_proxy, authority)
    verifications = [
        (
            "konduxImplementationLogic",
            "Kondux implementation (logic)",
            kondux_logic,
            forge_tool.build(
                [
                    "verify-contract",
                    "--chain-id",
                    str(chain_id),
                    "--num-of-optimizations",
                    "800",
                    "--etherscan-api-key",
                    etherscan_key,
                    kondux_logic,
                    "contracts/KonduxImplementation.sol:KonduxImplementation",
                ]
            ),
        ),
        (
            "konduxBatchMinter",
            "Kondux batch minter",
            batch_minter,
            forge_tool.build(
                [
                    "verify-contract",
                    "--chain-id",
                    str(chain_id),
                    "--num-of-optimizations",
                    "800",
                    "--constructor-args",
                    constructor_args,
                    "--etherscan-api-key",
                    etherscan_key,
                    batch_minter,
                    "contracts/KonduxBatchMinter.sol:KonduxBatchMinter",
                ]
            ),
        ),
    ]

    results: List[VerificationResult] = []
    for component, label, target_address, cmd in verifications:
        printable = _format_command(cmd, secret_replacements)
        print(f"\n> {printable} (API key masked)\n")
        try:
            completed = subprocess.run(
                cmd,
                env=env,
                cwd=ROOT,
                text=True,
                capture_output=True,
                check=False,
            )
        except FileNotFoundError as exc:
            output = f"forge binary not found: {exc}"
            print(output)
            results.append(
                VerificationResult(
                    component=component,
                    label=label,
                    success=False,
                    command=printable,
                    output=output,
                    address=target_address,
                )
            )
            continue

        success = completed.returncode == 0
        output_lines = completed.stdout if success else completed.stderr or completed.stdout
        output = (output_lines or "").strip()
        if output:
            print(output)
        if not success:
            print(f"Verification failed for {label} (exit code {completed.returncode})")

        results.append(
            VerificationResult(
                component=component,
                label=label,
                success=success,
                command=printable,
                output=_truncate(output or "(no output)"),
                address=target_address,
            )
        )

    proxy_note = (
        "forge verify-proxy is not available in current Foundry builds. "
        f"Verify proxy {kondux_proxy} -> {kondux_logic} manually via Etherscan's "
        "proxy verification workflow after the logic contract is published."
    )
    print(f"\n{proxy_note}\n")
    results.append(
        VerificationResult(
            component="konduxImplementationProxy",
            label="Kondux implementation proxy (manual step)",
            success=True,
            command=proxy_note,
            output=proxy_note,
            address=kondux_proxy,
        )
    )

    status = "success" if all(result.success for result in results) else "failed"

    def _apply_verification(entry: Dict[str, Any]) -> None:
        verification = cast(Dict[str, Any], entry.setdefault("verification", {}))
        components = cast(Dict[str, Any], verification.setdefault("components", {}))
        timestamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        verification["status"] = status
        verification["lastRun"] = timestamp
        verification["tool"] = "forge verify-contract"
        verification["chainId"] = chain_id
        for result in results:
            components[result.component] = {
                "status": "success" if result.success else "failed",
                "label": result.label,
                "command": result.command,
                "output": result.output,
                "address": result.address,
                "updatedAt": timestamp,
            }

    update_latest_entry(args.network, _apply_verification)
    print(f"Verification state recorded in {ADDRESS_BOOK_PATH}")

    if status != "success":
        raise SystemExit(1)

    print("Verification commands completed")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Manage Kondux batch minter deployments")
    sub = parser.add_subparsers(dest="command", required=True)

    deploy = sub.add_parser("deploy", help="Broadcast a deployment to a live network")
    deploy.add_argument("--network", choices=["mainnet", "sepolia"], required=True)
    deploy.add_argument("--rpc-url", help="Override the RPC endpoint (defaults to Alchemy)")
    deploy.add_argument("--skip-verify", action="store_true", help="Do not auto-run verification after deployment")
    deploy.add_argument("--dry-run", action="store_true", help="Use forge --dry-run and skip broadcasting")
    deploy.add_argument("--no-broadcast", action="store_true", help="Skip --broadcast even without --dry-run")
    deploy.add_argument("--slow", action="store_true", help="Pass --slow to forge script")
    deploy.add_argument("--show-defaults", action="store_true", help="Print the default network addresses and options")
    deploy.set_defaults(func=command_deploy)

    smoke = sub.add_parser("smoke", help="Run a smoke deployment against a local anvil fork")
    smoke.add_argument("--port", type=int, default=8545, help="Anvil listen port")
    smoke.add_argument(
        "--block-number",
        type=int,
        help="Optional block number to fork from",
    )
    smoke.add_argument("--skip-verify", action="store_true", help="Skip verification during smoke tests")
    smoke.add_argument("--slow", action="store_true", help="Pass --slow to forge script")
    smoke.add_argument(
        "--startup-delay",
        type=float,
        default=2.5,
        help="Seconds to wait for anvil to boot before running forge",
    )
    smoke.add_argument("--show-defaults", action="store_true", help="Print the default hardhat fork configuration")
    smoke.add_argument(
        "--anvil-args",
        nargs=argparse.REMAINDER,
        help="Additional arguments forwarded to anvil (must come last)",
    )
    smoke.set_defaults(func=command_smoke)

    verify = sub.add_parser("verify", help="Re-run Etherscan verification using the latest address book entry")
    verify.add_argument("--network", choices=["mainnet", "sepolia"], required=True)
    verify.add_argument("--show-defaults", action="store_true", help="Print the default network addresses and options")
    verify.set_defaults(func=command_verify)

    return parser


def main(argv: Optional[List[str]] = None) -> None:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        args.func(args)
    except subprocess.CalledProcessError as exc:
        raise SystemExit(exc.returncode) from exc


if __name__ == "__main__":
    main()
