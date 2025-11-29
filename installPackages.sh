#!/usr/bin/env bash
set -euo pipefail

packages=("$@")

is_installed() {
  dpkg -s "$1" &>/dev/null
}

missing=()
for pkg in "${packages[@]}"; do
  if ! is_installed "$pkg"; then
    missing+=("$pkg")
  fi
done

if [ ${#missing[@]} -eq 0 ]; then
  echo "All packages are already installed."
  exit 0
fi

echo "Packages to be installed: ${missing[*]}"
echo "Updating apt..."
sudo apt update

echo "Installing missing packages..."
sudo apt install -y "${missing[@]}"

echo "Installation completed."