import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/inventory_provider.dart';
import '../widgets/add_edit_buyer_dialog.dart';
import '../widgets/add_edit_shop_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Einstellungen'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            tabs: [
              Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Käufer'),
              Tab(icon: Icon(Icons.store_outlined, size: 18), text: 'Shops'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_BuyersTab(), _ShopsTab()],
        ),
      ),
    );
  }
}

class _BuyersTab extends StatelessWidget {
  const _BuyersTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final buyers = provider.buyers;
        return Scaffold(
          backgroundColor: const Color(0xFFF1F4F8),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'addBuyer',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const AddEditBuyerDialog(),
            ),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Käufer hinzufügen'),
          ),
          body: buyers.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 52, color: Color(0xFFCBD5E1)),
                      SizedBox(height: 12),
                      Text('Noch keine Käufer angelegt.',
                          style: TextStyle(color: Color(0xFF94A3B8))),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: buyers.length,
                  separatorBuilder: (context, i) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final buyer = buyers[i];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: buyer.buyerCellColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              buyer.name.isNotEmpty
                                  ? buyer.name[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: buyer.fontColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          buyer.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: buyer.rowFillColor,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: buyer.buyerCellColor.withAlpha(100)),
                              ),
                            ),
                            Text(
                              buyer.active ? 'Aktiv' : 'Inaktiv',
                              style: TextStyle(
                                fontSize: 12,
                                color: buyer.active
                                    ? const Color(0xFF059669)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              color: const Color(0xFF64748B),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => AddEditBuyerDialog(buyer: buyer),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: Colors.red[400],
                              onPressed: () =>
                                  _confirmDelete(context, provider, buyer.id, buyer.name),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, InventoryProvider provider,
      String id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Käufer löschen'),
        content: Text('Käufer "$name" wirklich löschen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () {
              provider.deleteBuyer(id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ShopsTab extends StatelessWidget {
  const _ShopsTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, _) {
        final shops = provider.shops;
        return Scaffold(
          backgroundColor: const Color(0xFFF1F4F8),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'addShop',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const AddEditShopDialog(),
            ),
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Shop hinzufügen'),
          ),
          body: shops.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.store_outlined, size: 52, color: Color(0xFFCBD5E1)),
                      SizedBox(height: 12),
                      Text('Noch keine Shops angelegt.',
                          style: TextStyle(color: Color(0xFF94A3B8))),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: shops.length,
                  separatorBuilder: (context, i) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final shop = shops[i];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: const Border.fromBorderSide(
                                BorderSide(color: Color(0xFFBFDBFE))),
                          ),
                          child: const Icon(Icons.store_outlined,
                              color: Color(0xFF2563EB), size: 22),
                        ),
                        title: Text(shop.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          '${shop.region}${shop.channel.isNotEmpty ? " · ${shop.channel}" : ""}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              color: const Color(0xFF64748B),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => AddEditShopDialog(shop: shop),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: Colors.red[400],
                              onPressed: () => _confirmDelete(
                                  context, provider, shop.id, shop.name),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, InventoryProvider provider,
      String id, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Shop löschen'),
        content: Text('Shop "$name" wirklich löschen?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () {
              provider.deleteShop(id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Löschen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
