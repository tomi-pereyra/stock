import 'package:flutter/material.dart';
import '../../../models/product.dart';
import '../../../core/supabase_client.dart';
import 'stock_action_dialog.dart';
import 'edit_product_modal.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final List<String> existingCategories;

  const ProductCard({
    super.key,
    required this.product,
    this.existingCategories = const [],
  });

  Future<void> _quickAdjust(BuildContext context, bool isEntry) async {
    if (!isEntry && product.quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Estoque zerado! Não é possível realizar saídas.'),
          backgroundColor: Color(0xFFDC2626),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final user = supabase.auth.currentUser;
    final userEmail = user?.email ?? 'Usuário';

    try {
      try {
        await supabase.rpc('update_stock', params: {
          'p_product_id': product.id,
          'p_product_name': product.name,
          'p_type': isEntry ? 'ENTRY' : 'EXIT',
          'p_quantity': 1,
          'p_user_email': userEmail,
        });
      } catch (_) {
        final newQuantity = isEntry ? product.quantity + 1 : product.quantity - 1;

        await supabase.from('products').update({
          'quantity': newQuantity,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', product.id);

        await supabase.from('stock_movements').insert({
          'product_id': product.id,
          'product_name': product.name,
          'type': isEntry ? 'ENTRY' : 'EXIT',
          'quantity': 1,
          'user_email': userEmail,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openCustomQuantityDialog(BuildContext context, bool isEntry) {
    showDialog(
      context: context,
      builder: (_) => StockActionDialog(product: product, isEntry: isEntry),
    );
  }

  void _openEditModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EditProductModal(
        product: product,
        existingCategories: existingCategories,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Excluir Produto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Deseja realmente excluir "${product.name}" do estoque? Esta ação não pode ser desfeita.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      try {
        await supabase.from('products').delete().eq('id', product.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Produto "${product.name}" excluído.'),
              backgroundColor: const Color(0xFF0F172A),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao excluir produto: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLowStock = product.quantity <= 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openEditModal(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
          child: Row(
            children: [
              // Nome e Categoria
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (product.skuOrCategory != null && product.skuOrCategory!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          product.skuOrCategory!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF1D4ED8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const Text(
                        'Sem categoria',
                        style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                  ],
                ),
              ),

              // Badge de Estoque Atual
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isLowStock ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isLowStock ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                  ),
                ),
                child: Text(
                  '${product.quantity}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isLowStock ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                  ),
                ),
              ),

              // Botões Rápidos (- e +)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionButton(
                    icon: Icons.remove,
                    color: const Color(0xFFDC2626),
                    backgroundColor: const Color(0xFFFEE2E2),
                    onTap: () => _quickAdjust(context, false),
                    onLongPress: () => _openCustomQuantityDialog(context, false),
                    tooltip: 'Toque para -1, segure para customizar',
                  ),
                  const SizedBox(width: 6),
                  _ActionButton(
                    icon: Icons.add,
                    color: const Color(0xFF16A34A),
                    backgroundColor: const Color(0xFFDCFCE7),
                    onTap: () => _quickAdjust(context, true),
                    onLongPress: () => _openCustomQuantityDialog(context, true),
                    tooltip: 'Toque para +1, segure para customizar',
                  ),
                ],
              ),

              // Menu de Mais Opções (Editar / Excluir)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF64748B)),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (val) {
                  if (val == 'edit') {
                    _openEditModal(context);
                  } else if (val == 'delete') {
                    _confirmDelete(context);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: Color(0xFF334155)),
                        SizedBox(width: 10),
                        Text('Editar produto', style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                        SizedBox(width: 10),
                        Text('Excluir produto', style: TextStyle(fontSize: 14, color: Color(0xFFDC2626))),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final String tooltip;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
    required this.onLongPress,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, color: color, size: 19),
          ),
        ),
      ),
    );
  }
}
