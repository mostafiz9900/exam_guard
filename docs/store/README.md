# Pahara — App Store and Google Play documents

App: **Pahara** · Subtitle: **Exam Hall Security** · ID: **`com.it24617.pahara.app`**
Version 1.0.0 · Prepared 2026-11-01

| # | Document | Use it for |
|---|---|---|
| 01 | [Play Store listing](01-play-store-listing.md) | Title, short and full description in English, বাংলা and العربية; category; what's new |
| 02 | [App Store listing](02-app-store-listing.md) | Name, subtitle, promo text, description, keywords |
| 03 | [Privacy policy (source)](03-privacy-policy.md) | Readable policy, English + বাংলা |
| — | [privacy-policy-blogger.html](privacy-policy-blogger.html) | **Paste into Blogger** (generated from 03) |
| 04 | [Data safety and App Privacy](04-data-safety-and-app-privacy.md) | Play Data safety form and Apple privacy label answers |
| 05 | [Content rating](05-content-rating.md) | IARC questionnaire, target audience, Apple age rating |
| 06 | [Permissions and review notes](06-permissions-and-review-notes.md) | Why each permission is needed; notes for the reviewers |
| 07 | [Graphics and screenshots](07-graphics-and-screenshots.md) | Required sizes, icon idea, screenshot plan with captions |
| 08 | [Release checklist](08-release-checklist.md) | **Blockers** (icon, signing, license), build commands, order |
| 09 | [Blogger setup](09-blogger-setup.md) | Publishing the privacy policy and support pages |

## Placeholders to fill

Search for `{{` in this folder and replace these:

| Placeholder | What to put |
|---|---|
| `{{DEVELOPER_NAME}}` | Your name or company, exactly as on the developer accounts |
| `{{DEVELOPER_ADDRESS}}` | Postal address (Play shows it for organisation accounts) |
| `{{SUPPORT_EMAIL}}` | Public support email |
| `{{EFFECTIVE_DATE}}` | Date the policy goes live, e.g. 1 November 2026 |
| `{{PRIVACY_URL}}` | Blogger privacy policy page URL |
| `{{SUPPORT_URL}}` | Blogger support page URL |
| `{{WEBSITE_URL}}` | Blogger home page (or your site) |
| `{{CONTACT_NAME}}`, `{{CONTACT_PHONE}}` | Apple's App Review contact |

## Keep in sync with the code

These documents describe version 1.0.0. Update them when a release:
- adds a permission, SDK or network call → 03, 04, 06;
- adds a big feature → 01, 02, 07.

To regenerate the Blogger HTML after editing 03, run:

```sh
python3 docs/store/tools/make_policy_html.py docs/store/03-privacy-policy.md docs/store/privacy-policy-blogger.html
```
