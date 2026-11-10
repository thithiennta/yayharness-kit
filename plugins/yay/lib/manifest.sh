# shellcheck shell=bash
# .yay/manifest.json: hashes of what the kit last wrote. See reference/ownership.md.
# Entry keys are repo-relative paths; "<path>#managed" tracks only the
# <!-- yay:managed:start --> … <!-- yay:managed:end --> block of that file.

yay_manifest_file() { printf '%s/.yay/manifest.json\n' "$(yay_repo_root)"; }

# Print the content an entry tracks (whole file or managed block).
yay_manifest_content() {
  local entry="$1" root path
  root="$(yay_repo_root)"
  path="${entry%%#*}"
  [ -f "$root/$path" ] || return 3
  case "$entry" in
    *'#managed')
      awk '/<!-- yay:managed:start/{on=1} on{print} /<!-- yay:managed:end -->/{if(on){found=1; exit}} END{exit found?0:3}' "$root/$path"
      ;;
    *) cat "$root/$path" ;;
  esac
}

yay_manifest_hash() {
  local c
  c="$(yay_manifest_content "$1")" || return 3
  printf '%s' "$c" | yay_sha256
}

# List entries as "<entry>\t<sha>\t<template>".
yay_manifest_entries() {
  local file; file="$(yay_manifest_file)"
  [ -f "$file" ] || return 0
  case "$(yay_json_engine)" in
    jq) jq -r '.files // {} | to_entries[] | [.key, .value.sha256, (.value.template // "")] | @tsv' "$file" ;;
    node) node -e 'const m=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));for(const [k,v] of Object.entries(m.files||{}))console.log([k,v.sha256,v.template||""].join("\t"))' "$file" ;;
    php) php -r '$m=json_decode(file_get_contents($argv[1]),true);foreach(($m["files"]??[]) as $k=>$v) echo $k,"\t",$v["sha256"],"\t",($v["template"]??""),"\n";' "$file" ;;
    python3) python3 -I -c 'import json,sys;m=json.load(open(sys.argv[1]))
for k,v in (m.get("files") or {}).items(): print("\t".join([k,v["sha256"],v.get("template","")]))' "$file" ;;
  esac
}

# yay_manifest_status [entry...]  -> "<status>\t<entry>" for each, where
# status is clean | modified | missing. No args = every entry.
yay_manifest_status() {
  local line entry sha tpl cur
  yay_manifest_entries | while IFS="$(printf '\t')" read -r entry sha tpl; do
    if [ $# -gt 0 ]; then
      case " $* " in *" $entry "*) ;; *) continue;; esac
    fi
    if cur="$(yay_manifest_hash "$entry")"; then
      if [ "$cur" = "$sha" ]; then printf 'clean\t%s\n' "$entry"; else printf 'modified\t%s\n' "$entry"; fi
    else
      printf 'missing\t%s\n' "$entry"
    fi
  done
}

# yay_manifest_record <entry> <template>  -> store the current hash of entry.
yay_manifest_record() {
  local entry="$1" tpl="${2:-}" file sha ver today
  file="$(yay_manifest_file)"
  sha="$(yay_manifest_hash "$entry")" || yay_die "cannot hash $entry (file or managed block missing)"
  ver="$(yay_kit_version)"; today="$(yay_today)"
  mkdir -p "$(dirname "$file")"
  [ -f "$file" ] || printf '{"kitVersion":"%s","updated":"%s","files":{}}\n' "$ver" "$today" > "$file"
  local tmp; tmp="$(mktemp)"
  case "$(yay_json_engine)" in
    jq) jq --arg e "$entry" --arg s "$sha" --arg t "$tpl" --arg v "$ver" --arg d "$today" \
          '.updated=$d | .files[$e]={sha256:$s, template:$t}' "$file" > "$tmp" ;;
    node) node -e 'const fs=require("fs");const [f,e,s,t,v,d]=process.argv.slice(1);const m=JSON.parse(fs.readFileSync(f,"utf8"));m.updated=d;m.files=m.files||{};m.files[e]={sha256:s,template:t};process.stdout.write(JSON.stringify(m,null,2)+"\n")' "$file" "$entry" "$sha" "$tpl" "$ver" "$today" > "$tmp" ;;
    php) php -r '[$_,$f,$e,$s,$t,$v,$d]=$argv;$m=json_decode(file_get_contents($f),true);$m["updated"]=$d;$m["files"]=$m["files"]??[];$m["files"][$e]=["sha256"=>$s,"template"=>$t];echo json_encode($m,JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES),"\n";' "$file" "$entry" "$sha" "$tpl" "$ver" "$today" > "$tmp" ;;
    python3) python3 -I -c 'import json,sys;f,e,s,t,v,d=sys.argv[1:];m=json.load(open(f));m["updated"]=d;m.setdefault("files",{})[e]={"sha256":s,"template":t};print(json.dumps(m,indent=2))' "$file" "$entry" "$sha" "$tpl" "$ver" "$today" > "$tmp" ;;
  esac
  cat "$tmp" > "$file"; rm -f "$tmp"
}

# yay_manifest_stamp: mark the repo as synced to the installed kit version.
# Called by a sync that left nothing unresolved.
yay_manifest_stamp() {
  local file tmp v; file="$(yay_manifest_file)"; [ -f "$file" ] || return 0
  v="$(yay_kit_version)"; tmp="$(mktemp)"
  case "$(yay_json_engine)" in
    jq) jq --arg v "$v" '.kitVersion=$v' "$file" > "$tmp" ;;
    node) node -e 'const fs=require("fs");const m=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));m.kitVersion=process.argv[2];process.stdout.write(JSON.stringify(m,null,2)+"\n")' "$file" "$v" > "$tmp" ;;
    php) php -r '$m=json_decode(file_get_contents($argv[1]),true);$m["kitVersion"]=$argv[2];echo json_encode($m,JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES),"\n";' "$file" "$v" > "$tmp" ;;
    python3) python3 -I -c 'import json,sys;m=json.load(open(sys.argv[1]));m["kitVersion"]=sys.argv[2];print(json.dumps(m,indent=2))' "$file" "$v" > "$tmp" ;;
  esac
  cat "$tmp" > "$file"; rm -f "$tmp"
}

# yay_manifest_forget <entry>
yay_manifest_forget() {
  local file tmp; file="$(yay_manifest_file)"; [ -f "$file" ] || return 0
  tmp="$(mktemp)"
  case "$(yay_json_engine)" in
    jq) jq --arg e "$1" 'del(.files[$e])' "$file" > "$tmp" ;;
    node) node -e 'const fs=require("fs");const m=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));delete (m.files||{})[process.argv[2]];process.stdout.write(JSON.stringify(m,null,2)+"\n")' "$file" "$1" > "$tmp" ;;
    php) php -r '$m=json_decode(file_get_contents($argv[1]),true);unset($m["files"][$argv[2]]);echo json_encode($m,JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES),"\n";' "$file" "$1" > "$tmp" ;;
    python3) python3 -I -c 'import json,sys;m=json.load(open(sys.argv[1]));(m.get("files") or {}).pop(sys.argv[2],None);print(json.dumps(m,indent=2))' "$file" "$1" > "$tmp" ;;
  esac
  cat "$tmp" > "$file"; rm -f "$tmp"
}
