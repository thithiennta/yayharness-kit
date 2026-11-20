#!/usr/bin/env python3
"""Static pre-review of a WordPress theme against the Theme Directory's required items.

Needs no WordPress install: it reads the files directly. It covers what can be
seen in the files (headers, readme, required files, screenshot size, files the
team refuses, plugin territory, remote resources, classic-theme hooks) and
builds an inventory for the manual pass. Theme Check itself runs on the site
(`yayh wporg theme-site`), not here.

Usage: precheck.py <theme-dir | theme.zip> [--slug SLUG] [--json]

Give it the built zip (or the folder the build produced), not the source repo:
WordPress.org only sees what is uploaded. Every finding carries its ID from
references/checklist.md, so the report and the fix commits use the same names.
"""
import argparse
import json
import os
import re
import shutil
import struct
import sys
import tempfile
import zipfile
from collections import defaultdict

SKIP_DIRS = {"node_modules", "vendor", ".git"}
CODE_EXT = {".php", ".js", ".mjs", ".html", ".css", ".json"}
STYLE_HEADERS = ["Theme Name", "Author", "Description", "Version", "Requires at least", "Tested up to", "Requires PHP", "License", "License URI", "Text Domain"]
README_HEADERS = ["Contributors", "Requires at least", "Tested up to", "Requires PHP", "License", "License URI"]
# Files the Themes Team doesn't allow in the zip (required items, "Files").
BAD_NAMES = {"thumbs.db", "desktop.ini", "project.properties", "project.xml", "php.ini", "dwsync.xml", "error_log", "web.config", "favicon.ico"}
BAD_EXT = {".kpf", ".sql", ".lubith", ".wie", ".dat", ".sh", ".zip", ".gz", ".tgz", ".rar", ".7z", ".phar", ".exe", ".log", ".bak", ".swp"}
XML_OK = {"wpml-config.xml", "loco.xml", "phpcs.xml"}
VCS_DIRS = {".git", ".svn", ".hg", ".bzr", "__MACOSX"}
CORE_LIBS = re.compile(r"(^|/)(jquery(-ui|-migrate)?(\.min)?\.js|backbone(\.min)?\.js|underscore(\.min)?\.js|masonry(\.pkgd)?(\.min)?\.js|imagesloaded(\.pkgd)?(\.min)?\.js|react(-dom)?(\.production)?(\.min)?\.js|lodash(\.min)?\.js|moment(\.min)?\.js)$", re.I)
ALLOWED_REMOTE = ("fonts.googleapis.com", "fonts.gstatic.com")
NAME_WORDS = re.compile(r"\b(wordpress|theme|twenty\w*)\b", re.I)
# Third-party project names reviewers treat like trademarks (Shadcn was flagged for a plugin in 2026).
PROJECT_NAMES = ["shadcn", "tailwind", "bootstrap", "react", "vue", "nextjs", "svelte", "material", "mui", "chakra", "figma", "notion", "shopify", "woocommerce", "woo", "elementor", "gutenberg", "divi", "astra", "kadence", "generatepress", "google", "facebook", "instagram", "openai", "chatgpt"]

