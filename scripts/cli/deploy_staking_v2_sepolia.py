#!/usr/bin/env python3
"""Helper to run the Sepolia StakingV2 deployment with environment validation."""

from __future__ import annotations

import argparse
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
ENV_PATH = REPO_ROOT / ".env"

FORGE_TARGET = "script/DeployStakingV2SepoliaImport.s.sol:DeployStakingV2SepoliaImportScript"

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


def load_env_file(path: Path) -> None:
    if not path.exists():
        return

    def sanitize(value: str) -> str:
        value = value.strip()
        if value and ((value[0] == value[-1]) and value[0] in {'"', "'"}):
            return value[1:-1]
        return value

    with path.open(encoding="utf-8") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" not in line:
                continue
            key, value = line.split("=", 1)
            key = key.strip()
            value = sanitize(value)
            os.environ.setdefault(key, value)


def require_env(key: str) -> str:
    value = os.environ.get(key)
    if not value:
        raise SystemExit(f"Missing required environment variable: {key}")
    return value


def resolve_rpc_url(env_key: str, network: str) -> tuple[str, str]:
    existing = os.environ.get(env_key)
    if existing:
        return existing, f"env:{env_key}"

    mapping = ALCHEMY_ENDPOINTS.get(network)
    if not mapping:
        raise SystemExit(f"No RPC mapping configured for network '{network}'")

    keys, template = mapping
    for key in keys:
        api_key = os.environ.get(key)
        if api_key:
            rpc_url = template.format(key=api_key)
            os.environ[env_key] = rpc_url
            return rpc_url, f"alchemy:{key}"

    joined_keys = ", ".join(keys)
    raise SystemExit(
        f"Missing RPC configuration. Provide {env_key} or define one of {joined_keys} for Alchemy"
    )


def mask(value: str) -> str:
    if len(value) <= 8:
        return value
    return f"{value[:4]}...{value[-4:]}"


def run_forge(command_args: list[str]) -> None:
    result = subprocess.run(command_args, env=os.environ.copy())
    if result.returncode != 0:
        raise SystemExit(result.returncode)


def in_virtualenv() -> bool:
    virtual_env = os.environ.get("VIRTUAL_ENV")
    if virtual_env:
        return True
    return sys.prefix != getattr(sys, "base_prefix", sys.prefix)


def print_venv_tip() -> None:
    if in_virtualenv():
        return
    print(
        "Tip: create a virtual environment for Python tooling:\n"
        "  python -m venv .venv\n"
        "  .\\.venv\\Scripts\\activate\n",
        file=sys.stderr,
    )


def build_forge_command(args: list[str]) -> tuple[list[str], str]:
    path = shutil.which("forge")
    if path:
        return [path, *args], path

    search_dirs = []
    foundry_home = os.environ.get("FOUNDRY_HOME")
    if foundry_home:
        search_dirs.append(Path(foundry_home) / "bin")
    search_dirs.append(Path.home() / ".foundry" / "bin")

    for directory in search_dirs:
        for extension in ("", ".exe", ".cmd", ".bat"):
            candidate = directory / f"forge{extension}"
            if candidate.exists():
                os.environ["PATH"] = f"{directory}{os.pathsep}" + os.environ.get("PATH", "")
                return [str(candidate), *args], str(candidate)

    wsl_path = shutil.which("wsl")
    if wsl_path:
        forge_command = "forge " + " ".join(shlex.quote(argument) for argument in args)
        wrapper = [wsl_path, "bash", "-lc", forge_command]
        return wrapper, f"{wsl_path} bash -lc {forge_command}"

    raise SystemExit(
        "forge executable not found. Install Foundry (https://book.getfoundry.sh/getting-started/installation) "
        "and ensure its bin directory is on PATH. On Windows you can install via PowerShell: "
        "PowerShell -NoLogo -ExecutionPolicy Bypass -Command \"Invoke-WebRequest -Uri https://raw.githubusercontent.com/foundry-rs/foundry/master/foundryup/foundryup.ps1 -UseBasicParsing | Invoke-Expression\""
    )


def main(argv: list[str]) -> None:
    load_env_file(ENV_PATH)

    parser = argparse.ArgumentParser(description="Deploy StakingV2 to Sepolia with import")
    parser.add_argument(
        "--smoke",
        action="store_true",
        help="Run a dry-run that does not broadcast transactions",
    )
    parser.add_argument(
        "--limit",
        type=int,
        help="Limit the number of legacy deposits fetched for debugging",
    )
    args, extra = parser.parse_known_args(argv[1:])

    sepolia_rpc, sepolia_source = resolve_rpc_url("SEPOLIA_RPC_URL", "sepolia")
    mainnet_rpc, mainnet_source = resolve_rpc_url("MAINNET_RPC_URL", "mainnet")
    deployer_pk = require_env("DEPLOYER_PK")
    etherscan_key = require_env("ETHERSCAN_API_KEY")

    print("Environment summary:")
    print(f"  SEPOLIA_RPC_URL -> {mask(sepolia_rpc)} ({sepolia_source})")
    print(f"  MAINNET_RPC_URL -> {mask(mainnet_rpc)} ({mainnet_source})")
    print(f"  DEPLOYER_PK -> {mask(deployer_pk)}")
    print(f"  ETHERSCAN_API_KEY -> {mask(etherscan_key)}")
    if args.limit is not None:
        if args.limit <= 0:
            raise SystemExit("--limit must be a positive integer")
        os.environ["STAKING_IMPORT_LIMIT"] = str(args.limit)
        print(f"  STAKING_IMPORT_LIMIT -> {args.limit} (via --limit)")

    print_venv_tip()

    forge_arguments = [
        "script",
        FORGE_TARGET,
        "--rpc-url",
        sepolia_rpc,
        "--ffi",
    ]

    if args.smoke:
        print("Smoke run: broadcasting disabled (omit --broadcast)")
    else:
        forge_arguments.append("--broadcast")

    if extra:
        forge_arguments.extend(extra)

    forge_cmd, forge_display = build_forge_command(forge_arguments)
    print(f"Using forge command: {forge_display}")

    print("\nRunning:")
    print("  ", " ".join(forge_cmd))
    run_forge(forge_cmd)


if __name__ == "__main__":
    main(sys.argv)
