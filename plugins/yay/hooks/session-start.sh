#!/usr/bin/env bash
# SessionStart: load the kit's code rules into every yay repo session, and tell
# Claude when this repo's harness is older than the kit. Stdout becomes context.
. "$(dirname "$0")/_hook.sh"
. "$YAY_LIB_DIR/harness.sh"
cwd="$(hook_get cwd)"; [ -n "$cwd" ] || cwd="$PWD"
hook_use_repo "$cwd"
# The rules ship with the plugin rather than as a synced repo file, so every yay repo
# follows the installed kit's rules without waiting for /yay:harness-update.
echo "yay code rules (loaded by the yay plugin for this repo):"
sed -e '1,/^$/d' "$YAY_KIT_ROOT/reference/code-rules.md"
st="$(yay_harness_status)"
case "$st" in
  outdated*) echo "yay: this repo's harness is ${st#outdated } (kit-owned files are older than the installed yay plugin). Suggest running /yay:harness-update before other work." ;;
  no-manifest) echo "yay: .yay/config.json exists but .yay/manifest.json doesn't. Suggest /yay:harness-update to install the kit files." ;;
esac
exit 0
