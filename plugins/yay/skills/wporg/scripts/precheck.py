#!/usr/bin/env python3
"""Static pre-review of a WordPress plugin against WordPress.org submission rules.

Needs no WordPress install: it reads the files directly. It approximates the
Plugin Check "Plugin Repo" gate and the patterns human reviewers cite most,
and it builds an inventory (AJAX/REST handlers, external hosts, admin
notices, global names) for the manual pass.

Usage: precheck.py <plugin-dir | plugin.zip> [--slug SLUG] [--wp-version 6.9] [--offline] [--json]

Give it the built zip (or the folder the build produced), not the source repo:
WordPress.org only sees what is uploaded. Every finding carries its ID from
references/checklist.md (CHECK_IDS below), so the report, the fix commits and
the review-email mapping all use the same names.
"""
import argparse
import fnmatch
import json
import os
import re
import shutil
import sys
import tempfile
import urllib.request
import zipfile
from collections import Counter, defaultdict

SKIP_DIRS = {"node_modules", "vendor", "vendor_prefixed", "vendor-prefixed", ".git"}
CODE_EXT = {".php", ".js", ".jsx", ".ts", ".tsx", ".mjs"}
ALLOWED_EXT = {
    ".php", ".js", ".jsx", ".ts", ".tsx", ".mjs", ".css", ".scss", ".sass", ".less", ".map",
    ".txt", ".md", ".json", ".xml", ".html", ".htm", ".svg", ".png", ".jpg", ".jpeg",
    ".gif", ".webp", ".ico", ".avif", ".woff", ".woff2", ".ttf", ".eot", ".otf", ".pot", ".po",
    ".mo", ".l10n.php", ".csv", ".yml", ".yaml", ".lock", ".dist", ".neon", ".mp4", ".webm",
    ".mp3", ".wav", ".ogg", ".pdf", ".twig", ".mustache", ".hbs", ".tpl", ".lottie",
}
BLOCKED_EXT = {
    ".zip", ".gz", ".tgz", ".rar", ".7z", ".tar", ".phar", ".exe", ".sh", ".bat", ".bin",
    ".dmg", ".iso", ".so", ".o", ".obj", ".dll", ".pkg", ".deb", ".jar", ".sql", ".log",
    ".bak", ".swp",
}
ROOT_MD_OK = {"readme.md", "license", "license.md", "changelog.md", "contributing.md", "security.md"}
AI_DIRS = {".claude", ".cursor", ".aider", ".continue", ".windsurf", ".ai"}
DEV_DIRS = {"tests", "test", "node_modules", "bower_components", ".github", ".gitlab", ".circleci", "docs-dev", "demo", "demos"}
CORE_LIBS = re.compile(r"(^|/)(jquery(\.min)?\.js|jquery-ui(\.min)?\.js|jquery-migrate(\.min)?\.js|class-phpmailer\.php|PHPMailer\.php|simplepie|class-simplepie|PasswordHash\.php|class-phpass\.php|backbone(\.min)?\.js|underscore(\.min)?\.js|react(-dom)?(\.production)?(\.min)?\.js|lodash(\.min)?\.js|moment(\.min)?\.js)$", re.I)
TRADEMARK_PREFIX = ["adobe", "adsense", "advanced-custom-fields", "akismet", "amazon", "android", "apple", "aws", "bbpress", "bing", "bootstrap", "buddypress", "chatgpt", "chat-gpt", "cloudflare", "contact-form-7", "cpanel", "disqus", "divi", "dropbox", "easy-digital-downloads", "elementor", "envato", "facebook", "fb", "fedex", "firefox", "fontawesome", "font-awesome", "github", "givewp", "google", "gravity-forms", "gravityforms", "gutenberg", "guten", "hubspot", "ig", "insta", "instagram", "ios", "jetpack", "macos", "mailchimp", "microsoft", "ninja-forms", "opera", "paddle", "paypal", "pinterest", "skype", "stripe", "tiktok", "tik-tok", "trustpilot", "twitch", "twitter", "ups", "usps", "whatsapp", "whats-app", "windows", "woo", "woocommerce", "woocom", "wp-mail-smtp", "yandex", "yahoo", "yoast", "youtube", "you-tube"]
# Third-party project, library and product names the review AI flags even though Plugin Check's list lacks them.
# Not exhaustive: the manual pass checks every distinctive word of the name (references/manual-review.md §8).
PROJECT_NAMES = ["shadcn", "tailwind", "tailwindcss", "react", "vue", "vuejs", "nextjs", "next-js", "svelte", "alpine", "alpinejs", "htmx", "laravel", "figma", "notion", "slack", "discord", "telegram", "zapier", "airtable", "shopify", "openai", "gpt", "claude", "anthropic", "gemini", "copilot", "midjourney", "deepseek", "perplexity", "canva", "unsplash", "spotify", "linkedin", "x-twitter", "zoom", "calendly", "klaviyo", "brevo", "sendgrid", "mailgun", "twilio", "square", "razorpay", "mollie", "klarna", "algolia", "meilisearch", "sentry", "vimeo", "wistia", "beaver-builder", "oxygen", "bricks", "breakdance", "kadence", "astra", "generatepress", "learndash", "lifterlms", "tutor-lms", "memberpress", "wpml", "polylang", "acf", "jetengine", "dokan", "wcfm", "material-ui", "mui", "chakra", "ant-design", "heroicons", "lucide"]
TRADEMARK_ANYWHERE = ["wordpress", "wordpess", "wpress", "plugin", "facebook", "instagram", "whatsapp", "trustpilot", "yoast", "gutenberg", "woocommerce", "tweet"]
ALLOWED_REMOTE_HOSTS = ("fonts.googleapis.com", "fonts.gstatic.com", "fonts.bunny.net", "use.typekit.net")
SHORTENERS = ("bit.ly", "tinyurl.com", "goo.gl", "t.co/", "ow.ly", "is.gd", "buff.ly", "rebrand.ly", "cutt.ly")

# check name -> checklist ID (references/checklist.md)
CHECK_IDS = {
    "ajax_nonce": "S1", "ajax_capability": "S1", "nonce_missing": "S1",
    "rest_permission": "S2", "rest_public_write": "S2",
    "unsanitized_input": "S3", "whole_input": "S3", "filter_no_flag": "S3", "filter_unsafe_raw": "S3", "setting_sanitization": "S3",
    "unescaped_output": "S4", "unescaped_e": "S4", "echo_gettext": "S4", "printf_gettext": "S4", "echo_sanitize": "S4",
    "esc_url_raw_output": "S4", "heredoc": "S4", "short_open_tag": "S4", "short_echo_tag": "S4",
    "echo_json_flags": "S6", "echo_json_encode": "S6",
    "direct_db": "S8", "mysql": "S8",
    "direct_file_access": "S9",
    "eval": "S10", "create_function": "S10", "forbidden_exec": "S10", "str_rot13": "S10", "base64_decode": "S10",
    "goto_backtick": "S10", "unserialize": "S10", "move_uploaded_file": "S10", "unfiltered_uploads": "S10",
    "inline_script_json_hex": "S11",
    "updater": "G1", "plugin_updater_detected": "G1",
    "offloading_files": "G2",
    "external_services": "G3", "ai_provider": "G3",
    "no_public_source": "B1",
    "no_build_instructions": "B2", "missing_composer_json_file": "B2", "stale_autoloader": "B2",
    "file_type": "B4", "unneeded_folders": "B4", "localhost": "B4", "source_repo": "B4", "distignore": "B4",
    "unclosed_ob_start": "Q1",
    "prefixing": "Q2",
    "admin_body_class": "Q3", "enqueue_scope": "Q3", "direct_tags": "Q3",
    "load_textdomain": "Q4",
    "i18n_textdomain_mismatch": "Q5", "i18n_variable_domain": "Q5",
    "dev_functions": "Q6",
    "uninstall_missing_constant_check": "Q7",
    "library_core_files": "Q8",
    "post_type_key_length": "Q9",
    "change_plugins": "Q10",
    "product_query_visibility": "Q13",
    "curl": "Q14", "file_get_contents_url": "Q14", "timezone": "Q14", "error_reporting": "Q14", "global_ini": "Q14",
    "json_encode": "Q14", "wp_redirect": "Q14", "wp_load": "Q14", "write_file": "Q14", "query_posts": "Q14",
    "plugindir": "Q14", "short_url": "Q14",
    "readme": "R1", "no_plugin_readme": "R1", "readme_invalid_contributors": "R1", "no_short_description_present": "R1",
    "trimmed_short_description": "R1", "default_readme_text": "R1", "readme_size": "R1", "readme_non_official_language": "R1",
    "mismatched_plugin_name": "R1",
    "no_stable_tag": "R2", "trunk_stable_tag": "R2", "stable_tag_mismatch": "R2", "invalid_tested_upto": "R2",
    "outdated_tested_upto_header": "R2", "tested_up_to": "R2",
    "readme_mismatched_header": "R3",
    "plugin_header": "R4", "textdomain_mismatch": "R4", "plugin_header_tested_up_to_not_allowed": "R4",
    "no_license": "R4", "license_mismatch": "R4",
    "too_many_tags": "R5",
    "block_api_version_too_low": "T3", "react_removed": "T3",
    "trademarks": "N1", "plugin_name": "N1", "slug": "N1",
    "main_file_name": "N2",
    "ownership": "N3",
    "zip_structure": "Z1", "zip_size": "Z2", "zip_macosx": "Z3", "zip_unsafe_path": "Z3",
}

