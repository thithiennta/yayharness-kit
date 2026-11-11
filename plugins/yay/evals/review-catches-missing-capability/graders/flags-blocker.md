---
type: llm
weight: 2
---

The reply reports, as a blocker or security finding, that the admin_post_giftly_save handler in includes/Settings.php (Settings::save) changes an option without checking a capability (such as current_user_can( 'manage_woocommerce' ) or 'manage_options') and without verifying a nonce (check_admin_referer or wp_verify_nonce), and says how to fix it. It does not edit the code.
