#!/usr/bin/env bash
# Bundle a generated URDF + all referenced meshes into a zip for web URDF viewers.
#
# The zip will contain:
#   <robot>.urdf              (package:// paths replaced with relative ./meshes/...)
#   meshes/**                 (all referenced mesh files from this package)
#
# Usage (run from franka_description root):
#   bash scripts/bundle_web_urdf.sh <urdf_file> [output_zip]
#
# Example:
#   bash scripts/bundle_web_urdf.sh urdfs/mobile_fr3_duo_v0_2_robotiq_2f85_d405.urdf

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: bash $0 <urdf_file> [output.zip]"
  exit 1
fi

URDF_IN="$1"
if [[ ! -f "$URDF_IN" ]]; then
  echo "ERROR: $URDF_IN not found"
  exit 1
fi

BASENAME="$(basename "${URDF_IN%.urdf}")"
ZIP_OUT="${2:-/tmp/${BASENAME}_web.zip}"
STAGING="$(mktemp -d)"

trap "rm -rf '$STAGING'" EXIT

echo "Bundling: $URDF_IN"
echo "Output  : $ZIP_OUT"
echo "Staging : $STAGING"

# -- Replace package://franka_description with ./  in URDF ----------------------
URDF_OUT="$STAGING/${BASENAME}.urdf"
sed 's|package://franka_description/|./|g' "$URDF_IN" > "$URDF_OUT"

# -- Find all referenced mesh paths and copy them --------------------------------
PACKAGE_DIR="$(cd "$(dirname "$0")/.." && pwd)"  # franka_description root

grep -oE 'filename="\./[^"]+' "$URDF_OUT" | sed 's|filename="\./||' | sort -u | while read -r rel; do
  src="$PACKAGE_DIR/$rel"
  dst="$STAGING/$rel"
  if [[ -f "$src" ]]; then
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
  else
    echo "  WARNING: mesh not found: $src"
  fi
done

# -- Count what we found --------------------------------------------------------
MESH_COUNT=$(find "$STAGING" -type f ! -name "*.urdf" | wc -l | tr -d ' ')
echo "Copied $MESH_COUNT mesh files"

# -- Zip it up ------------------------------------------------------------------
rm -f "$ZIP_OUT"
(cd "$STAGING" && zip -r "$ZIP_OUT" .)

echo ""
echo "Done: $ZIP_OUT"
echo "Upload this zip to your web URDF viewer."
