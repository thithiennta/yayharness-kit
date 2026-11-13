
Got this back from wordpress.org for event-countdown-kit. Please fix everything they want and write me the reply to send back.

---
Subject: [WordPress Plugin Directory] Review in Progress: Event Countdown Kit

There are issues with your plugin code preventing it from being approved immediately. We have pended your submission in order to help you correct all issues so that it may be approved and published.

## Variables and options must be escaped when echo'd

Much related to sanitizing everything, all variables that are echoed need to be escaped when they're echoed, so it can't hijack users or (worse) admin screens.

Example(s) from your plugin:
includes/shortcode.php:15 <div class="eck-countdown" data-date="<?php echo $atts['date']; ?>">

## Generic function/class/define/namespace/option names

All plugins must have unique function names, namespaces, defines, class and option names.

Example(s) from your plugin:
event-countdown-kit.php:22 function get_countdown_settings() {

## Undocumented use of a 3rd Party / external service

Plugins are permitted to require the use of third party/external services as long as they are clearly documented.

Example(s) from your plugin:
includes/shortcode.php:30 wp_remote_get( 'https://date.nager.at/api/v3/PublicHolidays/' ...

Please make sure that you fix all instances of these issues, not just the examples. When you're done, upload the fixed version and reply to this email.
---
