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
import subprocess
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple, cast

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_TARGET = "script/DeployKonduxBatchMinter.s.sol:DeployKonduxBatchMinterScript"
ADDRESS_BOOK_PATH = ROOT / "docs" / "deployments" / "kondux-batchminter" / "address-book.json"
ENV_PATH = ROOT / ".env"
FORGE_BIN = os.environ.get("FORGE_BIN", "forge")
ANVIL_BIN = os.environ.get("ANVIL_BIN", "anvil")

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


def ensure_binary(name: str) -> None:
    if shutil.which(name) is None:
        raise SystemExit(f"Required binary '{name}' is not available on PATH")


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
    rpc_url: str,
    broadcast: bool,
    slow: bool,
    dry_run: bool,
    extra: Optional[List[str]] = None,
) -> List[str]:
    cmd = [
        FORGE_BIN,
        "script",
        SCRIPT_TARGET,
        "--rpc-url",
        rpc_url,
        "--ffi",
    ]
    if broadcast:
        cmd.append("--broadcast")
    if dry_run:
        cmd.append("--dry-run")
    if slow:
        cmd.append("--slow")
    if extra:
        cmd.extend(extra)
    return cmd


def run_subprocess(cmd: List[str], env: Dict[str, str], cwd: Path = ROOT) -> None:
    printable = " ".join(shlex.quote(part) for part in cmd)
    print(f"\n> {printable}\n")
    subprocess.run(cmd, check=True, env=env, cwd=cwd)


def load_address_book() -> Dict[str, List[Dict[str, str]]]:
    if not ADDRESS_BOOK_PATH.exists():
        raise SystemExit("Address book file not found. Run a deployment first.")
    data = json.loads(ADDRESS_BOOK_PATH.read_text())
    return data.get("networks", {})


def latest_entry(network: str) -> Optional[Dict[str, str]]:
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
    ensure_binary(FORGE_BIN)
    env = merge_env(load_env_from_file())
    env.setdefault("FOUNDRY_FFI", "1")
    env["VERIFY"] = "0" if args.skip_verify else "1"

    if args.rpc_url:
        rpc_url = args.rpc_url
        rpc_hint = "custom"
    else:
        rpc_url, rpc_hint = resolve_alchemy_rpc(args.network, env)
    print(f"Resolved RPC provider ({args.network}): {rpc_hint}")

    broadcast = not args.dry_run and not args.no_broadcast
    cmd = build_forge_command(
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
    ensure_binary(FORGE_BIN)
    ensure_binary(ANVIL_BIN)
    env = merge_env(load_env_from_file())
    env.setdefault("FOUNDRY_FFI", "1")
    env["VERIFY"] = "0" if args.skip_verify else "1"

    rpc_url, rpc_hint = resolve_alchemy_rpc("mainnet", env)
    print(f"Starting anvil fork from {rpc_hint}")

    anvil_cmd = [
        ANVIL_BIN,
        "--fork-url",
        rpc_url,
        "--port",
        str(args.port),
    ]
    if args.block_number is not None:
        anvil_cmd.extend(["--fork-block-number", str(args.block_number)])
    if args.anvil_args:
        anvil_cmd.extend(args.anvil_args)

    anvil_proc = subprocess.Popen(anvil_cmd, cwd=ROOT)
    try:
        time.sleep(args.startup_delay)
        forge_cmd = build_forge_command(
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
    ensure_binary(FORGE_BIN)
    env = merge_env(load_env_from_file())
    etherscan_key = env.get("ETHERSCAN_API_KEY") or os.environ.get("ETHERSCAN_API_KEY")
    if not etherscan_key:
        raise SystemExit("ETHERSCAN_API_KEY is required for verification")

    entry = latest_entry(args.network)
    if not entry:
        raise SystemExit(f"No entries found in address book for network '{args.network}'")

    chain_id = entry.get("chainId")
    if isinstance(chain_id, str):
        chain_id = int(chain_id)
    if chain_id not in CHAIN_ID_TO_NETWORK:
        raise SystemExit(f"Unsupported chain id in address book entry: {chain_id}")

    kondux_opt = entry.get("konduxImplementation")
    batch_minter_opt = entry.get("konduxBatchMinter")
    authority_opt = entry.get("authority")
    if not all([kondux_opt, batch_minter_opt, authority_opt]):
        raise SystemExit("Address book entry missing required fields for verification")

    kondux = cast(str, kondux_opt)
    batch_minter = cast(str, batch_minter_opt)
    authority = cast(str, authority_opt)

    constructor_args = encode_constructor_args(kondux, authority)
    commands = [
        [
            FORGE_BIN,
            "verify-contract",
            "--chain-id",
            str(chain_id),
            "--num-of-optimizations",
            "800",
            kondux,
            "contracts/KonduxImplementation.sol:KonduxImplementation",
            etherscan_key,
        ],
        [
            FORGE_BIN,
            "verify-contract",
            "--chain-id",
            str(chain_id),
            "--num-of-optimizations",
            "800",
            "--constructor-args",
            constructor_args,
            batch_minter,
            "contracts/KonduxBatchMinter.sol:KonduxBatchMinter",
            etherscan_key,
        ],
    ]

    for cmd in commands:
        run_subprocess(cmd, env)

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
    smoke.add_argument(
        "--anvil-args",
        nargs=argparse.REMAINDER,
        help="Additional arguments forwarded to anvil (must come last)",
    )
    smoke.set_defaults(func=command_smoke)

    verify = sub.add_parser("verify", help="Re-run Etherscan verification using the latest address book entry")
    verify.add_argument("--network", choices=["mainnet", "sepolia"], required=True)
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
