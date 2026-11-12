# shellcheck shell=bash
# yayh asset: screenshots kept with an artifact, under docs/assets/<ID>/.
# See reference/artifacts.md (Screenshots).
#
# A screenshot belongs to one artifact id. `yayh artifact carry` takes an artifact's
# untracked screenshots into the worktree with it, and `yayh artifact archive`
# removes them with it.

YAY_ASSET_EXTS='png jpg jpeg gif webp'

yay_asset_dir() { printf 'docs/assets/%s\n' "$1"; }

_yay_asset_id_ok() {
  printf '%s' "$1" | grep -Eq '^(BS|BL|UX|P|B|R)-[0-9]+$' || yay_die "'$1' is not an artifact id (R-n, BS-n, P-n, B-n, UX-n, BL-n)"
}

# yay_asset_add <ID> <file> [caption] -> added<TAB>docs/assets/<ID>/<n>-<slug>.<ext><TAB>![caption](../assets/<ID>/<name>)
# Copies the file (the original stays where it was). The markdown link works from any
# artifact file under docs/<folder>/, which is where every artifact lives.
yay_asset_add() {
  local id="$1" src="$2" caption="${3:-}" root ext e ok=0 n slug name rel bytes
  _yay_asset_id_ok "$id"
  [ -f "$src" ] || yay_die "no such file: $src (a screenshot pasted into the chat has no file; drag the file into the terminal to get its path)"
  root="$(yay_repo_root)"
  yay_id_find "$id" >/dev/null 2>&1 || yay_die "no artifact $id in docs/ yet: create it first, then add its screenshot"
  ext="$(printf '%s' "${src##*.}" | LC_ALL=C tr '[:upper:]' '[:lower:]')"
  for e in $YAY_ASSET_EXTS; do [ "$ext" = "$e" ] && ok=1; done
  [ "$ok" = 1 ] || yay_die "'$src' is not an image ($YAY_ASSET_EXTS)"
  [ "$ext" = jpeg ] && ext=jpg
  rel="$(yay_asset_dir "$id")"
  mkdir -p "$root/$rel"
  n="$(find "$root/$rel" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')"
  n=$((n + 1))
  slug="$(yay_slugify "${caption:-$(basename "$src" ".${src##*.}")}")"
  [ -n "$slug" ] || slug=screenshot
  name="$n-$slug.$ext"
  while [ -e "$root/$rel/$name" ]; do n=$((n + 1)); name="$n-$slug.$ext"; done
  cp "$src" "$root/$rel/$name"
  bytes="$(wc -c < "$root/$rel/$name" | tr -d ' ')"
  [ "$bytes" -le 2097152 ] || yay_warn "$rel/$name is $((bytes / 1048576)) MB: it is committed with the artifact, so crop or compress it if you can"
  printf 'added\t%s\t![%s](../assets/%s/%s)\n' "$rel/$name" "$(printf '%s' "${caption:-$slug}" | tr -d '[]')" "$id" "$name"
}

# yay_asset_list <ID> -> repo-relative paths of its screenshots, one per line.
yay_asset_list() {
  local id="$1" root rel
  _yay_asset_id_ok "$id"
  root="$(yay_repo_root)"; rel="$(yay_asset_dir "$id")"
  [ -d "$root/$rel" ] || return 0
  (cd "$root" && find "$rel" -maxdepth 1 -type f | sort)
}

# yay_asset_move <old ID> <new ID>: when an artifact is renumbered, its screenshots
# follow (git mv for tracked files). The links in the artifact body are fixed by hand.
yay_asset_move() {
  local old="$1" new="$2" root from to f
  _yay_asset_id_ok "$old"; _yay_asset_id_ok "$new"
  root="$(yay_repo_root)"; from="$(yay_asset_dir "$old")"; to="$(yay_asset_dir "$new")"
  [ -d "$root/$from" ] || { printf 'none\t%s\n' "$from"; return 0; }
  [ ! -e "$root/$to" ] || yay_die "$to already exists"
  mkdir -p "$root/$to"
  for f in "$root/$from"/*; do
    [ -f "$f" ] || continue
    if git -C "$root" ls-files --error-unmatch -- "$from/${f##*/}" >/dev/null 2>&1; then
      git -C "$root" mv -- "$from/${f##*/}" "$to/${f##*/}"
    else
      mv "$f" "$root/$to/${f##*/}"
    fi
  done
  rmdir "$root/$from" 2>/dev/null || true
  printf 'moved\t%s\t%s\n' "$from" "$to"
}
