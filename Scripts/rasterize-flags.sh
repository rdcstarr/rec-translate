#!/usr/bin/env bash
#
# rasterize-flags.sh — convert the source flag SVGs to PNGs that ship as app resources.
# Runs on macOS (called by bundle.sh before `swift build`). macOS has no runtime SVG decoder,
# so we rasterize at build time: rsvg-convert if present (crisper), else Quick Look (qlmanage,
# always available on a macOS runner). sips CANNOT read SVG.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Resources/Flags-src"
OUT="$ROOT/Sources/RecTranslate/Resources/Flags"
WIDTH=64   # ~3x of the 20pt display size; SwiftUI downscales with high interpolation

[ -d "$SRC" ] || { echo "no Flags-src dir; skipping"; exit 0; }
mkdir -p "$OUT"

have_rsvg=0
command -v rsvg-convert >/dev/null 2>&1 && have_rsvg=1

count=0
for svg in "$SRC"/*.svg; do
  [ -e "$svg" ] || continue
  name="$(basename "$svg" .svg)"
  if [ "$have_rsvg" -eq 1 ]; then
    rsvg-convert -w "$WIDTH" "$svg" -o "$OUT/$name.png" 2>/dev/null || true
  else
    qlmanage -t -s "$WIDTH" -o "$OUT" "$svg" >/dev/null 2>&1 || true
    [ -f "$OUT/$name.svg.png" ] && mv -f "$OUT/$name.svg.png" "$OUT/$name.png"
  fi
  [ -f "$OUT/$name.png" ] && count=$((count + 1))
done

echo "==> Rasterized $count flags into $OUT (tool: $([ $have_rsvg -eq 1 ] && echo rsvg-convert || echo qlmanage))"
