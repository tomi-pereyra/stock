import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/supabase_client.dart';
import '../../../models/product.dart';

class EditProductModal extends StatefulWidget {
  final Product product;
  final List<String> existingCategories;

  const EditProductModal({
    super.key,
    required this.product,
    this.existingCategories = const [],
  });

  @override
  State<EditProductModal> createState() => _EditProductModalState();
}

class _EditProductModalState extends State<EditProductModal> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _quantityController;
  late TextEditingController _categoryController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product.name);
    _quantityController = TextEditingController(text: widget.product.quantity.toString());
    _categoryController = TextEditingController(text: widget.product.skuOrCategory ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final newQuantity = int.tryParse(_quantityController.text.trim()) ?? widget.product.quantity;
    final category = _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim();
    final user = supabase.auth.currentUser;

    try {
      await supabase.from('products').update({
        'name': name,
        'quantity': newQuantity,
        'sku_or_category': category,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.product.id);

      // Se a quantidade foi alterada diretamente, registra a movimentação de ajuste
      final diff = newQuantity - widget.product.quantity;
      if (diff != 0) {
        await supabase.from('stock_movements').insert({
          'product_id': widget.product.id,
          'product_name': name,
          'type': diff > 0 ? 'ENTRY' : 'EXIT',
          'quantity': diff.abs(),
          'user_email': user?.email ?? 'Usuário',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produto atualizado com sucesso!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar produto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Editar Produto',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Nome do Produto
              const Text('Nome do Produto *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Nome do produto',
                  prefixIcon: Icon(Icons.label_outline_rounded, size: 20),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome do produto';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Categoria
              const Text('Categoria', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _categoryController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Ex: Ferramentas, Limpeza, Alimentos...',
                  prefixIcon: Icon(Icons.category_outlined, size: 20),
                ),
              ),

              if (widget.existingCategories.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: widget.existingCategories.map((cat) {
                    return ActionChip(
                      label: Text(cat, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        setState(() {
                          _categoryController.text = cat;
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 16),

              // Quantidade em Estoque
              const Text('Quantidade em Estoque *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: '0',
                  prefixIcon: Icon(Icons.tag_rounded, size: 20),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe a quantidade';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Salvar Alterações'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
