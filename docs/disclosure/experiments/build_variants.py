import re, json, base64, subprocess, sys, time
h = open('report.html', encoding='utf-8').read()
m = re.search(r'(<script>\n)(.*)(</script>\s*</body>)', h, re.S)
head, js, tail = h[:m.start(2)], m.group(2), h[m.end(2):]
PROBE = ('<script>window.addEventListener("load",function(){setTimeout(function(){'
         'var f=document.querySelector(".fatal");document.title="PROBE:"+(f?"FATAL":"OK")+":"+'
         'document.querySelectorAll("#app *").length+":"+document.querySelectorAll("#app td").length+":"+Math.round(performance.now())'
         '+":micro="+(window.TR&&TR.MICRO?TR.MICRO.n:"null")+":agg="+(window.TR&&TR.AGG?Object.keys(TR.AGG).length:"null")},2500)})</script>')
def emit(name, jstext, html_head=head):
    body = jstext.replace('</script>', '<\\/script>')
    out = html_head + body + tail.replace('</body>', PROBE + '</body>', 1)
    open(name, 'w', encoding='utf-8').write(out)
    print(name, len(out))
emit('v_dev.html', js)
for p in ['p0','p1','p2']:
    emit(f'v_{p}.html', open(f'{p}.js', encoding='utf-8').read())

# ---- island-encoding prototype: LCG keystream XOR + base64, decoder patched into parseIsland
def keystream(seed, n):
    x = seed; out = bytearray(n)
    for i in range(n):
        x = (1664525 * x + 1013904223) % 4294967296
        out[i] = x >> 24
    return bytes(out)
def encode(txt, seed):
    b = txt.encode('utf-8'); k = keystream(seed, len(b))
    return base64.b64encode(bytes(a ^ c for a, c in zip(b, k))).decode('ascii')
DECODER = r'''function parseIsland(id) {
    var el = document.getElementById(id);
    if (!el) return null;
    try {
      var txt = el.textContent, seed = el.getAttribute("data-k");
      if (seed) {
        var bin = atob(txt.trim()), n = bin.length, out = new Uint8Array(n), x = parseInt(seed, 10);
        for (var i = 0; i < n; i++) { x = (1664525 * x + 1013904223) % 4294967296; out[i] = bin.charCodeAt(i) ^ (x >>> 24); }
        txt = new TextDecoder("utf-8").decode(out);
      }
      return JSON.parse(txt);
    } catch (e) { return null; }
  }'''
assert 'function parseIsland(id) {' in js
js_enc = re.sub(r'function parseIsland\(id\) \{.*?\n  \}', DECODER, js, count=1, flags=re.S)
assert js_enc != js
open('bundle_enc.js', 'w', encoding='utf-8').write(js_enc)
# encode every non-null data island in the head
seed = 305419896
def enc_island(mo):
    ident, body = mo.group(1), mo.group(2).strip()
    if body == 'null' or ident == 'user-state': return mo.group(0)
    return f'<script type="application/json" id="{ident}" data-k="{seed}">\n{encode(body, seed)}\n</script>'
head_enc, nsub = re.subn(r'<script type="application/json" id="([^"]+)">\s*(.*?)\s*</script>', enc_island, head, flags=re.S)
print('islands encoded:', nsub)
subprocess.run(['/opt/homebrew/bin/terser','--compress','passes=2,dead_code=true,drop_console=false','--mangle','toplevel=false','--no-mangle-props','--comments','some','--output','beautify=false','bundle_enc.js','-o','t_enc.js'], check=True)
subprocess.run(['/opt/homebrew/bin/javascript-obfuscator','t_enc.js','--output','p1_enc.js','--config','p1.json'], check=True, capture_output=True)
emit('v_p1_enc.html', open('p1_enc.js', encoding='utf-8').read(), head_enc)
# the first-look attack, re-run against the encoded file
h2 = open('v_p1_enc.html', encoding='utf-8').read()
mm = re.search(r'<script type="application/json" id="data-micro"[^>]*>\s*(.*?)\s*</script>', h2, re.S)
try: json.loads(mm.group(1)); print('ATTACK: json.loads on data-micro SUCCEEDED (bad)')
except Exception as e: print('ATTACK: json.loads on data-micro failed:', type(e).__name__, '| first 60 chars:', mm.group(1)[:60])
print('grep for a label in file:', 'KwaZulu' in h2, '| in dev:', 'KwaZulu' in h)
