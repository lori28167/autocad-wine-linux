"""Build a 'Microsoft Sans Serif' stand-in from Liberation Sans (SIL OFL 1.1).
The OFL requires renamed modified versions not to use the Reserved Font Name
"Liberation", which this name does not."""
import sys
from fontTools.ttLib import TTFont

src, dst = sys.argv[1], sys.argv[2]
font = TTFont(src)
names = {1: "Microsoft Sans Serif", 2: "Regular", 3: "Microsoft Sans Serif Regular (Wine substitute)",
         4: "Microsoft Sans Serif", 6: "MicrosoftSansSerif", 16: "Microsoft Sans Serif", 17: "Regular"}
table = font["name"]
for rec in list(table.names):
    if rec.nameID in names:
        table.removeNames(nameID=rec.nameID)
for nid, value in names.items():
    table.setName(value, nid, 3, 1, 0x409)
    table.setName(value, nid, 1, 0, 0)
font.save(dst)
print("saved", dst)
