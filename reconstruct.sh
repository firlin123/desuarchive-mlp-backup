#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# CONFIG
# ============================================================

# GitHub repo containing the releases
REPO="firlin123/desuarchive-mlp-backup"

# Base URLs
REPO_URL="https://github.com/${REPO}"
MANIFEST_URL="https://raw.githubusercontent.com/${REPO}/main/manifest.json"

# Output file
OUTPUT_FILE="${1:-desuarchive_mlp_full.ndjson}"

# ============================================================
# DEPENDENCY CHECKS
# ============================================================

for cmd in curl jq gzip; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required command '$cmd' not found. Please install it and retry." >&2
    exit 1
  fi
done

# ============================================================
# FETCH MANIFEST
# ============================================================

echo "Downloading manifest from: ${MANIFEST_URL}"
MANIFEST_TMP="$(mktemp)"
trap 'rm -f "$MANIFEST_TMP"' EXIT

if ! curl -fsSL "$MANIFEST_URL" -o "$MANIFEST_TMP"; then
  echo "Failed to download manifest.json from ${MANIFEST_URL}" >&2
  exit 1
fi

echo "Manifest downloaded to: ${MANIFEST_TMP}"

# Basic sanity check
if ! jq -e '.lastDownLoaded' "$MANIFEST_TMP" >/dev/null 2>&1; then
  echo "Downloaded manifest.json does not look valid." >&2
  exit 1
fi

# ============================================================
# PREPARE OUTPUT
# ============================================================

echo "Reconstructing archive into: ${OUTPUT_FILE}"
: >"$OUTPUT_FILE"

# ============================================================
# STEP 1 – YEARLIES
# ============================================================

YEARLY_COUNT="$(jq '.yearly | length' "$MANIFEST_TMP")"
echo "Found ${YEARLY_COUNT} yearly archives in manifest."

if [ "$YEARLY_COUNT" -gt 0 ]; then
  jq -r '.yearly[].url' "$MANIFEST_TMP" | while read -r url; do
    [ -z "$url" ] && continue
    echo "Appending yearly archive from: ${url}"
    # Download and decompress .gz on the fly
    curl -fSL "$url" | gzip -dc >>"$OUTPUT_FILE"
    echo "Done."
  done
else
  echo "No yearly archives listed; skipping yearly step."
fi

# ============================================================
# STEP 2 – MONTHLIES
# ============================================================

MONTHLY_COUNT="$(jq '.monthly | length' "$MANIFEST_TMP")"
echo "Found ${MONTHLY_COUNT} monthly archives in manifest."

if [ "$MONTHLY_COUNT" -gt 0 ]; then
  jq -r '.monthly[]' "$MANIFEST_TMP" | while read -r name; do
    [ -z "$name" ] && continue
    asset="${name}.ndjson.gz"
    url="${REPO_URL}/releases/download/${name}/${asset}"
    echo "Appending monthly ${name} from: ${url}"
    curl -fSL "$url" | gzip -dc >>"$OUTPUT_FILE"
    echo "Done."
  done
else
  echo "No monthly archives listed; skipping monthly step."
fi

# ============================================================
# STEP 3 – DAILIES
# ============================================================

DAILY_COUNT="$(jq '.daily | length' "$MANIFEST_TMP")"
echo "Found ${DAILY_COUNT} daily archives in manifest."

if [ "$DAILY_COUNT" -gt 0 ]; then
  jq -r '.daily[]' "$MANIFEST_TMP" | while read -r name; do
    [ -z "$name" ] && continue
    asset="${name}.ndjson.gz"
    url="${REPO_URL}/releases/download/${name}/${asset}"
    echo "Appending daily ${name} from: ${url}"
    curl -fSL "$url" | gzip -dc >>"$OUTPUT_FILE"
    echo "Done."
  done
else
  echo "No daily archives listed; skipping daily step."
fi

# ============================================================
# DONE
# ============================================================

echo "Reconstruction complete."
echo "Final archive written to: ${OUTPUT_FILE}"