PLUGIN_TERRITORY = [
    ("register_post_type", r"\bregister_post_type\s*\("),
    ("register_taxonomy", r"\bregister_taxonomy\s*\("),
    ("add_shortcode", r"\badd_shortcode\s*\("),
    ("register_block_type", r"\bregister_block_type(_from_metadata)?\s*\(|registerBlockType\s*\("),
    ("add_role", r"\badd_role\s*\("),
    ("user_contactmethods", r"['\"]user_contactmethods['\"]"),
    ("upload_mimes", r"['\"]upload_mimes['\"]"),
]
REMOVED_HOOKS = re.compile(r"remove_action\s*\(\s*['\"]wp_head['\"]\s*,\s*['\"](wp_generator|feed_links|feed_links_extra|rsd_link|wlwmanifest_link|rel_canonical|wp_shortlink_wp_head|adjacent_posts_rel_link_wp_head|rest_output_link_wp_head|wp_oembed_add_discovery_links)['\"]")
ADMIN_BAR = re.compile(r"show_admin_bar\s*\(\s*false|['\"]show_admin_bar['\"]\s*,\s*['\"]__return_false")
REDIRECT_ON_ACTIVATE = re.compile(r"after_switch_theme[\s\S]{0,400}?wp_(safe_)?redirect", re.M)
ENQUEUE_REMOTE = re.compile(r"wp_(enqueue|register)_(script|style)\s*\([^;]*?['\"](https?:)?//([^/'\"]+)", re.S)
CSS_IMPORT_REMOTE = re.compile(r"@import\s+(url\()?['\"]?(https?:)?//([^/'\")]+)", re.I)
FONTFACE_REMOTE = re.compile(r"\"src\"\s*:\s*\[?\s*\"(https?:)?//([^/\"]+)")
IMG_REMOTE = re.compile(r"<img[^>]+src=[\\]?['\"](https?:)?//([^/'\"\\]+)|\"url\"\s*:\s*\"(https?:)?//([^/\"]+)", re.I)
CLASSIC_HOOKS = [
    ("wp_head", r"\bwp_head\s*\("), ("wp_footer", r"\bwp_footer\s*\("), ("body_class", r"\bbody_class\s*\("),
    ("wp_body_open", r"\bwp_body_open\s*\("), ("language_attributes", r"\blanguage_attributes\s*\("),
    ("post_class", r"\bpost_class\s*\("), ("wp_link_pages", r"\bwp_link_pages\s*\("),
    ("title-tag", r"add_theme_support\s*\(\s*['\"]title-tag"), ("automatic-feed-links", r"add_theme_support\s*\(\s*['\"]automatic-feed-links"),
]
DEPRECATED_TITLE = re.compile(r"\bwp_title\s*\(")
TEXT_DOMAIN_CALL = re.compile(r"\b(?:__|_e|_x|_ex|_n|_nx|esc_html__|esc_html_e|esc_html_x|esc_attr__|esc_attr_e|esc_attr_x)\s*\((?:[^()]|\([^()]*\))*?,\s*['\"]([a-z0-9_-]+)['\"]\s*\)", re.S)
TGMPA = re.compile(r"class\s+TGM_Plugin_Activation|tgmpa\s*\(", re.I)
PLUGIN_SOURCE = re.compile(r"['\"]source['\"]\s*=>\s*['\"](?!https?://downloads\.wordpress\.org)[^'\"]+\.zip['\"]")


def headers_of(path, names):
    out = {}
    try:
        text = open(path, encoding="utf-8", errors="replace").read(8192)
    except OSError:
        return out
    for n in names:
        m = re.search(r"^[ \t/*#@]*" + re.escape(n) + r":[ \t]*(.+)$", text, re.M | re.I)
        if m:
            out[n] = m.group(1).strip().rstrip("*/").strip()
    return out


