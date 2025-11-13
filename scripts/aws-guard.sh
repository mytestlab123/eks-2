#!/usr/bin/env bash
# Source this to add an `awsg` function that prompts on PROD.
# KISS: minimal checks, clear emojis, no secrets.

awsg() {
  set -euo pipefail
  local prod_acct=${PROD_ACCOUNT:-021577063369}
  local acct
  acct=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo unknown)
  if [[ "$acct" == "$prod_acct" ]]; then
    echo "🛑💀 PROD account ($acct) — confirmation required"
    echo "Command: aws $*"
    read -r -p "Proceed? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; return 1; }
  elif [[ "$acct" == "unknown" ]]; then
    echo "⚠️  Unknown AWS identity — proceed with caution"
    echo "Command: aws $*"
    read -r -p "Proceed? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted."; return 1; }
  fi
  command aws "$@"
}

awsi() { aws sts get-caller-identity --query 'Account,Arn' --output text; }

export -f awsg awsi

