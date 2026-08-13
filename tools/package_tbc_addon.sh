#!/bin/sh

set -eu

root_dir=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
output_dir=${1:-"$root_dir/build/LoreBuddy"}

rm -rf "$output_dir"
mkdir -p "$output_dir/Core" "$output_dir/Addon"

cp "$root_dir/addon/LoreBuddy_TBC.toc" "$output_dir/LoreBuddy_TBC.toc"
cp "$root_dir"/core/*.lua "$output_dir/Core/"
cp "$root_dir"/addon/*.lua "$output_dir/Addon/"

sed -i '' \
    -e 's#^core/#Core/#' \
    -e 's#^addon/#Addon/#' \
    "$output_dir/LoreBuddy_TBC.toc"

printf 'Packaged TBC addon at %s\n' "$output_dir"
