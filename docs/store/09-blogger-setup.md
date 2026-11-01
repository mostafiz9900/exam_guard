# Publishing the privacy policy and support page on Blogger

Both stores need a public web page for the privacy policy, and Apple also
needs a support page. Blogger (free, run by Google) works for both.

## 1. Create the blog (once)

1. Go to https://www.blogger.com and sign in with the Google account you want to own it.
2. **New blog**:
   - Title: `Pahara – Exam Hall Security`
   - Address: e.g. `pahara-app.blogspot.com`
3. **Settings**:
   - **Privacy → Visible to search engines: On**. Store reviewers must be able to open the page.
   - **Basic → Description**: `Pahara helps exam invigilators find hidden wireless devices in exam halls.`
   - **Comments → Comment location: Hide**.

## 2. Privacy policy page

1. **Pages → New page**. Use a *Page*, not a Post, so the URL stays fixed.
2. Title: `Privacy Policy`
3. Click the **pencil icon → HTML view**. Paste the whole contents of [privacy-policy-blogger.html](privacy-policy-blogger.html).
4. Before publishing, replace `{{EFFECTIVE_DATE}}`, `{{DEVELOPER_NAME}}`, `{{SUPPORT_EMAIL}}` and `{{DEVELOPER_ADDRESS}}` in the pasted text.
5. **Options → Reader comments: Don't allow.**
6. **Publish.** The URL looks like `https://pahara-app.blogspot.com/p/privacy-policy.html`. That is your `{{PRIVACY_URL}}`.
7. Open the URL in a private browser window and check that both the English and the Bangla parts show.

> To edit the policy later, edit [03-privacy-policy.md](03-privacy-policy.md), regenerate the HTML (or edit both by hand), then paste again. Change the effective date.

## 3. Support page (Apple needs one)

**Pages → New page → "Support"**. In HTML view, paste:

```html
<div style="font-family:system-ui,-apple-system,'Segoe UI',Roboto,'Noto Sans Bengali',sans-serif;line-height:1.6;max-width:780px;margin:0 auto">
<h2>Pahara – Support</h2>
<p>Questions, problems or ideas? Email <a href="mailto:{{SUPPORT_EMAIL}}">{{SUPPORT_EMAIL}}</a>. We usually reply within 2 working days.</p>
<h3>Common questions</h3>
<p><strong>A device is not found.</strong> Pahara finds devices that are switched on and transmitting. Turn on Bluetooth (and Location on Android). On iPhone, classic Bluetooth and Wi-Fi scanning are not available.</p>
<p><strong>Is my data uploaded?</strong> No. Pahara has no servers. See the <a href="{{PRIVACY_URL}}">Privacy Policy</a>.</p>
<p><strong>Sensor nodes.</strong> Sensor nodes are optional ESP32 boxes. In the app open Sensor nodes for the shopping list and setup guide.</p>
<hr>
<h3>সহায়তা (বাংলা)</h3>
<p>প্রশ্ন বা সমস্যা হলে ইমেইল করুন: <a href="mailto:{{SUPPORT_EMAIL}}">{{SUPPORT_EMAIL}}</a></p>
<p>ডিভাইস না পেলে ব্লুটুথ (অ্যান্ড্রয়েডে লোকেশনও) চালু আছে কিনা দেখুন। পাহারা কোনো তথ্য সার্ভারে পাঠায় না।</p>
</div>
```

That page's URL is `{{SUPPORT_URL}}`. The blog home page can be
`{{WEBSITE_URL}}`.

## 4. Store fields that use these URLs

| Console | Field | URL |
|---|---|---|
| Play Console | Store settings → Privacy policy | `{{PRIVACY_URL}}` |
| Play Console | Store listing → Website (optional) | `{{WEBSITE_URL}}` |
| App Store Connect | App Information → Privacy Policy URL | `{{PRIVACY_URL}}` |
| App Store Connect | Version → Support URL | `{{SUPPORT_URL}}` |
