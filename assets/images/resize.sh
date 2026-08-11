#!/bin/bash
# Resize images for LinkedIn article share or article section use.
#
# Usage:
#   ./resize.sh cover  <input> <output>   # 1200x627 LinkedIn article share
#   ./resize.sh section <input> <output>  # 900x300 article section image

MODE="${1:?Usage: $0 <cover|section> <input> <output>}"
INPUT="${2:?Usage: $0 <cover|section> <input> <output>}"
OUTPUT="${3:?Usage: $0 <cover|section> <input> <output>}"

case "$MODE" in
  cover)
    # Scale content to 85% width so logos stay clear of LinkedIn's crop.
    convert "$INPUT" \
      -resize 1020x \
      -background black \
      -gravity center \
      -extent 1200x627 \
      "$OUTPUT"
    ;;
  section)
    # Downscale to fit within 900x300, preserving aspect ratio, no crop.
    convert "$INPUT" \
      -resize 900x300 \
      -background black \
      -gravity center \
      -extent 900x300 \
      "$OUTPUT"
    ;;
  *)
    echo "Unknown mode: $MODE. Use 'cover' or 'section'."
    exit 1
    ;;
esac

identify "$OUTPUT"
