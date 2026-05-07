import re
def remove_const(content):
    lines = content.split(chr(10))
    result = []
    for line in lines:
        if "Of(context)" in line and "const " in line:
            line = re.sub(r"\bconst (TextStyle|Icon|Divider|BoxDecoration|ColoredBox|SizedBox|Text|Container|Padding|Row|Column|Center|CircularProgressIndicator)\b", r"\1", line)
        result.append(line)
    return chr(10).join(result)
def fix_files():
    with open("lib/screens/dashboard_screen.dart", "r") as f:
        c = f.read()
    c = c.replace("AppTheme.borderOf(context)StrongOf(context)", "AppTheme.borderStrongOf(context)")
    with open("lib/screens/dashboard_screen.dart", "w") as f:
        f.write(c)
    print("Fixed borderStrong")
    with open("lib/screens/activity_screen.dart", "r") as f:
        c = f.read()
    c = c.replace("color: AppTheme.textMutedOf(context)),\n  };", "color: AppTheme.textMuted),\n  };")
    with open("lib/screens/activity_screen.dart", "w") as f:
        f.write(c)
    print("Fixed activity static map")
    with open("lib/widgets/deal_card.dart", "r") as f:
        c = f.read()
    c = c.replace("final status = _statusStyle(deal.status);", "final status = _statusStyle(deal.status, context);")
    c = c.replace("({Color bg, Color border, Color text}) _statusStyle(String s) =>", "({Color bg, Color border, Color text}) _statusStyle(String s, BuildContext context) =>")
    with open("lib/widgets/deal_card.dart", "w") as f:
        f.write(c)
    print("Fixed deal_card _statusStyle")
    with open("lib/widgets/global_search_dialog.dart", "r") as f:
        c = f.read()
    c = c.replace("  Widget _hint(String text) => Padding(", "  Widget _hint(String text, BuildContext context) => Padding(")
    import_str = chr(0x27)
    h1 = "        _hint(" + import_str + "Produktname, EAN, SKU, Ticket-Nummer, K\u00e4ufer-Name\u2026" + import_str + "),"
    h2 = "        _hint(" + import_str + "\u2191 \u2193 navigieren \u00b7 \u21b5 \u00f6ffnen \u00b7 esc schlie\u00dft." + import_str + "),"
    n1 = "        _hint(" + import_str + "Produktname, EAN, SKU, Ticket-Nummer, K\u00e4ufer-Name\u2026" + import_str + ", context),"
    n2 = "        _hint(" + import_str + "\u2191 \u2193 navigieren \u00b7 \u21b5 \u00f6ffnen \u00b7 esc schlie\u00dft." + import_str + ", context),"
    c = c.replace(h1, n1)
    c = c.replace(h2, n2)
    with open("lib/widgets/global_search_dialog.dart", "w") as f:
        f.write(c)
    print("Fixed global_search_dialog _hint")
fix_files()
files = [
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
for path in files:
    with open(path, "r") as f:
        c = f.read()
    n = remove_const(c)
    if n != c:
        with open(path, "w") as f:
            f.write(n)
        print(f"Removed const from {path}")
    else:
        print(f"No const changes in {path}")
