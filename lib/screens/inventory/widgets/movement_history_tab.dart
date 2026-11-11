import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/supabase_client.dart';
import '../../../models/movement.dart';

class MovementHistoryTab extends StatelessWidget {
  const MovementHistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('stock_movements')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .limit(100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Erro ao carregar histórico: ${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final data = snapshot.data ?? [];
        if (data.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history_rounded, size: 48, color: Color(0xFF94A3B8)),
                SizedBox(height: 12),
                Text(
                  'Nenhuma movimentação registrada.',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                ),
              ],
            ),
          );
        }

        final movements = data.map((map) => StockMovement.fromMap(map)).toList();

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: movements.length,
          separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
          itemBuilder: (context, index) {
            final mov = movements[index];
            final isEntry = mov.isEntry;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              leading: CircleAvatar(
                backgroundColor: isEntry ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                child: Icon(
                  isEntry ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: isEntry ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  size: 20,
                ),
              ),
              title: Text(
                mov.productName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: Text(
                '${mov.userEmail.split('@').first} • ${dateFormat.format(mov.createdAt.toLocal())}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              trailing: Text(
                '${isEntry ? '+' : '-'}${mov.quantity}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isEntry ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
