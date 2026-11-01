# Builds docs/store/privacy-policy-blogger.html from 03-privacy-policy.md.
import html, re, sys
src, out = sys.argv[1], sys.argv[2]
text = open(src, encoding='utf-8').read()
body = text.split('\n---\n', 1)[1]  # drop the internal note at the top

def inline(s):
    s = html.escape(s, quote=False)
    s = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', s)
    s = re.sub(r'`(.+?)`', r'<code>\1</code>', s)
    s = re.sub(r'(https?://[^\s<)]+)', r'<a href="\1" rel="nofollow">\1</a>', s)
    return s

TABLE = 'style="border-collapse:collapse;width:100%;margin:8px 0 16px"'
CELL = 'style="border:1px solid #d0d7de;padding:6px 8px;vertical-align:top;text-align:start"'
out_lines, i = [], 0
lines = body.split('\n')
lang_ids = {'English': 'en', 'বাংলা': 'bn'}
while i < len(lines):
    l = lines[i]
    if l.startswith('## '):
        name = l[3:].strip()
        if out_lines:
            out_lines.append('</div>')
        lid = lang_ids.get(name, 'x')
        d = ' dir="ltr"' if lid == 'en' else ''
        out_lines.append(f'<div id="{lid}" lang="{lid}"{d}>')
        out_lines.append(f'<h2 style="margin-top:28px">{inline(name)}</h2>')
    elif l.startswith('### '):
        out_lines.append(f'<h3 style="margin:20px 0 6px">{inline(l[4:])}</h3>')
    elif l.startswith('|'):
        rows = []
        while i < len(lines) and lines[i].startswith('|'):
            rows.append([c.strip() for c in lines[i].strip('|').split('|')])
            i += 1
        i -= 1
        head, data = rows[0], [r for r in rows[2:]]
        out_lines.append(f'<table {TABLE}><thead><tr>' + ''.join(f'<th {CELL}>{inline(c)}</th>' for c in head) + '</tr></thead><tbody>')
        for r in data:
            out_lines.append('<tr>' + ''.join(f'<td {CELL}>{inline(c)}</td>' for c in r) + '</tr>')
        out_lines.append('</tbody></table>')
    elif re.match(r'^- ', l):
        # Top-level items; "  - " lines nest under the previous item and
        # "  text" lines continue it.
        items = []
        while i < len(lines) and (re.match(r'^- ', lines[i]) or (lines[i].startswith('  ') and items) or (not lines[i].strip() and i + 1 < len(lines) and lines[i+1].startswith('  ') and items)):
            cur = lines[i]
            if cur.startswith('- '):
                items.append({'text': cur[2:].strip(), 'sub': [], 'more': []})
            elif cur.strip().startswith('- '):
                items[-1]['sub'].append(cur.strip()[2:])
            elif cur.strip():
                items[-1]['more'].append(cur.strip())
            i += 1
        i -= 1
        parts = []
        for it in items:
            h = inline(it['text'])
            if it['sub']:
                h += '<ul>' + ''.join(f'<li>{inline(x)}</li>' for x in it['sub']) + '</ul>'
            if it['more']:
                h += '<p style="margin:4px 0">' + inline(' '.join(it['more'])) + '</p>'
            parts.append(f'<li>{h}</li>')
        out_lines.append('<ul>' + ''.join(parts) + '</ul>')
    elif l.strip() == '---' or not l.strip():
        pass
    else:
        para = [l.strip()]
        while i + 1 < len(lines) and lines[i+1].strip() and not re.match(r'^(#|\||\s*- |---)', lines[i+1]):
            i += 1
            para.append(lines[i].strip())
        out_lines.append('<p>' + inline(' '.join(para)) + '</p>')
    i += 1
out_lines.append('</div>')

header_meta = [l for l in text.split('\n---\n', 1)[0].split('\n') if l.startswith('**')]
meta = '<br>'.join(inline(m) for m in header_meta)
page = f'''<!-- Pahara privacy policy for Blogger.
     Generated from docs/store/03-privacy-policy.md: edit that file, then
     regenerate. Paste this whole file into a Blogger PAGE in HTML view. -->
<div style="font-family:system-ui,-apple-system,'Segoe UI',Roboto,'Noto Sans Bengali',sans-serif;line-height:1.6;max-width:780px;margin:0 auto;color:#1f2328">
<h1 style="margin-bottom:4px">Pahara – Privacy Policy</h1>
<p style="margin-top:0;color:#57606a">Exam Hall Security · পাহারা – গোপনীয়তা নীতি</p>
<p>{meta}</p>
<p><a href="#en">English</a> · <a href="#bn">বাংলা</a></p>
{chr(10).join(out_lines)}
</div>
'''
open(out, 'w', encoding='utf-8').write(page)
print('ok', len(page))
