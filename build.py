# build.py: inline leads.json (and the public Supabase URL + anon key from supabase.json) into template.html -> index.html
import json, os
os.chdir(os.path.dirname(os.path.abspath(__file__)))
leads = json.load(open("leads.json", encoding="utf-8"))
supa = json.load(open("supabase.json", encoding="utf-8")) if os.path.exists("supabase.json") else {"url": "", "key": ""}
t = open("template.html", encoding="utf-8").read()
for k in ("/*LEADS*/[]", '/*SUPA_URL*/""', '/*SUPA_KEY*/""'):
    assert t.count(k) == 1, k
data = json.dumps(leads, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
t = t.replace("/*LEADS*/[]", data).replace('/*SUPA_URL*/""', json.dumps(supa["url"])).replace('/*SUPA_KEY*/""', json.dumps(supa["key"]))
open("index.html", "w", encoding="utf-8").write(t)
print(len(leads), "leads ->", "index.html", "(sync on)" if supa["url"] else "(sync off)")
