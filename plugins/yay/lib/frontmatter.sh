# shellcheck shell=bash
# Flat front-matter (see reference/artifacts.md): `key: value` lines between
# the first two `---` lines. Lists are inline `[a, b]`.

# yay_fm_get <file> <key>  -> value (raw, trimmed); exit 3 if key absent.
yay_fm_get() {
  local file="$1" key="$2"
  [ -f "$file" ] || return 3
  awk -v k="$key" '
    NR==1 && $0!="---" { exit 3 }
    NR==1 { infm=1; next }
    infm && $0=="---" { exit found?0:3 }
    infm {
      i = index($0, ":"); if (i == 0) next
      if (substr($0, 1, i-1) == k) {
        v = substr($0, i+1); sub(/^[ \t]+/, "", v); sub(/[ \t]+#.*$/, "", v); sub(/[ \t]+$/, "", v)
        print v; found=1; exit 0
      }
    }
    END { if (!found) exit 3 }
  ' "$file"
}

# yay_fm_set <file> <key> <value>  -> replaces the key, or appends it before
# the closing ---. Creates front-matter if the file has none.
yay_fm_set() {
  local file="$1" key="$2" val="$3" tmp
  [ -f "$file" ] || yay_die "no such file: $file"
  case "$val" in *$'\n'*) yay_die "front-matter values must be one line ($key)";; esac
  tmp="$(mktemp)"
  if [ "$(head -1 "$file")" != "---" ]; then
    { printf -- '---\n%s: %s\n---\n' "$key" "$val"; cat "$file"; } > "$tmp"
  else
    awk -v k="$key" -v v="$val" '
      NR==1 { print; infm=1; next }
      infm && $0=="---" { if (!done) print k ": " v; infm=0; print; next }
      infm {
        i = index($0, ":")
        if (i > 0 && substr($0, 1, i-1) == k) { print k ": " v; done=1; next }
      }
      { print }
    ' "$file" > "$tmp"
  fi
  cat "$tmp" > "$file"; rm -f "$tmp"
}

# yay_id_next <PREFIX>  -> e.g. B-8. Scans every .md under docs/ for
# `id: PREFIX-<n>` front-matter and `### PREFIX-<n>` roadmap headings.
yay_id_next() {
  local prefix="$1" root max
  case "$prefix" in R|BS|P|B|BL) ;; *) yay_die "unknown id prefix '$prefix' (R, BS, P, B, BL)";; esac
  root="$(yay_repo_root)/docs"
  max=0
  if [ -d "$root" ]; then
    max="$(find "$root" -type f -name '*.md' -print0 2>/dev/null \
      | { xargs -0 grep -hoE "^(id: |### )${prefix}-[0-9]+" 2>/dev/null || true; } \
      | sed -E "s/.*${prefix}-//" \
      | sort -n | tail -1)"
    max="${max:-0}"
  fi
  # Also count IDs already on the base branch, so two branches started from
  # different points don't hand out the same number.
  local base bmax
  base="$(yay_config_get git.baseBranch 2>/dev/null || true)"
  if [ -n "$base" ] && git -C "$(yay_repo_root)" rev-parse --verify --quiet "$base^{commit}" >/dev/null 2>&1; then
    bmax="$( { git -C "$(yay_repo_root)" grep -h -oE "^(id: |### )${prefix}-[0-9]+" "$base" -- docs/ 2>/dev/null || true; } \
      | sed -E "s/.*${prefix}-//" | sort -n | tail -1)"
    [ -n "$bmax" ] && [ "$bmax" -gt "$max" ] && max="$bmax"
  fi
  printf '%s-%d\n' "$prefix" $((max + 1))
}

# yay_id_find <ID>  -> path(s) of the artifact that declares this id.
yay_id_find() {
  local id="$1" root
  root="$(yay_repo_root)/docs"
  [ -d "$root" ] || return 3
  find "$root" -type f -name '*.md' -print0 \
    | xargs -0 grep -lE "^(id: |### )${id}( |$)" 2>/dev/null \
    || return 3
}
