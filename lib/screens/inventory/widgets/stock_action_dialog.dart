import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/supabase_client.dart';
import '../../../models/product.dart';

class StockActionDialog extends StatefulWidget {
  final Product product;
  final bool isEntry;

  const StockActionDialog({
    super.key,
    required this.product,
    required this.isEntry,
  });

  @override
  State<StockActionDialog> createState() => _StockActionDialogState();
}

class _StockActionDialogState extends State<StockActionDialog> {
  final _controller = TextEditingController(text: '1');
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final qty = int.tryParse(_controller.text.trim()) ?? 0;
    if (qty <= 0) return;

    if (!widget.isEntry && widget.product.quantity - qty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Operação cancelada: estoque insuficiente.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = supabase.auth.currentUser;
    final userEmail = user?.email ?? 'Usuário desconhecido';

    try {
      // 1. Tenta executar via RPC atômico no Supabase se configurado
      try {
        await supabase.rpc('update_stock', params: {
          'p_product_id': widget.product.id,
          'p_product_name': widget.product.name,
          'p_type': widget.isEntry ? 'ENTRY' : 'EXIT',
          'p_quantity': qty,
          'p_user_email': userEmail,
        });
      } catch (_) {
        // Fallback: Atualização direta via tabela
        final newQuantity = widget.isEntry
            ? widget.product.quantity + qty
            : widget.product.quantity - qty;

        await supabase.from('products').update({
          'quantity': newQuantity,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.product.id);

        await supabase.from('stock_movements').insert({
          'product_id': widget.product.id,
          'product_name': widget.product.name,
          'type': widget.isEntry ? 'ENTRY' : 'EXIT',
          'quantity': qty,
          'user_email': userEmail,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar estoque: $e'),
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
    final title = widget.isEntry ? 'Registrar Entrada' : 'Registrar Saída';
    final actionColor = widget.isEntry ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            widget.isEntry ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
            color: actionColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.product.name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Estoque atual: ${widget.product.quantity}',
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Quantidade',
                hintText: 'Ex: 5',
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Informe a quantidade';
                }
                final numVal = int.tryParse(val.trim());
                if (numVal == null || numVal <= 0) {
                  return 'A quantidade deve ser maior que 0';
                }
                if (!widget.isEntry && numVal > widget.product.quantity) {
                  return 'Excede o estoque atual (${widget.product.quantity})';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: actionColor,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(widget.isEntry ? 'Adicionar' : 'Subtrair'),
        ),
      ],
    );
  }
}