# (id, severity, regex, message, php_only)
PATTERNS = [
    ("eval", "error", r"\beval\s*\(", "eval() is a forbidden function.", True),
    ("create_function", "error", r"\bcreate_function\s*\(", "create_function() is forbidden.", True),
    ("forbidden_exec", "error", r"\b(passthru|proc_open|shell_exec|system|exec|popen)\s*\(", "Process execution functions are forbidden or will be questioned.", True),
    ("str_rot13", "error", r"\bstr_rot13\s*\(", "str_rot13() is forbidden (obfuscation).", True),
    ("base64_decode", "warning", r"\bbase64_decode\s*\(", "base64_decode() draws obfuscation scrutiny; make sure it is not used to hide code.", True),
    ("move_uploaded_file", "error", r"\bmove_uploaded_file\s*\(", "Use wp_handle_upload() / media_handle_upload() instead of move_uploaded_file().", True),
    ("unfiltered_uploads", "error", r"ALLOW_UNFILTERED_UPLOADS", "Any reference to ALLOW_UNFILTERED_UPLOADS is rejected; add specific types via the upload_mimes filter.", True),
    ("heredoc", "error", r"<<<\s*['\"]?[A-Za-z_]", "HEREDOC/NOWDOC is not permitted (sniffers can't see unescaped output inside).", True),
    ("short_open_tag", "error", r"<\?(?!php|=|xml)\s", "PHP short open tag; use <?php.", True),
    ("short_echo_tag", "warning", r"<\?=", "<?= is discouraged; use <?php echo esc_html( ... ); ?>.", True),
    ("curl", "error", r"\bcurl_(init|exec|setopt|setopt_array|multi_\w+)\s*\(", "Use the HTTP API (wp_remote_get/post/request) instead of cURL.", True),
    ("file_get_contents_url", "error", r"file_get_contents\s*\(\s*['\"]https?://", "file_get_contents() on a URL; use wp_remote_get().", True),
    ("timezone", "error", r"\bdate_default_timezone_set\s*\(", "Do not change the default timezone; use wp_date(), current_time(), wp_timezone().", True),
    ("error_reporting", "error", r"\berror_reporting\s*\(|ini_set\s*\(\s*['\"]display_errors", "Do not change error reporting in production code.", True),
    ("global_ini", "warning", r"\b(ini_set|ini_alter|set_time_limit|dl)\s*\(", "Changing PHP settings globally is flagged; scope it to the one function that needs it, or remove it.", True),
    ("unescaped_e", "error", r"(?<![\w>])_(e|ex)\s*\(", "_e()/_ex() output unescaped; use esc_html_e() / esc_attr_e() or echo esc_html( _x() ).", True),
    ("echo_gettext", "error", r"\becho\s+\(?\s*(__|_x|_n|_nx)\s*\(", "echo __() is unescaped; use esc_html__() / esc_attr__().", True),
    ("printf_gettext", "error", r"\b(printf|vprintf|print)\s*\(?\s*(__|_x|_n|_nx)\s*\(", "printf( __() ) is unescaped; use printf( esc_html__() ) (or wp_kses() when the string holds markup) and escape every argument too (esc_url( admin_url() ), esc_html( $x )).", True),
    ("echo_json_flags", "warning", r"\becho\s+\(?\s*wp_json_encode\s*\([^;]*JSON_(HEX|UNESCAPED)", "Echoed wp_json_encode() with flags gets flagged as escape-avoidance. For block markup use get_comment_delimited_block_content() / serialize_block_attributes(); for JS data use wp_add_inline_script() or wp_localize_script(); otherwise wrap in esc_attr()/esc_html().", True),
    ("load_textdomain", "warning", r"\bload_plugin_textdomain\s*\(", "load_plugin_textdomain() is not needed for WordPress.org plugins since WP 4.6; remove it (or, if you support older WP, call it on 'init').", True),
    ("echo_json_encode", "error", r"\becho\s+json_encode\s*\(", "Use wp_json_encode() (and usually return/wp_send_json rather than echo).", True),
    ("json_encode", "warning", r"(?<![\w>])json_encode\s*\(", "Use wp_json_encode() instead of json_encode().", True),
    ("esc_url_raw_output", "error", r"\becho\s+esc_url_raw\s*\(|=\s*\"\s*<\?php\s+echo\s+esc_url_raw", "esc_url_raw() is for the database/redirects; use esc_url() for output.", True),
    ("echo_sanitize", "error", r"\becho\s+sanitize_\w+\s*\(", "Sanitizing functions are not output escaping; escape with esc_html()/esc_attr()/wp_kses_post().", True),
    ("wp_redirect", "warning", r"(?<![\w_])wp_redirect\s*\(", "Prefer wp_safe_redirect() followed by exit.", True),
    ("unserialize", "error", r"(?<![\w_])unserialize\s*\(", "unserialize() on untrusted data is a top security-scan trigger; use JSON or maybe_unserialize() on trusted data only.", True),
    ("filter_no_flag", "error", r"\bfilter_input\s*\(\s*INPUT_\w+\s*,\s*['\"][^'\"]+['\"]\s*\)|\bfilter_var\s*\(\s*[^,()]+\)", "filter_input()/filter_var() without a filter (FILTER_DEFAULT) does not sanitize.", True),
    ("filter_unsafe_raw", "error", r"FILTER_UNSAFE_RAW|FILTER_DEFAULT", "FILTER_UNSAFE_RAW/FILTER_DEFAULT do not sanitize.", True),
    ("whole_input", "error", r"foreach\s*\(\s*\$_(POST|GET|REQUEST)\s+as|map_deep\s*\(\s*\$_(POST|GET|REQUEST)|(sanitize_\w+|array_map\s*\([^,]+,)\s*\(?\s*\$_(POST|GET|REQUEST)\s*\)", "Processing the whole $_POST/$_GET/$_REQUEST array; read only the specific keys you need.", True),
    ("wp_load", "error", r"(require|include)(_once)?\s*\(?[^;]*wp-(load|config|blog-header)\.php", "Never include wp-load.php/wp-config.php directly; use AJAX, REST or admin-post endpoints.", True),
    ("change_plugins", "error", r"\b(activate_plugin|activate_plugins|deactivate_plugins)\s*\(", "Changing active plugins is not allowed (except deactivating your own plugin when a dependency is missing). Prefer the Requires Plugins header.", True),
    ("updater", "error", r"pre_set_site_transient_update_plugins|site_transient_update_plugins|auto_update_plugin|plugin-update-checker|Puc_v\d|PucFactory|EDD_SL_Plugin_Updater|plugins_api", "Custom update logic is not allowed; WordPress.org serves updates.", True),
    ("direct_tags", "error", r"<script[\s>]|<link[^>]+rel=['\"]stylesheet|<style[\s>]", "Print scripts/styles via wp_enqueue_* / wp_add_inline_* instead of hard-coded tags.", True),
    ("query_posts", "warning", r"\bquery_posts\s*\(", "query_posts() is discouraged; use WP_Query or pre_get_posts.", True),
    ("plugindir", "error", r"\b(PLUGINDIR|WP_PLUGIN_URL|STYLESHEETPATH|TEMPLATEPATH)\b", "Discouraged constant; use plugin_dir_path()/plugins_url()/get_stylesheet_directory().", True),
    ("dev_functions", "warning", r"(?<![\w>])(var_dump|print_r|error_log|var_export|debug_zval_dump|debug_print_backtrace)\s*\(", "Debug function left in code (allowed only if intentional and guarded).", True),
    ("mysql", "error", r"\b(mysql_\w+|mysqli_\w+)\s*\(|new\s+(PDO|mysqli)\b", "Use $wpdb, not raw mysql/mysqli/PDO.", True),
    ("goto_backtick", "error", r"\bgoto\s+\w+\s*;|=\s*`[^`]+`", "goto and backtick shell execution are not allowed.", True),
    ("react_removed", "error", r"ReactDOM\.(render|hydrate|unmountComponentAtNode|findDOMNode)\s*\(", "React API removed in React 19 (WP 7.0); use createRoot().", False),
    ("ai_provider", "warning", r"api\.openai\.com|api\.anthropic\.com|generativelanguage\.googleapis\.com|api\.mistral\.ai|api\.groq\.com", "Direct AI provider call; Plugin Check suggests the WordPress AI Client, and it must be documented as an external service.", False),
]

