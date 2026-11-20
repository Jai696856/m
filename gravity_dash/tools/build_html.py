"""Swap a freshly exported game pack into the single-file Gravity Dash HTML.

Usage: python3 tools/build_html.py <template.html> <index.pck> <out.html>
The template is any earlier single-file build; its embedded engine is reused.
Export the pack with: godot --headless --export-pack "Web" index.pck
"""
import base64, gzip, re, sys

template, pck, out = sys.argv[1:4]
html = open(template, encoding="utf-8").read()
data = base64.b64encode(gzip.compress(open(pck, "rb").read(), 9)).decode()
html, n = re.subn(r'(<script id="game-data" type="text/plain">).*?(</script>)',
                  lambda m: m.group(1) + data + m.group(2), html, count=1, flags=re.S)
assert n == 1, "game-data block not found in template"
open(out, "w", encoding="utf-8").write(html)
print("wrote", out)
