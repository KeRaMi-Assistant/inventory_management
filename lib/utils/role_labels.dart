import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';
import '../models/workspace.dart';

/// Single-Source-of-Truth für die UI-Labels der Workspace-Rollen.
/// Mapping:
/// - `WorkspaceRole.owner`    → l10n.teamRoleOwner    („Eigentümer:in/Owner")
/// - `WorkspaceRole.admin`    → l10n.teamRoleAdmin    („Admin")
/// - `WorkspaceRole.editor`   → l10n.teamRoleEditor   („Editor")
/// - `WorkspaceRole.observer` → l10n.teamRoleObserver („Beobachter/Observer")
///
/// Die l10n-Keys existieren in `lib/l10n/app_de.arb` und `app_en.arb`.
/// Diese Funktion ist der einzige Lookup-Pfad — Drift zwischen
/// `settings_screen` und `invites_bell` ist damit ausgeschlossen.
String roleLabel(BuildContext context, WorkspaceRole role) {
  final l10n = AppLocalizations.of(context);
  return switch (role) {
    WorkspaceRole.owner => l10n.teamRoleOwner,
    WorkspaceRole.admin => l10n.teamRoleAdmin,
    WorkspaceRole.editor => l10n.teamRoleEditor,
    WorkspaceRole.observer => l10n.teamRoleObserver,
  };
}

/// Variante ohne BuildContext-Abhängigkeit für Tests / Background-Logging.
/// Liefert englische Fallback-Labels.
String roleLabelFallback(WorkspaceRole role) => switch (role) {
      WorkspaceRole.owner => 'Owner',
      WorkspaceRole.admin => 'Admin',
      WorkspaceRole.editor => 'Editor',
      WorkspaceRole.observer => 'Observer',
    };
