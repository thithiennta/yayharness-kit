#!/usr/bin/env bash
# SessionStart: tell Claude when this repo's harness is older than the kit.
. "$(dirname "$0")/_hook.sh"
. "$YAY_LIB_DIR/harness.sh"
cwd="$(hook_get cwd)"; [ -n "$cwd" ] || cwd="$PWD"
hook_use_repo "$cwd"
st="$(yay_harness_status)"
case "$st" in
  outdated*) echo "yay: this repo's harness is ${st#outdated } (kit-owned files are older than the installed yay plugin). Suggest running /yay:harness-update before other work." ;;
  no-manifest) echo "yay: .yay/config.json exists but .yay/manifest.json doesn't. Suggest /yay:harness-update to install the kit files." ;;
esac
exit 0
