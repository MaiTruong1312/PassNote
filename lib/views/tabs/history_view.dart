// lib/views/tabs/history_view.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import 'package:intl/intl.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<DashboardViewModel>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "AUDIT LOGS", 
          style: TextStyle(color: Colors.black, letterSpacing: 4, fontSize: 14, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.black12, height: 1), // Đường kẻ mảnh dưới AppBar
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: viewModel.fetchAuditLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 1));
          }
          
          final logs = snapshot.data ?? [];
          
          if (logs.isEmpty) {
            return const Center(
              child: Text("NO SYSTEM ACTIVITY RECORDED", 
                style: TextStyle(letterSpacing: 2, fontSize: 10, color: Colors.grey))
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final DateTime date = DateTime.parse(log['created_at'].toString());
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black.withOpacity(0.05)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  leading: _getIconForAction(log['action_type'].toString().toLowerCase()),
                  title: Text(
                    log['action_type'].toString().replaceAll('_', ' ').toUpperCase(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      DateFormat('dd MMM yyyy • HH:mm').format(date).toUpperCase(),
                      style: const TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1),
                    ),
                  ),
                  trailing: Text(
                    log['status']?.toString().toUpperCase() ?? "SUCCESS",
                    style: TextStyle(
                      fontSize: 8, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                      color: log['status'] == 'failed' ? Colors.black : Colors.grey[400]
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _getIconForAction(String action) {
    IconData iconData;
    if (action.contains('login')) {
      iconData = Icons.fingerprint;
    } else if (action.contains('delete')) {
      iconData = Icons.delete_sweep_outlined;
    } else if (action.contains('password')) {
      iconData = Icons.lock_open_outlined;
    } else {
      iconData = Icons.history_edu_outlined;
    }
    
    // Sử dụng màu đen xám thay vì xanh đỏ để giữ tính "Luxury"
    return Icon(iconData, color: Colors.black, size: 22);
  }
}