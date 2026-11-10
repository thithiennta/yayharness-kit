# shellcheck shell=bash
# Shared helpers for the yay kit. Bash 3.2 compatible (macOS default):
# no associative arrays, no ${var,,}, no mapfile.

YAY_LIB_DIR="${YAY_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
YAY_KIT_ROOT="${YAY_KIT_ROOT:-$(cd "$YAY_LIB_DIR/.." && pwd)}"

yay_die()  { printf 'yayh: %s\n' "$*" >&2; exit 1; }
yay_warn() { printf 'yayh: %s\n' "$*" >&2; }

# Kit version from the plugin manifest.
yay_kit_version() {
  sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
    "$YAY_KIT_ROOT/.claude-plugin/plugin.json" | sed -n 1p
}

# Root of the plugin repo being worked on. Honours YAY_REPO for tests and
# for running from outside the repo.
yay_repo_root() {
  if [ -n "${YAY_REPO:-}" ]; then printf '%s\n' "$YAY_REPO"; return; fi
  git rev-parse --show-toplevel 2>/dev/null || yay_die "not inside a git repo (set YAY_REPO)"
}

# Lowercase, non-alphanumerics to '-', trimmed, max 50 chars, no trailing '-'.
yay_slugify() {
  local s
  s="$(printf '%s' "$*" \
    | LC_ALL=C tr '[:upper:]' '[:lower:]' \
    | LC_ALL=C sed -e 's/[^a-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//' \
    | cut -c1-50 \
    | sed -e 's/-$//')"
  printf '%s\n' "$s"
}

yay_today() { date +%Y-%m-%d; }

# yay_in_list <item> <newline-separated list>: exact line match, no pipe.
# (`producer | grep -q` can fail under pipefail when grep exits early and the
# producer gets SIGPIPE, so match against a variable instead.)
yay_in_list() {
  local item="$1" line
  while IFS= read -r line; do [ "$line" = "$item" ] && return 0; done <<EOF
$2
EOF
  return 1
}

# sha256 of stdin, portable across macOS (shasum) and Linux (sha256sum).
yay_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | cut -d' ' -f1
  else shasum -a 256 | cut -d' ' -f1; fi
}

# Pick a JSON engine once: jq > node > php > python3.
yay_json_engine() {
  if [ -n "${YAY_JSON_ENGINE:-}" ]; then printf '%s\n' "$YAY_JSON_ENGINE"; return; fi
  for e in jq node php python3; do
    if command -v "$e" >/dev/null 2>&1; then printf '%s\n' "$e"; return; fi
  done
  yay_die "need one of jq, node, php or python3 to read JSON"
}

# yay_json_get <file> <dotted.path>
# Prints a scalar as text, an array one item per line (objects inside as JSON),
# an object as compact JSON. Exit 3 when the path is missing or null.
yay_json_get() {
  local file="$1" path="$2" engine
  [ -f "$file" ] || return 3
  engine="$(yay_json_engine)"
  case "$engine" in
    jq)
      jq -r --arg p "$path" '
        ($p | split(".")) as $keys
        | (try getpath($keys) catch null) as $v
        | if $v == null then error("missing")
          elif ($v | type) == "array" then $v[] | (if type == "string" then . else tojson end)
          elif ($v | type) == "object" then $v | tojson
          else $v end
      ' "$file" 2>/dev/null || return 3
      ;;
    node)
      node -e '
        const fs=require("fs");let v;try{v=JSON.parse(fs.readFileSync(process.argv[1],"utf8"))}catch(e){process.exit(3)}
        for (const k of process.argv[2].split(".")) { if (v===null||typeof v!=="object"||!(k in v)) process.exit(3); v=v[k]; }
        if (v===null) process.exit(3);
        const out=x=>typeof x==="string"?x:JSON.stringify(x);
        if (Array.isArray(v)) v.forEach(x=>console.log(out(x))); else console.log(out(v));
      ' "$file" "$path"
      ;;
    php)
      php -r '
        $v=json_decode(file_get_contents($argv[1]),true); if($v===null) exit(3);
        foreach(explode(".",$argv[2]) as $k){ if(!is_array($v)||!array_key_exists($k,$v)) exit(3); $v=$v[$k]; }
        if($v===null) exit(3);
        $o=function($x){ return is_string($x)?$x:(is_bool($x)?($x?"true":"false"):json_encode($x,JSON_UNESCAPED_SLASHES)); };
        if(is_array($v) && ($v===[] || array_keys($v)===range(0,count($v)-1))){ foreach($v as $x) echo $o($x),"\n"; }
        else echo $o($v),"\n";
      ' "$file" "$path"
      ;;
    python3)
      python3 -I -c '
import json,sys
try: v=json.load(open(sys.argv[1]))
except Exception: sys.exit(3)
for k in sys.argv[2].split("."):
    if not isinstance(v,dict) or k not in v: sys.exit(3)
    v=v[k]
if v is None: sys.exit(3)
o=lambda x: x if isinstance(x,str) else json.dumps(x,separators=(",",":"))
if isinstance(v,list): [print(o(x)) for x in v]
elif isinstance(v,bool): print("true" if v else "false")
else: print(o(v))
' "$file" "$path"
      ;;
  esac
}