URL_RE = re.compile(r"https?://[A-Za-z0-9.\-]+(?::\d+)?[^\s'\"<>)\]]*")
HEADER_RE = re.compile(r"^[ \t/*#@]*([A-Za-z ]+?):[ \t]*(.+?)\s*(\*/)?$")


def rel(path, root):
    return os.path.relpath(path, root)


def read(path):
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return ""


def parse_headers(text, limit=8192):
    out = {}
    for line in text[:limit].splitlines():
        m = HEADER_RE.match(line)
        if m:
            key = m.group(1).strip()
            if key.lower() in {k.lower() for k in out}:
                continue
            out[key] = m.group(2).strip()
    return out


def is_comment(line):
    s = line.strip()
    return s.startswith(("//", "*", "/*", "#")) and not s.startswith("#[")


def current_wp_major(offline):
    if offline:
        return None
    try:
        with urllib.request.urlopen("https://api.wordpress.org/core/version-check/1.7/", timeout=6) as r:
            data = json.loads(r.read().decode())
        ver = data["offers"][0]["current"]
        return ".".join(ver.split(".")[:2])
    except Exception:
        return None


class Report:
    def __init__(self):
        self.items = []

    def add(self, sev, check, msg, file=None, line=None, snippet=None):
        self.items.append({"severity": sev, "id": CHECK_IDS.get(check, ""), "check": check, "message": msg, "file": file, "line": line, "snippet": snippet})


def load_distignore(root):
    """Patterns from .distignore (used by `wp dist-archive` and 10up's deploy action)."""
    path = os.path.join(root, ".distignore")
    if not os.path.exists(path):
        return []
    pats = []
    for ln in read(path).splitlines():
        ln = ln.strip()
        if ln and not ln.startswith("#"):
            # gitignore-style: a leading slash (or a slash inside) anchors the pattern to the plugin root
            anchored = ln.startswith("/") or "/" in ln.strip("/")
            pats.append(("/" if anchored else "") + ln.strip("/"))
    return pats


def ignored(relpath, pats):
    relpath = relpath.replace(os.sep, "/")
    for pat in pats:
        anchored = pat.startswith("/")
        pat = pat.lstrip("/")
        if fnmatch.fnmatch(relpath, pat) or relpath == pat or relpath.startswith(pat + "/"):
            return True
        if not anchored and any(fnmatch.fnmatch(part, pat) for part in relpath.split("/")):
            return True
    return False


def walk(root, pats):
    for dirpath, dirnames, filenames in os.walk(root):
        relp = rel(dirpath, root)
        dirnames[:] = [d for d in dirnames if not ignored(os.path.join(relp, d) if relp != "." else d, pats)]
        filenames = [f for f in filenames if not ignored(os.path.join(relp, f) if relp != "." else f, pats)]
        yield dirpath, dirnames, filenames


def extract_zip(path):
    """Unpack a plugin zip into a temp dir (refusing unsafe paths). Returns (tmp_dir, plugin_root, notes)."""
    notes = []
    tmp = tempfile.mkdtemp(prefix="wporg-precheck-")
    with zipfile.ZipFile(path) as z:
        for info in z.infolist():
            name = info.filename
            if name.startswith(("/", "\\")) or ".." in name.replace("\\", "/").split("/"):
                notes.append(("error", "zip_unsafe_path", "Unsafe path in zip, skipped: %s" % name))
                continue
            z.extract(info, tmp)
    tops = [d for d in os.listdir(tmp) if d != "__MACOSX"]
    if os.path.isdir(os.path.join(tmp, "__MACOSX")):
        notes.append(("error", "zip_macosx", "Zip contains __MACOSX/ (macOS Finder zip); build it with zip -r or wp dist-archive."))
    if len(tops) == 1 and os.path.isdir(os.path.join(tmp, tops[0])):
        return tmp, os.path.join(tmp, tops[0]), notes
    notes.append(("error", "zip_structure", "Zip must contain exactly one top-level folder named after the slug; found: %s" % ", ".join(sorted(tops)[:5])))
    return tmp, tmp, notes


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("plugin_dir", help="plugin folder or built plugin .zip")
    ap.add_argument("--slug")
    ap.add_argument("--wp-version", help="Current WordPress major, e.g. 6.9 (auto-detected online otherwise)")
    ap.add_argument("--offline", action="store_true")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--no-distignore", action="store_true", help="Scan everything even if .distignore exists")
    args = ap.parse_args()

    rep = Report()
    inv = defaultdict(list)
    src = os.path.abspath(args.plugin_dir)
    tmp_dir = None
    if src.lower().endswith(".zip") and os.path.isfile(src):
        tmp_dir, root, notes = extract_zip(src)
        for sev, check, msg in notes:
            rep.add(sev, check, msg)
        if os.path.getsize(src) > 10 * 1048576:
            rep.add("error", "zip_size", "Zip is %.1f MB; the submission limit is 10 MB." % (os.path.getsize(src) / 1048576.0))
    else:
        root = src
        if not os.path.isdir(root):
            sys.exit("Not a directory or .zip: %s" % root)
    if tmp_dir and root == tmp_dir and not args.slug:
        # no top-level folder: guess the slug from the zip name (my-plugin.1.2.0.zip -> my-plugin)
        args.slug = re.sub(r"[.-]v?\d+(\.\d+)*$", "", os.path.basename(src)[:-4])
    try:
        run(args, src, root, rep, inv, from_zip=tmp_dir is not None)
    finally:
        if tmp_dir:
            shutil.rmtree(tmp_dir, ignore_errors=True)


def looks_like_source_repo(root):
    """Signs that this is the development repo rather than the shipped build."""
    signs = []
    if os.path.isdir(os.path.join(root, ".git")):
        signs.append(".git/")
    pj = os.path.join(root, "package.json")
    if os.path.exists(pj):
        try:
            scripts = json.loads(read(pj)).get("scripts", {})
            hits = [k for k in scripts if re.search(r"zip|release|dist|build:free|bundle|plugin-zip", k)]
            if hits:
                signs.append("package.json scripts: %s" % ", ".join(hits[:4]))
        except Exception:
            pass
    for f in ("Gruntfile.js", "gulpfile.js", "bin/build-zip.sh", "bin/build.sh", "Makefile"):
        if os.path.exists(os.path.join(root, f)):
            signs.append(f)
    wf = os.path.join(root, ".github", "workflows")
    if os.path.isdir(wf):
        for f in os.listdir(wf):
            if re.search(r"deploy|release|wporg|svn", read(os.path.join(wf, f)), re.I):
                signs.append(".github/workflows/%s" % f)
                break
    for d in ("pro", "premium", "src/Pro", "includes/pro", "inc/Pro"):
        if os.path.isdir(os.path.join(root, d)):
            signs.append("%s/" % d)
    if not os.path.isdir(os.path.join(root, "node_modules")) and os.path.exists(pj) and not any(os.path.isdir(os.path.join(root, d)) for d in ("build", "dist", "assets/dist")):
        signs.append("no built assets yet")
    return signs


