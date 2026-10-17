# build.py: inline leads.json into template.html -> index.html
import json, os
os.chdir(os.path.dirname(os.path.abspath(__file__)))
leads = json.load(open("leads.json", encoding="utf-8"))
t = open("template.html", encoding="utf-8").read()
assert t.count("/*LEADS*/[]") == 1
data = json.dumps(leads, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/")
open("index.html", "w", encoding="utf-8").write(t.replace("/*LEADS*/[]", data))
print(len(leads), "leads ->", "index.html")
