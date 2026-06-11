#!/usr/bin/env bash
set -euo pipefail

workflow="${WORKFLOW:-.github/workflows/build.yml}"
output_dir="${1:-out/firmware/latest}"

repo="${GH_REPO:-}"
if [[ -z "$repo" ]]; then
  repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
fi

run_info="$(
  gh run list \
    --repo "$repo" \
    --workflow "$workflow" \
    --limit 1 \
    --json databaseId,status,conclusion \
    --jq '.[0] // empty | [.databaseId, .status, (.conclusion // "")] | @tsv'
)"

if [[ -z "$run_info" ]]; then
  echo "status=not_found"
  exit 0
fi

IFS=$'\t' read -r run_id status conclusion <<< "$run_info"
conclusion="${conclusion:-none}"

echo "run_id=$run_id"
echo "status=$status"
echo "conclusion=$conclusion"

if [[ "$status" != "completed" || "$conclusion" != "success" ]]; then
  exit 0
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

gh run download "$run_id" --repo "$repo" --dir "$tmp_dir" >/dev/null

firmware_list="$tmp_dir/firmware-files.txt"
find "$tmp_dir" -type f \( -name '*.uf2' -o -name '*.bin' -o -name '*.hex' \) -print0 > "$firmware_list"

if [[ ! -s "$firmware_list" ]]; then
  exit 0
fi

rm -rf "$output_dir"
mkdir -p "$output_dir"

while IFS= read -r -d '' firmware_file; do
  cp "$firmware_file" "$output_dir/"
done < "$firmware_list"

find "$output_dir" -type f | sort