def run(args, src, root, rep, inv, from_zip=False):
    slug = args.slug or os.path.basename(root.rstrip("/"))
    if not from_zip:
        signs = looks_like_source_repo(root)
        if signs:
            rep.add("warning", "source_repo", "This looks like the source repo, not the shipped build (%s). Results may differ from the zip WordPress.org receives: build the free zip in a copy and run precheck on it." % "; ".join(signs))
    pats = [] if args.no_distignore or from_zip else load_distignore(root)
    if pats:
        pats.append(".distignore")
        rep.add("info", "distignore", "Using .distignore (%d patterns): excluded paths are treated as not shipped. Make sure the real zip is built with it." % (len(pats) - 1))

    # ---------- files ----------
    total_size = 0
    all_files = []
    vendor_dirs = []
    for dirpath, dirnames, filenames in walk(root, pats):
        relp = rel(dirpath, root)
        for d in list(dirnames):
            dl = d.lower()
            p = os.path.join(relp, d) if relp != "." else d
            if dl in AI_DIRS:
                rep.add("warning", "file_type", "AI tool directory must not ship: %s/" % p, p)
            elif dl == ".git" or dl == ".svn" or dl == ".hg":
                rep.add("error", "file_type", "Version-control directory must not ship: %s/" % p, p)
            elif dl in DEV_DIRS:
                rep.add("warning", "unneeded_folders", "Development folder probably should not ship: %s/" % p, p)
            elif d.startswith("."):
                rep.add("error", "file_type", "Hidden directory: %s/" % p, p)
            if dl in ("vendor", "vendor_prefixed", "vendor-prefixed"):
                vendor_dirs.append(p)
        for f in filenames:
            full = os.path.join(dirpath, f)
            p = rel(full, root)
            try:
                total_size += os.path.getsize(full)
            except OSError:
                pass
            if any(part in SKIP_DIRS for part in p.split(os.sep)[:-1]) and not p.startswith("vendor"):
                continue
            all_files.append(p)
            fl = f.lower()
            ext = os.path.splitext(fl)[1]
            if f.startswith("."):
                rep.add("error", "file_type", "Hidden file must not ship: %s" % p, p)
            elif ext in BLOCKED_EXT:
                rep.add("error", "file_type", "File type not permitted in the plugin zip: %s" % p, p)
            elif ext and ext not in ALLOWED_EXT and not fl.endswith(".l10n.php"):
                rep.add("warning", "file_type", "Unusual file type, reviewers may ask about it: %s" % p, p)
            if os.sep not in p and ext == ".md" and fl not in ROOT_MD_OK:
                rep.add("warning", "file_type", "Unexpected markdown file in plugin root: %s" % p, p)
            if re.search(r"[^A-Za-z0-9._\-/]", p.replace(os.sep, "/")):
                rep.add("error", "file_type", "Badly named file (spaces or special characters): %s" % p, p)
            if CORE_LIBS.search(p.replace(os.sep, "/")) and "node_modules" not in p:
                rep.add("error", "library_core_files", "Bundles a library WordPress core already ships; use the core handle: %s" % p, p)
    if total_size > 10 * 1024 * 1024:
        rep.add("error", "zip_size", "Plugin folder is %.1f MB; the submission zip must be under 10 MB." % (total_size / 1048576.0))
    for vd in vendor_dirs:
        parent = os.path.dirname(vd)
        if not os.path.exists(os.path.join(root, parent, "composer.json")):
            rep.add("warning", "missing_composer_json_file", "%s/ exists but no composer.json next to it; include composer.json." % vd, vd)
    lower_map = Counter(f.lower() for f in all_files)
    for f in all_files:
        if lower_map[f.lower()] > 1:
            rep.add("error", "file_type", "Files differ only by case: %s" % f, f)

    # ---------- main file & headers ----------
    main_candidates = []
    for f in os.listdir(root):
        if f.endswith(".php") and not ignored(f, pats):
            h = parse_headers(read(os.path.join(root, f)))
            if "Plugin Name" in h:
                main_candidates.append((f, h))
    headers = {}
    main_file = None
    if not main_candidates:
        rep.add("error", "plugin_header", "No PHP file in the plugin root has a 'Plugin Name:' header.")
    else:
        if len(main_candidates) > 1:
            rep.add("error", "plugin_header", "Plugin headers found in more than one file: %s" % ", ".join(c[0] for c in main_candidates))
        main_file, headers = main_candidates[0]
        for c in main_candidates:
            if c[0] == slug + ".php":
                main_file, headers = c
        if main_file != slug + ".php":
            rep.add("error", "main_file_name", "Main file is '%s'; it should be named '%s.php' after the slug." % (main_file, slug), main_file)
        for req in ("Plugin Name", "Description", "Version", "License", "Requires at least", "Requires PHP", "Author"):
            if req not in headers:
                rep.add("error" if req in ("Plugin Name", "Version", "License", "Description") else "warning", "plugin_header", "Plugin header missing '%s'." % req, main_file)
        td = headers.get("Text Domain")
        if td and td != slug:
            rep.add("error", "textdomain_mismatch", "Text Domain '%s' must equal the slug '%s'." % (td, slug), main_file)
        if "Update URI" in headers:
            rep.add("error", "plugin_updater_detected", "'Update URI' header is not allowed on WordPress.org.", main_file)
        if "Tested up to" in headers:
            rep.add("error", "plugin_header_tested_up_to_not_allowed", "'Tested up to' belongs in readme.txt only, not the plugin header.", main_file)
        name = headers.get("Plugin Name", "")
        if len(re.findall(r"[A-Za-z0-9]", name)) < 5:
            rep.add("error", "plugin_header", "Plugin Name needs at least 5 Latin letters or digits.", main_file)
        if re.search(r"\b(wordpress|plugin)\b", name, re.I):
            rep.add("warning", "plugin_name", "Avoid 'WordPress' or 'Plugin' in the plugin name.", main_file)
        if len(name.split()) > 5:
            rep.add("warning", "plugin_name", "Plugin name has more than 5 words; keep it short.", main_file)
        if headers.get("Network") and headers["Network"].lower() != "true":
            rep.add("error", "plugin_header", "Network header must be 'true' or omitted.", main_file)
        rp = headers.get("Requires Plugins")
        if rp and "/" in rp:
            rep.add("error", "plugin_header", "Requires Plugins takes WordPress.org slugs, not paths.", main_file)
        dp = headers.get("Domain Path")
        if dp and not os.path.isdir(os.path.join(root, dp.strip("/"))):
            rep.add("warning", "plugin_header", "Domain Path '%s' does not exist." % dp, main_file)
        puri = headers.get("Plugin URI", "")
        if "wordpress.org" in puri:
            rep.add("error", "plugin_header", "Plugin URI must not be a WordPress.org URL.", main_file)

    # ---------- slug / trademarks ----------
    for t in TRADEMARK_PREFIX:
        if slug == t or slug.startswith(t + "-"):
            rep.add("error", "trademarks", "Slug starts with trademark/project name '%s'. Put it later, e.g. 'my-thing-for-%s', unless you own it." % (t, t))
            break
    for t in TRADEMARK_ANYWHERE:
        if t in slug and not (t == "woocommerce" and slug.endswith("-for-woocommerce")):
            rep.add("error", "trademarks", "Slug contains '%s', which is not allowed in slugs." % t)
    if re.search(r"\d+(\.\d+)+|-v\d", slug):
        rep.add("error", "slug", "Slug must not contain version numbers.")
    name_l = re.sub(r"[^a-z0-9]+", "-", headers.get("Plugin Name", "").lower()).strip("-")
    for t in TRADEMARK_PREFIX + PROJECT_NAMES:
        if (name_l == t or name_l.startswith(t + "-")) and not (slug == t or slug.startswith(t + "-")):
            rep.add("error" if t in TRADEMARK_PREFIX else "warning", "trademarks", "Display name starts with '%s', which implies affiliation. Use '<Your Brand> ... for %s'." % (t, t), main_file)
            break
    for t in PROJECT_NAMES:
        if slug == t or slug.startswith(t + "-"):
            rep.add("warning", "trademarks", "Slug starts with the project/library name '%s' (not in Plugin Check's list, but the review AI flags it). Use '<your-brand>-...-for-%s'." % (t, t))
            break
    # Ownership: the team compares the names and URLs in the plugin with the submitter's account and email domain.
    def _host(u):
        h = re.sub(r"^https?://", "", u or "").split("/")[0].lower()
        return ".".join(h.split(".")[-2:]) if h else ""
    ph, ah = _host(headers.get("Plugin URI")), _host(headers.get("Author URI"))
    if ph and ah and ph != ah:
        rep.add("info", "ownership", "Plugin URI domain '%s' differs from Author URI domain '%s'. The team will ask you to prove you own '%s' (DNS TXT record, account email on that domain, or explanation). Use the author's domain or be ready to verify." % (ph, ah, ph), main_file)
    for t in TRADEMARK_PREFIX + PROJECT_NAMES:
        if len(t) >= 5 and t.replace("-", "") in ph.replace("-", ""):
            rep.add("warning", "trademarks", "Plugin URI domain '%s' contains '%s'; trademarks in URLs, icons, banners and usernames are reviewed too." % (ph, t), main_file)
            break

    # ---------- readme ----------
    readme_path = None
    for cand in os.listdir(root):
        if cand.lower() == "readme.txt":
            readme_path = cand
    readme = ""
    if not readme_path:
        rep.add("error", "no_plugin_readme", "No readme.txt (a README.md alone is rejected).")
    else:
        readme = read(os.path.join(root, readme_path))
        if readme_path != "readme.txt":
            rep.add("warning", "readme", "Name the file 'readme.txt' (lowercase).", readme_path)
        rh = parse_headers(readme, 3000)
        mname = re.match(r"\s*===\s*(.+?)\s*===", readme)
        if not mname:
            rep.add("error", "readme", "readme.txt must start with '=== Plugin Name ==='.", readme_path)
        elif headers.get("Plugin Name") and mname.group(1).strip() != headers["Plugin Name"].strip():
            rep.add("warning", "mismatched_plugin_name", "readme name '%s' differs from header Plugin Name '%s'." % (mname.group(1), headers["Plugin Name"]), readme_path)
        st = rh.get("Stable tag")
        if not st:
            rep.add("error", "no_stable_tag", "readme.txt has no 'Stable tag'.", readme_path)
        elif st.lower() == "trunk":
            rep.add("error", "trunk_stable_tag", "Stable tag 'trunk' is not allowed for new plugins.", readme_path)
        elif headers.get("Version") and st != headers["Version"]:
            rep.add("error", "stable_tag_mismatch", "Stable tag %s does not match header Version %s." % (st, headers["Version"]), readme_path)
        lic = rh.get("License")
        if not lic:
            rep.add("error", "no_license", "readme.txt has no 'License'.", readme_path)
        elif headers.get("License") and lic.strip().lower() != headers["License"].strip().lower():
            rep.add("error", "license_mismatch", "readme License '%s' differs from header License '%s'." % (lic, headers["License"]), readme_path)
        tags = [t.strip() for t in rh.get("Tags", "").split(",") if t.strip()]
        if len(tags) > 5:
            rep.add("warning", "too_many_tags", "%d tags; only the first 5 are used." % len(tags), readme_path)
        tu = rh.get("Tested up to")
        wp_major = args.wp_version or current_wp_major(args.offline)
        if not tu:
            rep.add("error", "readme", "readme.txt has no 'Tested up to'.", readme_path)
        else:
            if not re.fullmatch(r"\d+\.\d+", tu):
                rep.add("error", "invalid_tested_upto", "'Tested up to: %s' must be a major version like 6.9." % tu, readme_path)
            if wp_major:
                try:
                    if tuple(int(x) for x in tu.split(".")[:2]) < tuple(int(x) for x in wp_major.split(".")):
                        rep.add("error", "outdated_tested_upto_header", "'Tested up to: %s' is older than the current WordPress %s (blocks upload)." % (tu, wp_major), readme_path)
                except ValueError:
                    pass
            else:
                rep.add("info", "tested_up_to", "Could not look up the current WordPress version; confirm 'Tested up to: %s' is the latest major." % tu, readme_path)
        for k in ("Requires at least", "Requires PHP"):
            if rh.get(k) and headers.get(k) and rh[k] != headers[k]:
                rep.add("error", "readme_mismatched_header", "readme '%s: %s' differs from plugin header '%s'." % (k, rh[k], headers[k]), readme_path)
        contrib = rh.get("Contributors", "")
        if not contrib:
            rep.add("warning", "readme", "No Contributors line; list WordPress.org usernames.", readme_path)
        elif re.search(r"[A-Z ]|@", contrib.replace(", ", ",")):
            rep.add("warning", "readme_invalid_contributors", "Contributors should be WordPress.org usernames (lowercase, no spaces/emails): '%s'." % contrib, readme_path)
        # short description: first non-empty non-header line after the header block
        body = readme.split("==", 1)
        lines = readme.splitlines()
        short = None
        in_head = True
        for ln in lines[1:]:
            if in_head:
                if not ln.strip():
                    in_head = False
                continue
            if ln.strip().startswith("=="):
                break
            if ln.strip():
                short = ln.strip()
                break
        if not short:
            rep.add("warning", "no_short_description_present", "No short description line under the readme header.", readme_path)
        elif len(short) > 150:
            rep.add("warning", "trimmed_short_description", "Short description is %d characters; max 150." % len(short), readme_path)
        for sec in ("Description", "Installation", "Changelog"):
            if not re.search(r"^==\s*%s\s*==" % sec, readme, re.M | re.I):
                rep.add("warning", "readme", "readme.txt has no '== %s ==' section." % sec, readme_path)
        for default in ("Here is a short description of the plugin", "This is the long description", "A brief description of the plugin", "Upload the plugin files to the `/wp-content/plugins/plugin-name` directory"):
            if default.lower() in readme.lower():
                rep.add("error", "default_readme_text", "readme.txt still contains template text: '%s...'." % default[:40], readme_path)
        if len(readme.encode()) > 10240:
            rep.add("info", "readme_size", "readme.txt is over 10 KB; consider moving old changelog entries to changelog.txt.", readme_path)
        if len(re.findall(r"[Ѐ-ӿ؀-ۿ぀-ヿ一-鿿฀-๿가-힯]", readme)) > 30 or re.search(r"[ăắằẳẵặâấầẩẫậđêếềểễệôốồổỗộơớờởỡợưứừửữự]{1}.*[ăắằẳẵặâấầẩẫậđêếềểễệôốồổỗộơớờởỡợưứừửữự]", readme):
            rep.add("error", "readme_non_official_language", "readme.txt appears to contain non-English text; it must be written in English.", readme_path)

    # ---------- code scan ----------
    php_files = []
    ajax_handlers = []
    enqueue_hooks = []
    hosts = defaultdict(set)
    globals_found = defaultdict(list)  # kind -> [(name, file, line)]
    has_minified = []
    updater_rx = re.compile(r"EDD_SL_Plugin_Updater|plugin-update-checker|PucFactory|Puc_v\d|pre_set_site_transient_update_plugins|site_transient_update_plugins")
    pro_rx = re.compile(r"\b(is_?[Pp]ro|isPremium|is_premium|hasPro|pro_active|isProActive|can_use_premium_code|__premium_only|fs_is_paying|is_paying|license_?[Kk]ey|licenseStatus|license_status|is_licen[sc]ed|isLicen[sc]ed|days_left|trial_ends?)\b")
    for p in all_files:
        parts = p.split(os.sep)
        ext = os.path.splitext(p)[1].lower()
        if ext in (".php", ".js", ".mjs") and "node_modules" not in parts:
            text = read(os.path.join(root, p))
            # Reviewers scan bundled and scoped vendor code too: an updater anywhere in the zip is flagged.
            if re.search(r"(?i)(plugin[_-]?updater|update[_-]?checker|EDD_SL_)", os.path.basename(p)) or (ext == ".php" and updater_rx.search(text)):
                m = updater_rx.search(text)
                ln = text[: m.start()].count("\n") + 1 if m else 1
                if any(x in SKIP_DIRS for x in parts):
                    rep.add("error", "plugin_updater_detected", "Update checker library ships in the zip (vendor code counts). Remove it from the WordPress.org build.", p, ln)
            # Pro/license flags in PHP and built JS: the manual pass decides whether code is locked (guideline 5).
            hits = [text[: m.start()].count("\n") + 1 for m in pro_rx.finditer(text)]
            if hits:
                inv["pro_license_gates"].append("%s  (%d hits, first line %d)" % (p, len(hits), hits[0]))
        if any(x in SKIP_DIRS for x in parts):
            continue
        if p.endswith((".min.js", ".min.css")) or (ext in (".js", ".css") and ("build" in parts or "dist" in parts)):
            has_minified.append(p)
            continue_minified = True
        else:
            continue_minified = False
        if ext == ".json" and os.path.basename(p) == "block.json":
            try:
                bj = json.loads(read(os.path.join(root, p)))
                if int(bj.get("apiVersion", 1)) < 3:
                    rep.add("error", "block_api_version_too_low", "block.json apiVersion %s; use 3 (WordPress 7.0 iframe editor)." % bj.get("apiVersion", 1), p)
            except Exception:
                pass
        if ext not in CODE_EXT:
            continue
        text = read(os.path.join(root, p))
        is_php = ext == ".php"
        if is_php:
            php_files.append(p)
        if ext == ".js" and not continue_minified:
            first = text[:5000]
            if first.count("\n") < 3 and len(first) > 3000:
                has_minified.append(p)
        lines = text.splitlines()
        for i, line in enumerate(lines, 1):
            if is_comment(line):
                continue
            for pid, sev, rx, msg, php_only in PATTERNS:
                if php_only and not is_php:
                    continue
                if re.search(rx, line):
                    rep.add(sev, pid, msg, p, i, line.strip()[:160])
            for m in URL_RE.finditer(line):
                url = m.group(0)
                host = re.sub(r"^https?://", "", url).split("/")[0].split(":")[0].lower()
                if host in ("localhost", "127.0.0.1", "0.0.0.0") or host.endswith(".local") or host.endswith(".test"):
                    rep.add("error", "localhost", "Local development URL left in code: %s" % url, p, i)
                    continue
                if any(s in url for s in SHORTENERS):
                    rep.add("warning", "short_url", "URL shortener; use the full URL: %s" % url, p, i)
                hosts[host].add("%s:%d" % (p, i))
                if re.search(r"\.(js|css)(\?|$)", url) and not host.endswith(ALLOWED_REMOTE_HOSTS):
                    rep.add("error", "offloading_files", "Remote JS/CSS loaded from %s; bundle it locally (only fonts may be remote)." % host, p, i, line.strip()[:160])
            if is_php:
                for kind, rx in (("function", r"^\s*function\s+&?\s*([A-Za-z_]\w*)\s*\("),
                                 ("class", r"^\s*(?:final\s+|abstract\s+|readonly\s+)*(?:class|interface|trait|enum)\s+([A-Za-z_]\w*)"),
                                 ("namespace", r"^\s*namespace\s+([A-Za-z_][\w\\]*)\s*[;{]"),
                                 ("define", r"\bdefine\s*\(\s*['\"]([A-Za-z_]\w*)['\"]"),
                                 ("option", r"\b(?:(?:add|update|delete)_(?:site_)?option\s*\(|register_setting\s*\(\s*['\"][\w\-]+['\"]\s*,)\s*['\"]([\w\-]+)['\"]"),
                                 ("transient", r"\b(?:set|get|delete)_(?:site_)?transient\s*\(\s*['\"]([\w\-]+)['\"]"),
                                 ("hook", r"\b(?:do_action|apply_filters)\s*\(\s*['\"]([\w\-/]+)['\"]")):
                    m = re.search(rx, line)
                    if m:
                        if kind == "function" and line.startswith((" ", "\t")):
                            continue  # likely a method
                        globals_found[kind].append((m.group(1), p, i))
                m = re.search(r"add_action\s*\(\s*['\"](wp_ajax_(nopriv_)?[\w\-]+|admin_post_(nopriv_)?[\w\-]+)['\"]", line)
                if m:
                    inv["ajax_admin_post_handlers"].append("%s  (%s:%d)" % (m.group(1), p, i))
                if "register_rest_route" in line:
                    window = "\n".join(lines[i - 1:i + 25])
                    if "permission_callback" not in window:
                        rep.add("error", "rest_permission", "register_rest_route() without a permission_callback.", p, i, line.strip()[:160])
                    elif re.search(r"permission_callback['\"]?\s*=>\s*['\"]__return_true", window):
                        inv["rest_routes_public"].append("%s:%d" % (p, i))
                        route_def = window.split("register_rest_route", 2)[1] if window.count("register_rest_route") > 1 else window
                        if re.search(r"POST|PUT|PATCH|DELETE|CREATABLE|EDITABLE|DELETABLE|ALLMETHODS", route_def):
                            rep.add("warning", "rest_public_write", "Public (__return_true) REST route that accepts writes. Reviewers list every __return_true route; add a real check, or justify it in your reply (e.g. a public form) and show the abuse protection (validation, nonce for logged-in users, rate limit).", p, i, line.strip()[:160])
                    inv["rest_routes"].append("%s:%d" % (p, i))
                if re.search(r"\badd_shortcode\s*\(|['\"]render_callback['\"]\s*=>|\badd_filter\s*\(\s*['\"](the_content|the_title|the_excerpt|widget_text|render_block)['\"]", line):
                    inv["output_callbacks"].append("%s:%d  `%s`  (returned HTML must be escaped; shortcode atts are user input)" % (p, i, line.strip()[:100]))
                m = re.search(r"\bregister_post_type\s*\(\s*['\"]([^'\"]+)['\"]", line)
                if m and len(m.group(1)) > 20:
                    rep.add("error", "post_type_key_length", "Post type key '%s' is %d characters; register_post_type() fails above 20 (a long prefix uses up the limit)." % (m.group(1), len(m.group(1))), p, i, line.strip()[:160])
                if re.search(r"\badd_filter\s*\(\s*['\"]admin_body_class['\"]", line):
                    inv["admin_body_class"].append("%s:%d" % (p, i))
                    rep.add("warning", "admin_body_class", "admin_body_class filter: add the class only on the plugin's own screen, or its CSS styles every admin page.", p, i, line.strip()[:160])
                if re.search(r"\b(wp_add_inline_script|wp_print_inline_script_tag)\s*\(", line):
                    call = " ".join(lines[i - 1:i + 6]).split(";")[0]
                    encoded = "wp_json_encode(" in call.replace(" (", "(")
                    if not encoded:
                        for v in re.findall(r"\$\w+", call):
                            for prev in lines[max(0, i - 16):i - 1]:
                                if re.search(r"%s\s*=[^=].*\bwp_json_encode\s*\(" % re.escape(v), prev):
                                    encoded, call = True, call + " " + prev
                    if encoded and "JSON_HEX_TAG" not in call:
                        rep.add("error", "inline_script_json_hex", "wp_json_encode() into an inline script without JSON_HEX_TAG | JSON_HEX_AMP: a value holding </script> closes the tag.", p, i, line.strip()[:160])
                if re.search(r"\bnew\s+WP_Query\s*\(|\bget_posts\s*\(", line):
                    window = " ".join(lines[max(0, i - 13):i + 12])
                    if re.search(r"['\"]post_type['\"]\s*=>\s*(?:array\s*\(|\[)?\s*['\"]product['\"]", window) and not re.search(r"product_visibility|exclude-from-catalog|exclude-from-search|wc_get_product_visibility_term_ids", window):
                        rep.add("warning", "product_query_visibility", "Product query with no catalog-visibility filter: products set to Hidden still show. Exclude 'exclude-from-catalog' (product_visibility), or use wc_get_products( array( 'visibility' => 'catalog' ) ).", p, i, line.strip()[:160])
                if re.search(r"\badd_action\s*\(\s*['\"](admin_notices|all_admin_notices|network_admin_notices)['\"]", line):
                    inv["admin_notices"].append("%s:%d" % (p, i))
                if re.search(r"\bregister_setting\s*\(", line):
                    window = " ".join(lines[i - 1:i + 6])
                    call = window.split(";")[0]
                    if call.count(",") < 2 and "sanitize_callback" not in window:
                        rep.add("error", "setting_sanitization", "register_setting() without a sanitize callback.", p, i, line.strip()[:160])
                if re.search(r"\$wpdb->(query|get_results|get_row|get_var|get_col)\s*\(\s*[\"'].*\$\w+|\$wpdb->(query|get_results|get_row|get_var|get_col)\s*\(\s*\$\w+\s*\)", line) and "prepare" not in line:
                    rep.add("error", "direct_db", "$wpdb query with a variable but no $wpdb->prepare() on this line (verify the SQL string is prepared).", p, i, line.strip()[:160])
                if re.search(r"(file_put_contents|fopen|fwrite|mkdir|WP_Filesystem.*put_contents)\s*\(.*(plugin_dir_path|__DIR__|dirname\s*\(\s*__FILE__)", line):
                    rep.add("error", "write_file", "Writes into the plugin folder (wiped on update); use wp_upload_dir() or the database.", p, i, line.strip()[:160])
                if re.search(r"wp_remote_(get|post|request|head)|wp_safe_remote_|WP_Http|wp_remote_", line):
                    inv["http_calls"].append("%s:%d" % (p, i))
                if re.search(r"\$_(POST|GET|REQUEST|COOKIE|SERVER|FILES)\b", line):
                    inv["superglobal_uses"].append("%s:%d" % (p, i))
                    if re.search(r"\$_(POST|GET|REQUEST|COOKIE|SERVER)\s*\[", line) and not re.search(r"\b(sanitize_\w+|absint|intval|floatval|wp_unslash|isset|empty|wp_verify_nonce|check_admin_referer|check_ajax_referer|esc_\w+|wp_kses\w*|in_array|array_key_exists|is_numeric|boolval|\(int\)|\(bool\)|\(float\))\s*\(?", line):
                        rep.add("error", "unsanitized_input", "Request data used without sanitizing/validating (sanitize early: wp_unslash + sanitize_*; validate allowed values).", p, i, line.strip()[:160])
                block_safe = os.path.basename(p) == "render.php" and re.search(r"\becho\s*\(?\s*\$\w*(content|wrapper_attributes)\s*\)?\s*;", line)
                if block_safe:
                    pass  # block render.php: $content and get_block_wrapper_attributes() output are already safe
                elif re.search(r"\becho\s*\(?\s*(\$\w+|get_option\s*\(|get_post_meta\s*\(|get_the_\w+\s*\(|\$_)", line) or re.search(r"\becho\s+['\"][^;]*['\"]\s*\.\s*\$", line):
                    rep.add("error", "unescaped_output", "Output not escaped at the point of echo (escape late: esc_html/esc_attr/esc_url/wp_kses_post).", p, i, line.strip()[:160])
            else:
                if re.search(r"\bfetch\s*\(\s*['\"`]https?://|axios\.(get|post)\s*\(\s*['\"`]https?://|XMLHttpRequest", line):
                    inv["http_calls"].append("%s:%d" % (p, i))

        if is_php:
            for m in re.finditer(r"add_action\s*\(\s*['\"](wp_ajax_(?:nopriv_)?[\w\-]+|admin_post_(?:nopriv_)?[\w\-]+)['\"]\s*,\s*['\"]([A-Za-z_]\w*)['\"]", text):
                ajax_handlers.append((m.group(1), m.group(2), p))
            for m in re.finditer(r"add_action\s*\(\s*['\"](admin_enqueue_scripts|wp_enqueue_scripts|enqueue_block_assets)['\"]\s*,\s*(?:['\"]([A-Za-z_]\w*)['\"]|(?:array\s*\(|\[)\s*\$this\s*,\s*['\"]([A-Za-z_]\w*)['\"])", text):
                enqueue_hooks.append((m.group(1), m.group(2) or m.group(3), p, text[: m.start()].count("\n") + 1))
            if re.search(r"\$_POST\s*\[", text) and not re.search(r"wp_verify_nonce|check_admin_referer|check_ajax_referer|settings_fields|wp_nonce_field", text):
                rep.add("error", "nonce_missing", "File reads $_POST but contains no nonce creation/verification at all.", p)
            # ob_start() must be closed in the same function (team: "Unclosed ob_start()")
            for m in re.finditer(r"\bob_start\s*\(", text):
                rest = text[m.end():]
                nxt = re.search(r"\n\s*(?:public\s+|private\s+|protected\s+|static\s+)*function\s+\w+\s*\(", rest)
                body = rest[: nxt.start() if nxt else len(rest)]
                if not re.search(r"\bob_(get_clean|end_clean|end_flush|get_flush)\s*\(", body):
                    rep.add("warning", "unclosed_ob_start", "ob_start() with no ob_get_clean()/ob_end_*() later in the same function. Close it in the same scope with nothing (hooks, early returns, filters) able to skip the close; to change the whole page use the WP 6.9 template enhancement output buffer instead.", p, text[: m.start()].count("\n") + 1)
            base = os.path.basename(p)
            if base == "uninstall.php" and "WP_UNINSTALL_PLUGIN" not in text:
                rep.add("error", "uninstall_missing_constant_check", "uninstall.php must check defined( 'WP_UNINSTALL_PLUGIN' ).", p)
            stripped = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
            code_lines = [l for l in stripped.splitlines() if l.strip() and not l.strip().startswith(("//", "#", "<?php", "?>", "namespace", "use ", "declare"))]
            guarded = re.search(r"defined\s*\(\s*['\"](ABSPATH|WPINC|WP_UNINSTALL_PLUGIN)['\"]\s*\)", text)
            only_decls = code_lines and re.match(r"\s*(final\s+|abstract\s+)?(class|interface|trait|enum)\b", code_lines[0])
            if not guarded and code_lines and not only_decls:
                rep.add("error", "direct_file_access", "No ABSPATH guard; add `if ( ! defined( 'ABSPATH' ) ) exit;` at the top.", p, 1)

    # text domains: Plugin Check's i18n check scans everything except vendor/ and node_modules/,
    # so scoped copies (vendor-prefixed/, vendor_prefixed/) count as your code.
    gettext = re.compile(r"\b(__|_e|_x|_ex|_n|_nx|esc_html__|esc_html_e|esc_attr__|esc_attr_e|esc_html_x|esc_attr_x|_n_noop|_nx_noop)\s*\(")
    domain_hits = defaultdict(list)
    for p in all_files:
        parts = p.split(os.sep)
        if not p.endswith(".php") or "vendor" in parts or "node_modules" in parts:
            continue
        for i, line in enumerate(read(os.path.join(root, p)).splitlines(), 1):
            if is_comment(line) or not gettext.search(line):
                continue
            for g in gettext.finditer(line):
                # args of this call up to its closing paren (no nested calls inside gettext args)
                call = re.match(r"[^()]*\)", line[g.end():])
                if not call:
                    continue
                m = re.search(r",\s*['\"]([A-Za-z0-9_\-]+)['\"]\s*\)$", call.group(0))
                if m and m.group(1) != slug:
                    domain_hits[m.group(1)].append((p, i, line.strip()[:160]))
            if re.search(r"\b(__|_e|_x|_ex|_n|_nx|esc_html__|esc_html_e|esc_attr__|esc_attr_e|esc_html_x|esc_attr_x)\s*\([^()]*,\s*\$\w+\s*\)", line):
                rep.add("error", "i18n_variable_domain", "Text domain passed as a variable; it must be the literal string '%s'." % slug, p, i, line.strip()[:160])
    for dom, hits in domain_hits.items():
        if dom in ("default",):
            continue
        for p, i, snip in hits:
            rep.add("error", "i18n_textdomain_mismatch", "Text domain '%s' must be '%s' (%d calls use '%s'; scoped vendor copies count)." % (dom, slug, len(hits), dom), p, i, snip)

    # Composer autoloaders that still map stripped files or updater/licensing classes
    for cm in ("vendor/composer/autoload_classmap.php", "vendor/composer/autoload_static.php", "vendor/composer/autoload_psr4.php"):
        full = os.path.join(root, cm)
        if not os.path.exists(full):
            continue
        missing, updater = 0, []
        for i, line in enumerate(read(full).splitlines(), 1):
            if re.search(r"EDD_SL_Plugin_Updater|PluginUpdateChecker|Puc_v\d|\\License\\|LicenseHandler|LicenseAPI", line):
                updater.append(i)
            m = re.search(r"\$(baseDir|vendorDir)\s*\.\s*'([^']+\.php)'", line)
            if m:
                target = m.group(2).lstrip("/")
                target = target if m.group(1) == "baseDir" else os.path.join("vendor", target)
                if not os.path.exists(os.path.join(root, target)):
                    missing += 1
        if updater:
            rep.add("error", "plugin_updater_detected", "%s still lists updater/licensing classes (%d entries, e.g. line %d); regenerate the autoloader after stripping them." % (cm, len(updater), updater[0]), cm, updater[0])
        if missing:
            rep.add("warning", "stale_autoloader", "%s maps %d classes to files that are not in the plugin; run `composer dump-autoload` after the build strips files." % (cm, missing), cm)

    # AJAX / admin-post handlers: nonce + capability inside the callback
    all_php = {p: read(os.path.join(root, p)) for p in php_files}

    def function_body(fn, fallback):
        for fp, t in all_php.items():
            m = re.search(r"function\s+%s\s*\(" % re.escape(fn), t)
            if m:
                rest = t[m.end():]
                nxt = re.search(r"\n\s*(?:public\s+|private\s+|protected\s+|static\s+)*function\s+\w+\s*\(", rest)
                return rest[: nxt.start() if nxt else 6000], "%s:%d" % (fp, t[: m.start()].count("\n") + 1)
        return None, fallback

    # Enqueue callbacks that load on every screen (Q3): admin ones need a $hook_suffix or screen check,
    # front-end ones a condition for the pages that use the assets.
    for hook, fn, hp, hl in enqueue_hooks:
        body, where = function_body(fn, "%s:%d" % (hp, hl))
        if body is None:
            continue
        if hook == "admin_enqueue_scripts":
            scoped = re.search(r"\$hook|hook_suffix|get_current_screen|\$screen|\$_GET\s*\[\s*['\"]page['\"]|\$pagenow|\$page\b", body)
        else:
            scoped = re.search(r"\bif\s*\(|\breturn\b|\?\s*:", body) or re.search(r"\bis_\w+\s*\(|has_block|has_shortcode", body)
        if not scoped:
            inv["enqueue_everywhere"].append("%s -> %s()  (%s)" % (hook, fn, where))
            rep.add("warning", "enqueue_scope", "%s() on '%s' enqueues on every %s; load assets only where they're used (check $hook_suffix or the page)." % (fn, hook, "admin screen" if hook == "admin_enqueue_scripts" else "page"), where.split(":")[0], int(where.split(":")[1]))

    for hook, fn, hp in ajax_handlers:
        body, where = function_body(fn, hp)
        if body is None:
            continue
        nonce = re.search(r"check_ajax_referer|wp_verify_nonce|check_admin_referer", body)
        cap = re.search(r"current_user_can", body)
        public = "nopriv" in hook
        if not nonce:
            rep.add("error", "ajax_nonce", "Handler %s() for '%s' does not verify a nonce." % (fn, hook), where.split(":")[0], int(where.split(":")[1]))
        if not cap and not public:
            rep.add("error", "ajax_capability", "Handler %s() for '%s' has no current_user_can() check (a nonce alone is not authorization)." % (fn, hook), where.split(":")[0], int(where.split(":")[1]))
        if public:
            inv["public_nopriv_handlers"].append("%s -> %s()  (%s)  review: must not change data or expose private info" % (hook, fn, where))

    # minified code needs public source
    if has_minified:
        # only source that actually ships counts (a src/ removed by .distignore does not)
        src_dirs = [d for d in ("src", "assets/src", "resources", "source", "blocks/src") if any(f.startswith(d + os.sep) and f.endswith((".js", ".jsx", ".ts", ".tsx", ".scss", ".vue")) for f in all_files)]
        repo_link = re.search(r"(github\.com|gitlab\.com|bitbucket\.org)/[\w\-]+/[\w\-.]+", readme)
        if not src_dirs and not repo_link:
            rep.add("error", "no_public_source", "%d minified/built files (%s%s) but no shipped source folder and no public repository link in readme.txt. Add a '== Source code ==' readme section with the repo URL and build steps." % (len(has_minified), ", ".join(has_minified[:3]), "..." if len(has_minified) > 3 else ""))
        elif src_dirs and not repo_link and not re.search(r"source code|src/", readme, re.I):
            rep.add("warning", "no_public_source", "Source ships in %s/ but readme.txt doesn't say so; the team asks you to document where the source of the built files is, plus build steps." % src_dirs[0])
        elif not repo_link and not re.search(r"npm (run )?build|npm install|yarn build|composer install|webpack|wp-scripts", readme, re.I):
            rep.add("warning", "no_build_instructions", "Built files are present; add build instructions (and a repo link) in readme.txt.")

    # external services documentation
    readme_l = readme.lower()
    ignore_hosts = ("wordpress.org", "w.org", "gnu.org", "www.gnu.org", "opensource.org", "example.com", "example.org", "schema.org", "www.w3.org", "w3.org", "github.com", "php.net", "developer.wordpress.org", "make.wordpress.org", "gravatar.com", "s.w.org", "ps.w.org", "schemas.wp.org", "fonts.googleapis.com", "fonts.gstatic.com")
    own_host = re.sub(r"^https?://", "", headers.get("Plugin URI", "") + " " + headers.get("Author URI", ""))
    ext_hosts = {h: sorted(v) for h, v in hosts.items() if not h.endswith(ignore_hosts)}
    if ext_hosts:
        undocumented = []
        for h in sorted(ext_hosts):
            core = ".".join(h.split(".")[-2:])
            if core not in readme_l:
                undocumented.append(h)
        has_section = re.search(r"^==\s*(external services|third[- ]party services|3rd party|external)\b", readme, re.M | re.I)
        if inv["http_calls"] and not has_section:
            rep.add("error", "external_services", "Plugin makes HTTP requests but readme.txt has no '== External services ==' section (what service, what data, when, ToS + privacy links).")
        for h in undocumented:
            ref = ext_hosts[h][0]
            note = " (your own domain still counts)" if h in own_host else ""
            rep.add("warning", "external_services", "Host '%s' appears in code but not in readme.txt%s. If the plugin contacts it, document it; if it is only a link, ignore." % (h, note), ref.split(":")[0], int(ref.split(":")[1]))
    inv["external_hosts"] = ["%s  (%s)" % (h, ", ".join(v[:3]) + (" ..." if len(v) > 3 else "")) for h, v in sorted(ext_hosts.items())]

    # prefixing
    names = []
    for kind in ("function", "class", "define", "option", "transient", "hook"):
        for n, f, l in globals_found[kind]:
            names.append((kind, n, f, l))
    pref_counter = Counter()
    for kind, n, f, l in names:
        tok = re.split(r"[_\-]", n.lower())[0] if kind != "class" else re.split(r"[_\-]|(?<=[a-z])(?=[A-Z])", n)[0].lower()
        if tok:
            pref_counter[tok] += 1
    ns = sorted({n for n, _, _ in globals_found["namespace"]})
    dominant = pref_counter.most_common(1)[0][0] if pref_counter else None
    inv["prefix_summary"] = ["namespaces: %s" % (", ".join(ns) or "none"), "most common name prefix: %s (%s)" % (dominant, ", ".join("%s=%d" % kv for kv in pref_counter.most_common(5)))]
    if dominant and len(dominant) < 4 and not ns:
        rep.add("warning", "prefixing", "Dominant prefix '%s' is shorter than 4 characters; short prefixes are no longer accepted." % dominant)
    generic = re.compile(r"^(wp_|_|__|get_|set_|init$|setup$|settings$|options$|admin$|my_|plugin_|custom_|enqueue_|load_|register_|add_|save_|ajax_|helper|utils?$|main$|core$)", re.I)
    for kind, n, f, l in names:
        lowered = n.lower()
        if kind == "hook" and lowered.startswith(("wp_", "admin_", "init", "save_post", "the_", "woocommerce_")):
            continue  # likely firing/consuming a core hook name
        if ns and kind in ("function", "class"):
            continue
        if dominant and lowered.startswith((dominant + "_", dominant + "-")) or (kind == "class" and lowered.startswith(dominant or "\0")):
            continue
        if generic.search(n) or (dominant and pref_counter[dominant] >= 3):
            rep.add("warning", "prefixing", "%s '%s' is not uniquely prefixed (expected '%s_' or a namespace)." % (kind.capitalize(), n, dominant or "yourprefix"), f, l)

    # function_exists wrappers
    fe = sum(read(os.path.join(root, p)).count("function_exists") for p in php_files)
    if fe > 5:
        rep.add("warning", "prefixing", "%d function_exists() wrappers; wrapping your own functions this way is flagged (it's for shared libraries)." % fe)

    # ---------- output ----------
    order = {"error": 0, "warning": 1, "info": 2}
    rep.items.sort(key=lambda x: (order[x["severity"]], x["id"], x["check"], x["file"] or "", x["line"] or 0))
    result = {
        "plugin_dir": root, "reviewed": src, "from_zip": from_zip, "slug": slug, "main_file": main_file, "headers": headers,
        "counts": dict(Counter(i["severity"] for i in rep.items)),
        "findings": rep.items, "inventory": {k: v for k, v in inv.items() if v},
    }
    if args.json:
        print(json.dumps(result, indent=1))
        return
    print("# Static precheck: %s (slug: %s)\n" % (headers.get("Plugin Name", slug), slug))
    print("Reviewed: %s%s\n" % (src, " (zip contents)" if from_zip else ""))
    print("Main file: %s | Version %s | errors %d, warnings %d\n" % (main_file, headers.get("Version", "?"), result["counts"].get("error", 0), result["counts"].get("warning", 0)))
    grouped = defaultdict(list)
    for it in rep.items:
        grouped[(it["severity"], it["check"])].append(it)
    for (sev, check), its in grouped.items():
        print("## [%s] %s %s (%d)" % (sev.upper(), its[0]["id"] or "-", check, len(its)))
        same = len({it["message"] for it in its}) == 1
        if same:
            print("  %s" % its[0]["message"])
        for it in its[:25]:
            loc = it["file"] + (":%d" % it["line"] if it["line"] else "") if it["file"] else ""
            parts = [loc] if loc else []
            if not same:
                parts.append(it["message"])
            if it["snippet"]:
                parts.append("`%s`" % it["snippet"])
            if parts:
                print("  - " + "  ".join(parts))
        if len(its) > 25:
            print("  - ... and %d more" % (len(its) - 25))
        print()
    print("# Inventory for the manual pass\n")
    for k, v in result["inventory"].items():
        print("## %s (%d)" % (k, len(v)))
        for x in v[:40]:
            print("  - %s" % x)
        if len(v) > 40:
            print("  - ... and %d more" % (len(v) - 40))
        print()


if __name__ == "__main__":
    main()