def image_size(path):
    """(width, height) of a PNG, JPEG or WebP, or None."""
    try:
        with open(path, "rb") as f:
            head = f.read(32)
            if head[:8] == b"\x89PNG\r\n\x1a\n":
                return struct.unpack(">II", head[16:24])
            if head[:4] == b"RIFF" and head[8:12] == b"WEBP":
                f.seek(12); chunk = f.read(4); f.seek(20); data = f.read(10)
                if chunk == b"VP8X":
                    return (1 + int.from_bytes(data[4:7], "little"), 1 + int.from_bytes(data[7:10], "little"))
                if chunk == b"VP8 ":
                    w, h = struct.unpack("<HH", data[6:10]); return (w & 0x3FFF, h & 0x3FFF)
                if chunk == b"VP8L":
                    b = data[1:5]; v = int.from_bytes(b, "little"); return ((v & 0x3FFF) + 1, ((v >> 14) & 0x3FFF) + 1)
                return None
            if head[:2] == b"\xff\xd8":
                f.seek(2)
                while True:
                    m = f.read(2)
                    if len(m) < 2 or m[0] != 0xFF:
                        return None
                    if m[1] in (0xC0, 0xC1, 0xC2):
                        f.read(3); h, w = struct.unpack(">HH", f.read(4)); return (w, h)
                    f.seek(struct.unpack(">H", f.read(2))[0] - 2, 1)
    except (OSError, struct.error):
        return None
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("theme", help="theme folder or built theme .zip")
    ap.add_argument("--slug")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()

    tmp = None
    src = a.theme
    if src.endswith(".zip"):
        tmp = tempfile.mkdtemp()
        with zipfile.ZipFile(src) as z:
            names = z.namelist()
            z.extractall(tmp)
        tops = sorted({n.split("/")[0] for n in names if n.strip("/")})
        root = os.path.join(tmp, tops[0]) if len(tops) == 1 and os.path.isdir(os.path.join(tmp, tops[0])) else tmp
    else:
        root = src.rstrip("/")
        tops = [os.path.basename(root)]
    folder = os.path.basename(root) if root != tmp else ""
    slug = a.slug or folder

    findings = []  # (severity, id, check, location, message)
    inventory = defaultdict(list)

    def add(sev, cid, check, loc, msg=""):
        findings.append({"severity": sev, "id": cid, "check": check, "where": loc, "message": msg})

    if tmp and (len(tops) != 1 or root == tmp):
        add("error", "X1", "zip_structure", "", "the zip must hold one top folder, the theme slug (got: %s)" % " ".join(tops))

    files = []
    for d, dirs, fs in os.walk(root):
        rel_d = os.path.relpath(d, root)
        for x in list(dirs):
            if x in VCS_DIRS:
                add("error", "X1", "vcs_dir", os.path.normpath(os.path.join(rel_d, x)) + "/", "version-control and archive folders must not ship")
                dirs.remove(x)
            elif x in SKIP_DIRS:
                inventory["skipped_dirs"].append(os.path.normpath(os.path.join(rel_d, x)) + "/")
                dirs.remove(x)
            elif x.startswith("."):
                add("error", "X1", "hidden_file", os.path.normpath(os.path.join(rel_d, x)) + "/", "hidden folders are not allowed")
                dirs.remove(x)
        for f in fs:
            files.append(os.path.normpath(os.path.join(rel_d, f)))

    for rel in files:
        base = os.path.basename(rel).lower()
        ext = os.path.splitext(base)[1]
        if base.startswith("."):
            add("error", "X1", "hidden_file", rel, "hidden files are not allowed")
        elif base in BAD_NAMES or ext in BAD_EXT or (ext == ".xml" and base not in XML_OK):
            add("error", "X1", "disallowed_file", rel, "this file type is not allowed in a theme zip")
        if CORE_LIBS.search(rel):
            add("error", "X4", "bundled_core_library", rel, "use the copy WordPress ships (wp_enqueue_script with its handle)")
        if re.search(r"\.min\.(js|css)$", base):
            plain = re.sub(r"\.min\.(js|css)$", r".\1", rel)
            if plain not in files and not any(f.startswith(("src/", "source/", "assets/src/")) for f in files):
                add("warning", "X3", "minified_without_source", rel, "ship the unminified original in the theme too")

    # style.css headers
    style = os.path.join(root, "style.css")
    sh = headers_of(style, STYLE_HEADERS + ["Theme URI", "Author URI", "Tags", "Template"])
    if not os.path.isfile(style):
        add("error", "X7", "missing_style_css", "style.css", "a theme needs style.css with its header")
    for h in STYLE_HEADERS:
        if os.path.isfile(style) and not sh.get(h):
            add("error", "X7", "style_header", "style.css", "missing header: %s" % h)
    v = sh.get("Version", "")
    if v and not re.match(r"^\d+\.\d+(\.\d+)?$", v):
        add("error", "X7", "style_version_format", "style.css", "Version must be X.X or X.X.X (got %s)" % v)
    for h in ("Requires at least", "Tested up to", "Requires PHP"):
        if sh.get(h) and not re.match(r"^\d+(\.\d+)*$", sh[h]):
            add("error", "X7", "style_number_only", "style.css", "%s must be a number only (got %s)" % (h, sh[h]))
    if "wordpress.org" in sh.get("Theme URI", "").lower():
        add("error", "X7", "theme_uri_reserved", "style.css", "a wordpress.org Theme URI is reserved for default themes")
    td = sh.get("Text Domain", "")
    if td and slug and td != slug:
        add("error", "I2", "text_domain_mismatch", "style.css", "Text Domain is %s, the theme slug (folder) is %s" % (td, slug))

    # name
    name = sh.get("Theme Name", "")
    if name and NAME_WORDS.search(name):
        add("error", "N1", "reserved_word_in_name", "style.css", "theme names can't use WordPress, Theme or Twenty*: %s" % name)
    for w in re.split(r"[^a-z0-9]+", (name + " " + slug).lower()):
        # Names of 5+ letters count anywhere in a word ("WPShadcn"); short ones only as a prefix ("vue" not in "revue").
        if w and any(w == p or w.startswith(p) or (len(p) >= 5 and p in w) for p in PROJECT_NAMES):
            add("warning", "N3", "third_party_name", "style.css", "%r names someone else's project; reviewers treat that like a trademark (name: %s)" % (w, name))
            break
    if re.search(r"Wordpress|wordPress|WORDPRESS", name + " " + sh.get("Description", "")):
        add("warning", "N2", "wordpress_spelling", "style.css", "spell it WordPress")

    # readme.txt
    readme = os.path.join(root, "readme.txt")
    if not os.path.isfile(readme):
        add("error", "X8", "missing_readme", "readme.txt", "a theme needs readme.txt")
    else:
        rtext = open(readme, encoding="utf-8", errors="replace").read()
        if not re.search(r"^===\s*.+?\s*===", rtext, re.M):
            add("error", "X8", "readme_title", "readme.txt", "first line must be === Theme Name ===")
        rh = headers_of(readme, README_HEADERS)
        for h in README_HEADERS:
            if not rh.get(h):
                add("error", "X8", "readme_header", "readme.txt", "missing header: %s" % h)
        if not re.search(r"copyright", rtext, re.I):
            add("error", "L2", "no_copyright", "readme.txt", "state the theme's copyright (and each bundled resource's)")
        if not re.search(r"^==\s*(Resources|Credits|Copyright)", rtext, re.M | re.I):
            add("warning", "L3", "no_resources_section", "readme.txt", "list every bundled image, font and library with its license and source (an == Resources == section)")
        for h in ("Requires at least", "Tested up to", "Requires PHP"):
            if sh.get(h) and rh.get(h) and sh[h] != rh[h]:
                add("warning", "X8", "readme_style_mismatch", "readme.txt", "%s is %s in readme.txt and %s in style.css" % (h, rh[h], sh[h]))

    # block or classic, required files
    block = os.path.isfile(os.path.join(root, "templates", "index.html"))
    inventory["type"].append("block theme" if block else "classic theme")
    if block:
        if not os.path.isfile(os.path.join(root, "theme.json")):
            add("error", "B1", "missing_theme_json", "theme.json", "a block theme needs theme.json")
    elif not sh.get("Template"):
        if not os.path.isfile(os.path.join(root, "index.php")):
            add("error", "K1", "missing_index_php", "index.php", "a classic theme needs index.php (or templates/index.html for a block theme)")
        if not os.path.isfile(os.path.join(root, "comments.php")):
            add("warning", "K1", "missing_comments_php", "comments.php", "classic themes are expected to ship comments.php (threaded comments)")
    if sh.get("Template"):
        inventory["type"].append("child theme of %s" % sh["Template"])

    shots = [f for f in files if re.match(r"^screenshot\.(png|jpe?g|webp)$", f, re.I)]
    if not shots:
        add("error", "X6", "missing_screenshot", "screenshot.png", "a theme needs a screenshot")
    for s in shots:
        size = image_size(os.path.join(root, s))
        if not size:
            add("warning", "X6", "screenshot_unreadable", s, "couldn't read its size: check it is at most 1200x900 and 4:3")
            continue
        w, h = size
        inventory["screenshot"].append("%s %dx%d" % (s, w, h))
        if w > 1200 or h > 900:
            add("error", "X6", "screenshot_too_big", s, "%dx%d is over 1200x900" % (w, h))
        if w * 3 != h * 4:
            add("error", "X6", "screenshot_ratio", s, "%dx%d is not 4:3" % (w, h))

    # code scan
    domains = defaultdict(int)
    hooks_seen = set()
    crlf, lf = [], []
    for rel in files:
        ext = os.path.splitext(rel)[1].lower()
        if ext not in CODE_EXT:
            continue
        try:
            raw = open(os.path.join(root, rel), "rb").read()
        except OSError:
            continue
        if b"\r\n" in raw:
            crlf.append(rel)
        elif b"\n" in raw:
            lf.append(rel)
        text = raw.decode("utf-8", errors="replace")
        lines = text.split("\n")

        def at(pos):
            return "%s:%d" % (rel, text.count("\n", 0, pos) + 1)

        if ext == ".php":
            for check, rx in PLUGIN_TERRITORY:
                for m in re.finditer(rx, text):
                    add("error", "F7", "plugin_territory_" + check, at(m.start()), "plugin territory: %s belongs in a plugin" % check)
            for m in REMOVED_HOOKS.finditer(text):
                add("error", "F6", "removes_core_hook", at(m.start()), "don't remove the non-presentational hook %s" % m.group(1))
            for m in ADMIN_BAR.finditer(text):
                add("error", "F4", "hides_admin_bar", at(m.start()), "themes must not hide the admin bar")
            for m in REDIRECT_ON_ACTIVATE.finditer(text):
                add("error", "F5", "redirect_on_activation", at(m.start()), "no redirect on activation")
            for m in DEPRECATED_TITLE.finditer(text):
                add("warning", "K3", "wp_title", at(m.start()), "use add_theme_support( 'title-tag' ), not wp_title()")
            for m in ENQUEUE_REMOTE.finditer(text):
                host = m.group(4)
                if not host.endswith(ALLOWED_REMOTE) and "$" not in host:
                    add("error", "X2", "remote_asset", at(m.start()), "enqueues a file from %s: bundle it (only Google Fonts may stay remote)" % host)
            for m in TEXT_DOMAIN_CALL.finditer(text):
                domains[m.group(1)] += 1
            if TGMPA.search(text):
                inventory["plugin_recommendations"].append(rel)
            for m in PLUGIN_SOURCE.finditer(text):
                add("error", "W3", "bundled_plugin_source", at(m.start()), "plugins may only come from WordPress.org, installed by the user")
            for check, rx in CLASSIC_HOOKS:
                if re.search(rx, text):
                    hooks_seen.add(check)
            for i, ln in enumerate(lines, 1):
                if re.search(r"\badd_menu_page\s*\(|\badd_submenu_page\s*\(|\badd_theme_page\s*\(", ln):
                    inventory["admin_pages"].append("%s:%d" % (rel, i))
                if re.search(r"['\"]admin_notices['\"]", ln):
                    inventory["admin_notices"].append("%s:%d" % (rel, i))
                if re.search(r"\b(update_option|add_option)\s*\(", ln):
                    inventory["options_written"].append("%s:%d %s" % (rel, i, ln.strip()[:100]))
                if re.search(r"\bwp_remote_(get|post|request)\s*\(|\bcurl_init\s*\(", ln):
                    inventory["remote_calls"].append("%s:%d" % (rel, i))
                if re.search(r"upgrade|upsell|\bpro\b|premium", ln, re.I) and re.search(r"https?://", ln):
                    inventory["upsell_links"].append("%s:%d %s" % (rel, i, ln.strip()[:100]))
        if ext == ".css":
            for m in CSS_IMPORT_REMOTE.finditer(text):
                if not m.group(3).endswith(ALLOWED_REMOTE):
                    add("error", "X2", "remote_css_import", at(m.start()), "@import from %s: bundle it" % m.group(3))
        if ext == ".json":
            for m in FONTFACE_REMOTE.finditer(text):
                if not m.group(2).endswith(ALLOWED_REMOTE):
                    add("error", "X2", "remote_font", at(m.start()), "font loaded from %s: bundle it in the theme" % m.group(2))
        if ext in (".php", ".html", ".json"):
            for m in IMG_REMOTE.finditer(text):
                host = m.group(2) or m.group(4) or ""
                if host and not host.endswith(ALLOWED_REMOTE) and "w.org" not in host and "wordpress.org" not in host and "gravatar.com" not in host:
                    add("warning", "X2", "remote_image", at(m.start()), "image from %s: patterns and templates should use images bundled in the theme" % host)

    if not block and not sh.get("Template"):
        for check, _ in CLASSIC_HOOKS:
            if check not in hooks_seen:
                add("error", "K2", "missing_" + check.replace("-", "_"), "", "a classic theme must call %s" % check)
    if crlf and lf:
        add("warning", "X9", "mixed_line_endings", ", ".join(crlf[:5]), "%d files use CRLF, %d use LF: use one" % (len(crlf), len(lf)))
    others = sorted(d for d in domains if d != slug)
    if slug and others:
        sev = "error" if len(others) > 1 else "warning"
        add(sev, "I3", "other_text_domains", "", "text domains other than %s: %s (at most two in all, for a framework)" % (slug, ", ".join("%s (%d)" % (d, domains[d]) for d in others)))
    inventory["text_domains"] = ["%s (%d)" % (d, n) for d, n in sorted(domains.items())]

    counts = defaultdict(int)
    for f in findings:
        counts[f["severity"]] += 1
    result = {"theme": name or slug, "slug": slug, "version": v, "block": block, "counts": counts, "findings": findings, "inventory": inventory}
    if tmp:
        shutil.rmtree(tmp, ignore_errors=True)
    if a.json:
        print(json.dumps(result, indent=1))
        return 0

    print("# Static precheck: %s (slug: %s)\n" % (name or slug, slug))
    print("Reviewed: %s%s\n" % (src, " (zip contents)" if tmp else ""))
    print("%s | Version %s | errors %d, warnings %d\n" % ("block theme" if block else "classic theme", v or "?", counts["error"], counts["warning"]))
    grouped = defaultdict(list)
    for f in findings:
        grouped[(f["severity"], f["id"], f["check"])].append(f)
    for (sev, cid, check), its in sorted(grouped.items(), key=lambda k: (k[0][0] != "error", k[0][1], k[0][2])):
        print("## [%s] %s %s (%d)" % (sev.upper(), cid, check, len(its)))
        print("  %s" % its[0]["message"])
        for f in its[:25]:
            if f["where"]:
                print("  - %s%s" % (f["where"], "  " + f["message"] if f["message"] != its[0]["message"] else ""))
        if len(its) > 25:
            print("  - ... and %d more" % (len(its) - 25))
        print()
    print("# Inventory for the manual pass\n")
    for k, vals in inventory.items():
        print("## %s (%d)" % (k, len(vals)))
        for x in vals[:40]:
            print("  - %s" % x)
        if len(vals) > 40:
            print("  - ... and %d more" % (len(vals) - 40))
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
