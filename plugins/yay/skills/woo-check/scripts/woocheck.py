#!/usr/bin/env python3
"""woocheck.py: the /yay:woo-check rows that don't come from a tool, and the rows that do.

Every command prints or rewrites findings.tsv rows:
    result <TAB> id <TAB> file <TAB> line <TAB> code <TAB> message
result is FAIL, WARN, SKIP, INFO or BASE; file is relative to the plugin folder
(or the lock file's name for the audits); line is 0 for a whole file.

  scan <dir> [--requires-wc X] [--tested-wc Y] [--wc-latest Z] [--lib a/,b/]   MAL1-MAL4, VAL1-VAL5

--lib adds library folders (the repo's generatedPaths, such as vendor-prefixed/) to vendor/ and
node_modules/: PHPCS and PHPStan rows there are dropped, MAL1 there is a WARN.
  convert <phpcs-sec|phpcs-cmp|phpstan|composer|npm|pnpm|gitleaks> <json> --root <dir> [--lib a/,b/]
  constants <dir> [--lib a/,b/]                                    a PHP stub defining every constant the plugin define()s
  baseline <findings.tsv> <baseline.tsv> [--update]                 mark BASE rows, list GONE rows
  areas <findings.tsv>                                              area status fail warn base skip

IDs and severities: references/checklist.md.
"""
import argparse
import hashlib
import json
import os
import re
import sys

LIB_DIRS = ("vendor", "node_modules")
LIB_PATHS = []  # --lib: folders relative to the plugin root
NEVER_BASELINED = ("SEC5", "MAL2")
AREAS = ("SEC", "MAL", "STAN", "CMP", "VAL")


def row(result, rid, path, line, code, message):
    clean = re.sub(r"\s+", " ", str(message)).strip()
    return "\t".join([result, rid, path, str(line), code, clean])


def in_lib(rel):
    parts = rel.split("/")
    return any(p in LIB_DIRS for p in parts) or any(rel.startswith(l) for l in LIB_PATHS)


def set_libs(arg):
    LIB_PATHS[:] = [l.strip().strip("/") + "/" for l in (arg or "").split(",") if l.strip().strip("/")]


def rel_to(root, path):
    root = os.path.realpath(root)
    path = os.path.realpath(path)
    rel = os.path.relpath(path, root)
    return rel.replace(os.sep, "/")


# --- PHP source with strings and comments blanked -----------------------------------------

def php_code_only(src):
    """Return src with HTML, comments and string contents replaced by spaces (newlines kept),
    so a regex on the result only sees PHP code. Backticks outside strings stay."""
    out = []
    i, n = 0, len(src)
    in_php = False

    def blank(s):
        return re.sub(r"[^\n]", " ", s)

    while i < n:
        if not in_php:
            j = src.find("<?", i)
            if j < 0:
                out.append(blank(src[i:]))
                break
            out.append(blank(src[i:j]))
            m = re.match(r"<\?(php|=)?", src[j:])
            out.append(" " * len(m.group(0)))
            i = j + len(m.group(0))
            in_php = True
            continue
        c = src[i]
        two = src[i:i + 2]
        if two == "?>":
            out.append("  ")
            i += 2
            in_php = False
        elif two == "/*":
            j = src.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append(blank(src[i:j]))
            i = j
        elif two == "//" or (c == "#" and src[i + 1:i + 2] != "["):
            j = i
            while j < n and src[j] != "\n" and src[j:j + 2] != "?>":
                j += 1
            out.append(blank(src[i:j]))
            i = j
        elif c in ("'", '"'):
            j = i + 1
            while j < n and src[j] != c:
                j += 2 if src[j] == "\\" else 1
            j = min(j + 1, n)
            out.append(c + blank(src[i + 1:j - 1]) + c)
            i = j
        elif src.startswith("<<<", i):
            m = re.match(r"<<<[ \t]*(['\"]?)([A-Za-z_]\w*)\1[^\n]*\n", src[i:])
            if not m:
                out.append(c)
                i += 1
                continue
            end = re.compile(r"^[ \t]*" + re.escape(m.group(2)) + r"\b", re.M)
            e = end.search(src, i + m.end())
            j = n if not e else e.end()
            out.append(blank(src[i:j]))
            i = j
        else:
            out.append(c)
            i += 1
    return "".join(out)


