import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/supabase_client.dart';

class AddProductModal extends StatefulWidget {
  final List<String> existingCategories;

  const AddProductModal({super.key, this.existingCategories = const []});

  @override
  State<AddProductModal> createState() => _AddProductModalState();
}

class _AddProductModalState extends State<AddProductModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '0');
  final _categoryController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 0;
    final category = _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim();
    final user = supabase.auth.currentUser;

    try {
      final insertResponse = await supabase.from('products').insert({
        'name': name,
        'quantity': quantity,
        'sku_or_category': category,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select().single();

      if (quantity > 0) {
        await supabase.from('stock_movements').insert({
          'product_id': insertResponse['id'],
          'product_name': name,
          'type': 'ENTRY',
          'quantity': quantity,
          'user_email': user?.email ?? 'Usuário',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produto cadastrado com sucesso!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cadastrar produto: $e'),
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
                    'Novo Produto',
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
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Ex: Parafuso Sextavado 6mm',
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

              // Quantidade Inicial
              const Text('Estoque Inicial *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                    return 'Informe o estoque inicial';
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
                  hintText: 'Ex: Ferramentas, Bebidas, Elétrica...',
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
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _saveProduct,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Cadastrar Produto'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
