import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/inventory_provider.dart';

/// Hilfe-/Onboarding-Seite. Sammelt Anleitungen, die früher als
/// "Discord-Info"-Tab in den Einstellungen vergraben waren — und gibt Platz
/// für weitere Onboarding-Inhalte (Barcode-Scanner, Push-Setup, …) ohne die
/// Settings zuzumüllen.
class HelpScreen extends StatelessWidget {
  final bool embedded;
  const HelpScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final body = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle(l10n.helpQuickStart),
        const SizedBox(height: 8),
        _HelpStep(
          number: '1',
          title: l10n.helpStepShopsBuyersTitle,
          desc: l10n.helpStepShopsBuyersDesc,
        ),
        const SizedBox(height: 8),
        _HelpStep(
          number: '2',
          title: l10n.helpStepFirstDealTitle,
          desc: l10n.helpStepFirstDealDesc,
        ),
        const SizedBox(height: 8),
        _HelpStep(
          number: '3',
          title: l10n.helpStepStatsTitle,
          desc: l10n.helpStepStatsDesc,
        ),
        const SizedBox(height: 28),
        const _DiscordSection(),
        const SizedBox(height: 28),
        _SectionTitle(l10n.helpContactSection),
        const SizedBox(height: 8),
        _InfoCard(
          icon: Icons.mark_email_unread_outlined,
          title: l10n.helpContactReportTitle,
          subtitle: l10n.helpContactReportDesc,
        ),
      ],
    );

    if (embedded) {
      return Container(color: AppTheme.bgAppOf(context), child: body);
    }
    return Scaffold(
      backgroundColor: AppTheme.bgAppOf(context),
      appBar: AppBar(title: Text(l10n.helpTitle)),
      body: body,
    );
  }
}

class _DiscordSection extends StatelessWidget {
  const _DiscordSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final buyers = context.watch<InventoryProvider>().buyers;
    final dark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(l10n.helpDiscordSection),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF5865F2).withAlpha(dark ? 35 : 12),
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: const Color(0xFF5865F2).withAlpha(60)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF5865F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.discord,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.helpDiscordHowTitle,
                        style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimaryOf(context))),
                    const SizedBox(height: 6),
                    Text(
                      l10n.helpDiscordHowDesc,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryOf(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _HelpStep(
          number: '1',
          title: l10n.helpDiscordStep1Title,
          desc: l10n.helpDiscordStep1Desc,
        ),
        const SizedBox(height: 8),
        _HelpStep(
          number: '2',
          title: l10n.helpDiscordStep2Title,
          desc: l10n.helpDiscordStep2Desc,
        ),
        const SizedBox(height: 8),
        _HelpStep(
          number: '3',
          title: l10n.helpDiscordStep3Title,
          desc: l10n.helpDiscordStep3Desc,
        ),
        const SizedBox(height: 16),
        Text(l10n.helpDiscordConfiguredIds,
            style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryOf(context))),
        const SizedBox(height: 8),
        if (buyers.isEmpty)
          _InfoCard(
            icon: Icons.info_outline,
            title: l10n.helpDiscordNoBuyers,
            subtitle: l10n.helpDiscordNoBuyersDesc,
          )
        else
          ...buyers.map((b) {
            final ids = b.discordServerIds;
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: AppTheme.borderOf(context)),
              ),
              child: ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: b.buyerCellColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      b.name.isNotEmpty ? b.name[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: b.fontColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                title: Text(b.name,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context))),
                subtitle: Text(
                  ids.isEmpty
                      ? l10n.helpDiscordNoServerIds
                      : ids.join(', '),
                  style: TextStyle(
                    fontSize: 12,
                    color: ids.isEmpty
                        ? AppTheme.textMutedOf(context)
                        : const Color(0xFF5865F2),
                  ),
                ),
                trailing: Icon(Icons.discord,
                    color: ids.isEmpty
                        ? AppTheme.textDisabledOf(context)
                        : const Color(0xFF5865F2)),
              ),
            );
          }),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppTheme.textMutedOf(context),
        letterSpacing: 0.7,
      ),
    );
  }
}

class _HelpStep extends StatelessWidget {
  final String number;
  final String title;
  final String desc;
  const _HelpStep({
    required this.number,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgSurfaceOf(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppTheme.accentLightOf(context),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(number,
                  style: TextStyle(
                      color: AppTheme.accentTextOf(context),
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryOf(context))),
                const SizedBox(height: 2),
                Text(desc,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppTheme.borderOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.accentTextOf(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryOf(context))),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryOf(context))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