DANGEROUS = re.compile(
    r"(?<![\w$>:\\])(?<!function )\b(eval|create_function|system|exec|shell_exec|passthru|proc_open|popen)\s*\(")
ASSERT_STRING = re.compile(r"(?<![\w$>:])\bassert\s*\(\s*['\"]")
DECODERS = r"(?:base64_decode|gzinflate|gzuncompress|gzdecode|str_rot13|strrev|hex2bin)"
EVAL_DECODED = re.compile(r"\b(?:eval|assert)\s*\(\s*" + DECODERS + r"\s*\(")
DECODE_CHAIN = re.compile(r"\b" + DECODERS + r"\s*\(\s*" + DECODERS + r"\s*\(")
PREG_E = re.compile(r"\bpreg_replace\s*\(\s*(['\"])([^\w\s\\])(?:(?!\2).)*\2[imsxuADSUXJ]*e[imsxuADSUXJ]*\1")
LONG_B64 = re.compile(r"['\"][A-Za-z0-9+/]{200,}={0,2}['\"]")
NON_PRINTABLE = re.compile("[\x00-\x08\x0b\x0c\x0e-\x1f\x7f​-‏‪-‮⁦-⁩﻿]")
DISGUISE_EXT = (".jpg", ".jpeg", ".png", ".gif", ".ico", ".bmp", ".webp", ".svg", ".txt", ".css", ".log")
ALLOW = re.compile(r"woo-check:allow\s+([A-Z]+\d+(?:\s*,\s*[A-Z]+\d+)*)")


def allowed(lines, idx, rid):
    for k in (idx, idx - 1):
        if 0 <= k < len(lines):
            m = ALLOW.search(lines[k])
            if m and rid in re.split(r"\s*,\s*", m.group(1)):
                return True
    return False


def scan_php(rel, src, rows):
    raw = src.split("\n")
    code = php_code_only(src).split("\n")
    lib = in_lib(rel)
    for i, line in enumerate(code):
        hits = []
        if EVAL_DECODED.search(line) or DECODE_CHAIN.search(line):
            hits.append(("FAIL", "MAL2", "obfuscation", "decoded string run or decoders chained: " + raw[i].strip()[:120]))
        else:
            for m in DANGEROUS.finditer(line):
                hits.append(("WARN" if lib else "FAIL", "MAL1", "dangerous_function", m.group(1) + "() call"))
            if ASSERT_STRING.search(line):
                hits.append(("WARN" if lib else "FAIL", "MAL1", "dangerous_function", "assert() on a string"))
            if "`" in line:
                hits.append(("WARN" if lib else "FAIL", "MAL1", "dangerous_function", "backtick shell execution"))
        if PREG_E.search(raw[i]):
            hits.append(("FAIL", "MAL2", "obfuscation", "preg_replace() with the /e modifier"))
        if LONG_B64.search(raw[i]):
            hits.append(("FAIL", "MAL2", "obfuscation", "base64 string of 200+ characters"))
        if NON_PRINTABLE.search(raw[i]) and not (i == 0 and raw[i].startswith("﻿") and not NON_PRINTABLE.search(raw[i][1:])):
            hits.append(("WARN", "MAL4", "non_printable", "non-printable character in PHP source"))
        for res, rid, chk, msg in hits:
            if not allowed(raw, i, rid):
                rows.append(row(res, rid, rel, i + 1, chk, msg))


