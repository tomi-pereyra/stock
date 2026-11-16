import 'package:flutter/material.dart';
import '../../core/supabase_client.dart';
import '../../models/product.dart';
import '../auth/login_screen.dart';
import 'widgets/add_product_modal.dart';
import 'widgets/product_card.dart';
import 'widgets/movement_history_tab.dart';

enum SortOption {
  updatedDesc('Modificados recentemente', Icons.history_rounded),
  updatedAsc('Modificados antigamente', Icons.update_rounded),
  nameAsc('Nome (A - Z)', Icons.sort_by_alpha_rounded),
  nameDesc('Nome (Z - A)', Icons.sort_by_alpha_rounded),
  quantityDesc('Maior estoque', Icons.arrow_downward_rounded),
  quantityAsc('Menor estoque', Icons.arrow_upward_rounded);

  final String label;
  final IconData icon;
  const SortOption(this.label, this.icon);
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  int _currentTabIndex = 0;
  String _searchQuery = '';
  String? _selectedCategory; // null = Todas
  SortOption _currentSort = SortOption.updatedDesc;

  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Saída'),
        content: const Text('Deseja realmente desconectar desta conta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sair', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }
  }

  void _openAddProductModal(List<String> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddProductModal(existingCategories: categories),
    );
  }

  void _openSortDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    'Organizar produtos por',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ),
                ...SortOption.values.map((opt) {
                  final isSelected = opt == _currentSort;
                  return ListTile(
                    leading: Icon(
                      opt.icon,
                      color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                    ),
                    title: Text(
                      opt.label,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF0F172A))
                        : null,
                    onTap: () {
                      setState(() => _currentSort = opt);
                      Navigator.of(ctx).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = supabase.auth.currentUser?.email ?? 'Usuário';

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('products').stream(primaryKey: ['id']),
      builder: (context, snapshot) {
        final rawList = snapshot.data ?? [];
        final allProducts = rawList.map((map) => Product.fromMap(map)).toList();

        // Extrai categorias únicas
        final categories = allProducts
            .map((p) => p.skuOrCategory?.trim())
            .where((c) => c != null && c.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.folder_rounded,
                    color: Color(0xFFF59E0B),
                    size: 20,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'stock',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                      ),
                      Text(
                        userEmail,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (_currentTabIndex == 0)
                IconButton(
                  icon: const Icon(Icons.sort_rounded),
                  tooltip: 'Organizar produtos',
                  onPressed: _openSortDialog,
                ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Sair da conta',
                onPressed: _logout,
              ),
            ],
          ),
          body: _currentTabIndex == 0
              ? _buildInventoryBody(snapshot, allProducts, categories)
              : const MovementHistoryTab(),
          floatingActionButton: _currentTabIndex == 0
              ? FloatingActionButton.extended(
                  onPressed: () => _openAddProductModal(categories),
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.add),
                  label: const Text('Novo Produto'),
                )
              : null,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentTabIndex,
            onDestinationSelected: (index) {
              setState(() => _currentTabIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2_rounded),
                label: 'Estoque',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history_rounded),
                label: 'Histórico',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInventoryBody(
    AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
    List<Product> allProducts,
    List<String> categories,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting && allProducts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Erro ao carregar estoque: ${snapshot.error}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    // Aplica filtro por busca
    var filtered = allProducts.where((p) {
      if (_searchQuery.isEmpty) return true;
      final matchName = p.name.toLowerCase().contains(_searchQuery);
      final matchCat = p.skuOrCategory?.toLowerCase().contains(_searchQuery) ?? false;
      return matchName || matchCat;
    }).toList();

    // Aplica filtro por categoria
    if (_selectedCategory != null) {
      filtered = filtered.where((p) => p.skuOrCategory?.trim() == _selectedCategory).toList();
    }

    // Aplica ordenação
    switch (_currentSort) {
      case SortOption.updatedDesc:
        filtered.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case SortOption.updatedAsc:
        filtered.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
        break;
      case SortOption.nameAsc:
        filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case SortOption.nameDesc:
        filtered.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
        break;
      case SortOption.quantityDesc:
        filtered.sort((a, b) => b.quantity.compareTo(a.quantity));
        break;
      case SortOption.quantityAsc:
        filtered.sort((a, b) => a.quantity.compareTo(b.quantity));
        break;
    }

    return Column(
      children: [
        // Barra de Busca
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim().toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: 'Buscar por nome ou categoria...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
          ),
        ),

        // Barra de Filtro de Categorias (Chips horizontais)
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text('Todas (${allProducts.length})'),
                  selected: _selectedCategory == null,
                  onSelected: (_) {
                    setState(() => _selectedCategory = null);
                  },
                ),
              ),
              ...categories.map((cat) {
                final count = allProducts.where((p) => p.skuOrCategory?.trim() == cat).length;
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text('$cat ($count)'),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = selected ? cat : null;
                      });
                    },
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 4),

        // Lista de Produtos
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchQuery.isNotEmpty || _selectedCategory != null
                            ? Icons.filter_alt_off_rounded
                            : Icons.inventory_2_outlined,
                        size: 56,
                        color: const Color(0xFF94A3B8),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'Nenhum produto encontrado para "$_searchQuery"'
                            : _selectedCategory != null
                                ? 'Nenhum produto na categoria "$_selectedCategory"'
                                : 'Nenhum produto cadastrado no momento.',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 15),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 4, bottom: 84),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return ProductCard(
                      product: filtered[index],
                      existingCategories: categories,
                    );
                  },
                ),
        ),
      ],
    );
  }
}
