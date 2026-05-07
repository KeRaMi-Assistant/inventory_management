
import re

def fix_file(path):
    with open(path, "r") as f:
        content = f.read()
    
    replacements = [
        ("AppTheme.borderStrong", "AppTheme.borderStrongOf(context)"),
        ("AppTheme.border", "AppTheme.borderOf(context)"),
        ("AppTheme.bgSurface", "AppTheme.bgSurfaceOf(context)"),
        ("AppTheme.bgSubtle", "AppTheme.bgSubtleOf(context)"),
        ("AppTheme.bgApp", "AppTheme.bgAppOf(context)"),
        ("AppTheme.textPrimary", "AppTheme.textPrimaryOf(context)"),
        ("AppTheme.textSecondary", "AppTheme.textSecondaryOf(context)"),
        ("AppTheme.textMuted", "AppTheme.textMutedOf(context)"),
        ("AppTheme.textDisabled", "AppTheme.textDisabledOf(context)"),
    ]
    
    for old, new in replacements:
        content = content.replace(old, new)
    
    lines = content.split("\n")
    new_lines = []
    for line in lines:
        if "Of(context)" in line and "const " in line:
            line = re.sub(r"\bconst (TextStyle|Icon|Divider|BoxDecoration|ColoredBox|SizedBox)\b", r"\1", line)
        new_lines.append(line)
    content = "\n".join(new_lines)
    
    with open(path, "w") as f:
        f.write(content)
    
    remaining = re.findall(r"AppTheme\.(bgApp|bgSurface|bgSubtle|border|borderStrong|textPrimary|textSecondary|textMuted|textDisabled)[^O]", content)
    print(f"Updated {path}, remaining: {len(remaining)}")

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

for f in files:
    fix_file(f)