def read_headers(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        head = fh.read(8192)
    found = {}
    for key in ("Plugin Name", "WC requires at least", "WC tested up to"):
        m = re.search(r"^[ \t/*#@]*" + re.escape(key) + r":(.*)$", head, re.M | re.I)
        if m:
            found[key] = m.group(1).strip()
    return found


def vkey(v):
    return tuple(int(x) for x in re.findall(r"\d+", v or "")[:2]) or (0,)


def scan(args):
    root = args.dir
    rows = []
    php_files = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        for d in dirnames:
            if d.startswith("."):
                rows.append(row("WARN", "MAL3", rel_to(root, os.path.join(dirpath, d)) + "/", 0, "hidden_file", "hidden folder in the zip"))
        for f in sorted(filenames):
            full = os.path.join(dirpath, f)
            rel = rel_to(root, full)
            if f.startswith("."):
                rows.append(row("WARN", "MAL3", rel, 0, "hidden_file", "hidden file in the zip"))
            low = f.lower()
            if low.endswith(".php"):
                php_files.append(rel)
                with open(full, encoding="utf-8", errors="replace") as fh:
                    scan_php(rel, fh.read(), rows)
            elif low.endswith(DISGUISE_EXT):
                with open(full, "rb") as fh:
                    if b"<?php" in fh.read(1 << 20):
                        rows.append(row("WARN", "MAL3", rel, 0, "disguised_php", "PHP code in a ." + low.rsplit(".", 1)[1] + " file"))

    main = None
    for rel in php_files:
        if "/" not in rel and "Plugin Name" in read_headers(os.path.join(root, rel)):
            main = rel
            break
    if not main:
        rows.append(row("FAIL", "VAL1", "-", 0, "wc_headers", "no main plugin file with a Plugin Name header at the top of the zip"))
    else:
        h = read_headers(os.path.join(root, main))
        for key, cfg, flag in (("WC requires at least", args.requires_wc, "requires.wc"), ("WC tested up to", args.tested_wc, "tested.wc")):
            if key not in h:
                rows.append(row("FAIL", "VAL1", main, 0, "wc_headers", "missing header: " + key))
            elif cfg and vkey(cfg) != vkey(h[key]):
                rows.append(row("WARN", "VAL2", main, 0, "wc_headers_config", "%s is %s, %s is %s" % (key, h[key], flag, cfg)))
        tested = h.get("WC tested up to")
        if not args.wc_latest:
            rows.append(row("SKIP", "VAL5", main, 0, "wc_tested_latest", "newest WooCommerce release unknown (offline)"))
        elif tested and vkey(tested) < vkey(args.wc_latest):
            rows.append(row("WARN", "VAL5", main, 0, "wc_tested_latest", "WC tested up to %s, newest WooCommerce is %s" % (tested, args.wc_latest)))

    own = [r for r in php_files if not in_lib(r)]
    texts = {}
    for rel in own:
        with open(os.path.join(root, rel), encoding="utf-8", errors="replace") as fh:
            texts[rel] = fh.read()
    has_hook = any("before_woocommerce_init" in t for t in texts.values())
    for feature, rid, check, missing in (("custom_order_tables", "VAL3", "declare_hpos", "FAIL"),
                                         ("cart_checkout_blocks", "VAL4", "declare_blocks", "WARN")):
        pat = re.compile(r"declare_compatibility\s*\(\s*['\"]" + feature + r"['\"]\s*,[^,)]*(?:,\s*(\w+))?")
        hit = None
        for rel, t in texts.items():
            m = pat.search(t)
            if m:
                hit = (rel, t.count("\n", 0, m.start()) + 1, (m.group(1) or "true").lower())
                break
        where = main or "-"
        if not hit:
            rows.append(row(missing, rid, where, 0, check, "no declare_compatibility( '%s' ) found" % feature))
        elif hit[2] == "false":
            rows.append(row("WARN", rid, hit[0], hit[1], check, "declared incompatible with %s" % feature))
        elif not has_hook:
            rows.append(row("WARN", rid, hit[0], hit[1], check, "declared outside a before_woocommerce_init callback"))

    print("\n".join(rows))


# --- tool JSON -> rows -----------------------------------------------------------------------

def convert(args):
    with open(args.json, encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    # Some tools print notices before the JSON; start at the first brace or bracket.
    start = min([i for i in (text.find("{"), text.find("[")) if i >= 0] or [0])
    data = json.loads(text[start:] or "null")
    root = args.root
    rows = []
    t = args.tool
    if isinstance(data, dict) and data.get("error") and t in ("composer", "npm"):
        err = data["error"]
        msg = err.get("summary") or err.get("code") if isinstance(err, dict) else err
        rid = "SEC3" if t == "composer" else "SEC4"
        print(row("SKIP", rid, "composer.lock" if t == "composer" else "package-lock.json", 0, t + "-audit", "audit didn't run: %s" % msg))
        return
    if t in ("phpcs-sec", "phpcs-cmp"):
        for path, f in sorted(((data or {}).get("files") or {}).items()):
            rel = rel_to(root, path)
            if in_lib(rel):
                continue
            for m in f.get("messages", []):
                src = m.get("source", "")
                if t == "phpcs-sec":
                    rid = "SEC1" if src.startswith("WordPress.Security") else "SEC2" if src.startswith("WordPress.DB") else None
                else:
                    rid = "CMP1" if src.startswith("PHPCompatibility") else None
                if rid:
                    rows.append(row("FAIL" if m.get("type") == "ERROR" else "WARN", rid, rel, m.get("line", 0), src, m.get("message", "")))
    elif t == "phpstan":
        seen = set()
        for path, f in sorted(((data or {}).get("files") or {}).items()):
            # A trait's errors come once per class that uses it: "Trait.php (in context of class X)".
            rel = rel_to(root, re.sub(r" \(in context of .*\)$", "", path))
            if in_lib(rel):
                continue
            for m in f.get("messages", []):
                k = (rel, m.get("line"), m.get("message"))
                if k not in seen:
                    seen.add(k)
                    rows.append(row("FAIL", "STAN1", rel, m.get("line") or 0, m.get("identifier") or "phpstan", m.get("message", "")))
        for msg in (data or {}).get("errors") or []:
            rows.append(row("FAIL", "STAN1", "-", 0, "phpstan.general", msg))
    elif t == "composer":
        for pkg, advs in sorted(((data or {}).get("advisories") or {}).items()):
            for a in advs if isinstance(advs, list) else advs.values():
                sev = (a.get("severity") or "").lower()
                rows.append(row("FAIL" if sev in ("high", "critical") else "WARN", "SEC3", "composer.lock", 0, pkg,
                                "%s (%s, affects %s) %s" % (a.get("title", ""), sev or "severity unknown", a.get("affectedVersions", "?"), a.get("cve") or a.get("link") or "")))
    elif t == "npm":
        for name, v in sorted(((data or {}).get("vulnerabilities") or {}).items()):
            sev = (v.get("severity") or "").lower()
            titles = sorted({x.get("title", "") for x in v.get("via", []) if isinstance(x, dict)})
            via = ", ".join(t for t in titles if t) or "through " + ", ".join(x for x in v.get("via", []) if isinstance(x, str))
            rows.append(row("FAIL" if sev in ("high", "critical") else "WARN", "SEC4", "package-lock.json", 0, name,
                            "%s (%s, range %s)%s" % (via, sev, v.get("range", "?"), "" if v.get("fixAvailable") else ", no fix available")))
    elif t == "pnpm":
        for _, a in sorted(((data or {}).get("advisories") or {}).items(), key=lambda kv: str(kv[1].get("module_name", ""))):
            sev = (a.get("severity") or "").lower()
            rows.append(row("FAIL" if sev in ("high", "critical") else "WARN", "SEC4", "pnpm-lock.yaml", 0, a.get("module_name", "?"),
                            "%s (%s, affects %s, patched %s) %s" % (a.get("title", ""), sev, a.get("vulnerable_versions", "?"), a.get("patched_versions", "?"), a.get("url", ""))))
    elif t == "gitleaks":
        for f in data or []:
            rel = rel_to(root, f.get("File", "-"))
            # Never print the secret itself.
            rows.append(row("FAIL", "SEC5", rel, f.get("StartLine", 0), f.get("RuleID", "gitleaks"), f.get("Description", "possible secret")))
    else:
        sys.exit("woocheck.py: unknown tool " + t)
    print("\n".join(rows))


def constants(args):
    """PHPStan doesn't see a constant the plugin defines inside if ( ! defined() ), so every
    define() name in the plugin's own code goes into a stub it scans (typed by dynamicConstantNames)."""
    names = set()
    pat = re.compile(r"\bdefine\s*\(\s*['\"]([A-Za-z_][A-Za-z0-9_]*)['\"]")
    for dirpath, dirnames, filenames in os.walk(args.dir):
        for f in filenames:
            full = os.path.join(dirpath, f)
            if f.lower().endswith(".php") and not in_lib(rel_to(args.dir, full)):
                with open(full, encoding="utf-8", errors="replace") as fh:
                    names.update(pat.findall(fh.read()))
    print("<?php")
    for n in sorted(names):
        print("define( '%s', '' );" % n)


# --- baseline and areas ----------------------------------------------------------------------

def read_rows(path):
    out = []
    if os.path.exists(path):
        with open(path, encoding="utf-8") as fh:
            for ln in fh:
                ln = ln.rstrip("\n")
                if ln and not ln.startswith("#"):
                    parts = ln.split("\t")
                    out.append(parts + [""] * (6 - len(parts)))
    return out


def bkey(rid, path, code, message):
    h = hashlib.sha256(re.sub(r"\d+", "N", message).encode("utf-8")).hexdigest()[:16]
    return (rid, path, code, h)


def baseline(args):
    rows = read_rows(args.findings)
    base = {}
    for b in read_rows(args.baseline):
        base[tuple(b[:4])] = b[4]
    seen = set()
    out = []
    for r in rows:
        if r[0] in ("FAIL", "WARN", "BASE"):
            k = bkey(r[1], r[2], r[4], r[5])
            seen.add(k)
            if r[0] != "BASE" and k in base and r[1] not in NEVER_BASELINED:
                r = ["BASE"] + r[1:]
        out.append(r)
    with open(args.findings, "w", encoding="utf-8") as fh:
        fh.write("".join("\t".join(r[:6]) + "\n" for r in out))
    for k in sorted(set(base) - seen):
        print("\t".join(("GONE",) + k[:3] + (base[k],)))
    if args.update:
        keep = {}
        for r in out:
            if r[0] in ("FAIL", "WARN", "BASE") and r[1] not in NEVER_BASELINED:
                keep[bkey(r[1], r[2], r[4], r[5])] = r[5]
        with open(args.baseline, "w", encoding="utf-8") as fh:
            fh.write("# /yay:woo-check baseline: findings accepted when it was written. id file code hash message\n")
            fh.write("# SEC5 and MAL2 are never written here. Rewrite with /yay:woo-check --update-baseline.\n")
            for k in sorted(keep):
                fh.write("\t".join(k + (keep[k],)) + "\n")
        skipped = sorted({r[1] for r in out if r[0] in ("FAIL", "WARN") and r[1] in NEVER_BASELINED})
        for rid in skipped:
            print("KEPT\t%s\tnever baselined: fix it, or allow it next to the line" % rid)


def areas(args):
    rows = read_rows(args.findings)
    for a in AREAS:
        mine = [r for r in rows if re.match(a + r"\d", r[1])]
        n = {k: sum(1 for r in mine if r[0] == k) for k in ("FAIL", "WARN", "BASE", "SKIP", "INFO")}
        if n["FAIL"]:
            status = "Failed"
        elif n["WARN"]:
            status = "Warning"
        elif n["INFO"]:
            status = "Success"
        else:
            status = "Skipped"
        print("\t".join([a, status, str(n["FAIL"]), str(n["WARN"]), str(n["BASE"]), str(n["SKIP"])]))


def main():
    p = argparse.ArgumentParser(prog="woocheck.py")
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("scan")
    s.add_argument("dir")
    s.add_argument("--requires-wc", default="")
    s.add_argument("--tested-wc", default="")
    s.add_argument("--wc-latest", default="")
    s.add_argument("--lib", default="")
    k = sub.add_parser("constants")
    k.add_argument("dir")
    k.add_argument("--lib", default="")
    c = sub.add_parser("convert")
    c.add_argument("tool")
    c.add_argument("json")
    c.add_argument("--root", required=True)
    c.add_argument("--lib", default="")
    b = sub.add_parser("baseline")
    b.add_argument("findings")
    b.add_argument("baseline")
    b.add_argument("--update", action="store_true")
    a = sub.add_parser("areas")
    a.add_argument("findings")
    args = p.parse_args()
    set_libs(getattr(args, "lib", ""))
    {"scan": scan, "convert": convert, "constants": constants, "baseline": baseline, "areas": areas}[args.cmd](args)


if __name__ == "__main__":
    main()
