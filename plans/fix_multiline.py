import re
OF = chr(79)+chr(102)+chr(40)+chr(99)+chr(111)+chr(110)+chr(116)+chr(101)+chr(120)+chr(116)+chr(41)
CONST = chr(99)+chr(111)+chr(110)+chr(115)+chr(116)+chr(32)
WIDGETS = chr(40)+"TextStyle|BoxDecoration|Divider|ColoredBox|SizedBox|Text|Padding|Container|Row|Column|Center|Icon"+chr(41)
pattern = re.compile(r"\b"+CONST+WIDGETS+r"\s*\(")
def fix(content):
    result = []
    i = 0
    while i < len(content):
        m = pattern.search(content, i)
        if not m:
            result.append(content[i:])
            break
        result.append(content[i:m.start()])
        start = m.start()
        op = content.index(chr(40), m.start())
        depth = 0
        end = op
        for j in range(op, len(content)):
            if content[j] == chr(40): depth += 1
            elif content[j] == chr(41):
                depth -= 1
                if depth == 0:
                    end = j + 1
                    break
        snip = content[start:end]
        if OF in snip:
            snip = snip.replace(CONST+m.group(1), m.group(1), 1)
        result.append(snip)
        i = end
    return "".join(result)
flist = [
    "lib/screens/dashboard_screen.dart",
    "lib/screens/activity_screen.dart",
    "lib/screens/main_screen.dart",
    "lib/widgets/attachment_gallery.dart",
    "lib/widgets/tracking_chip.dart",
    "lib/widgets/invites_bell.dart",
    "lib/widgets/kpi_card.dart",
    "lib/widgets/deal_card.dart",
    "lib/widgets/global_search_dialog.dart",
]
for path in flist:
    with open(path, "r") as fh: c = fh.read()
    n = fix(c)
    if n != c:
        with open(path, "w") as fh: fh.write(n)
        print("changed", path)
    else: print("no change", path)