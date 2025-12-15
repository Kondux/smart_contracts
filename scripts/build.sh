#!/bin/bash
export PATH=$PATH:~/.foundry/bin
cd /mnt/d/git/smart_contracts
forge build 2>&1 | tail -15
