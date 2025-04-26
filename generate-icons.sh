#!/bin/bash

# This script generates app icons of various sizes from a base icon file (icon.png)
# Requires ImageMagick installed (convert command)

BASE_ICON=public/icon.png
OUTPUT_DIR=public/icons

mkdir -p $OUTPUT_DIR

sizes=(16 32 48 64 96 128 192 256 384 512)

for size in "${sizes[@]}"
do
  convert $BASE_ICON -resize ${size}x${size} $OUTPUT_DIR/icon-${size}x${size}.png
done

echo "Icons generated in $OUTPUT_DIR"
