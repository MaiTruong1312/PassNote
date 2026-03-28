// lib/views/dashboard_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/dashboard_viewmodel.dart';
import 'tabs/home_view.dart';
import 'tabs/history_view.dart';
import 'tabs/settings_view.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  final List<Widget> _views = const [
    HomeView(),
    HistoryView(),
    SettingsView(),
  ];

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<DashboardViewModel>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      // Sử dụng IndexedStack để giữ trạng thái các trang khi chuyển đổi (không load lại từ đầu)
      body: IndexedStack(
        index: viewModel.currentIndex,
        children: _views,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.black.withOpacity(0.05), width: 1),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildNavItem(context, viewModel, 0, Icons.grid_view_outlined, "VAULT"),
                _buildNavItem(context, viewModel, 1, Icons.history_rounded, "LOGS"),
                _buildNavItem(context, viewModel, 2, Icons.tune_rounded, "PREF"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, DashboardViewModel viewModel, int index, IconData icon, String label) {
    bool isSelected = viewModel.currentIndex == index;

    return GestureDetector(
      onTap: () => viewModel.setTabIndex(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          // Hiệu ứng nền nhẹ khi được chọn
          color: isSelected ? Colors.black.withOpacity(0.03) : Colors.transparent,
          borderRadius: BorderRadius.zero, // Giữ góc vuông đồng bộ
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.black : Colors.black26,
            ),
            const SizedBox(height: 6),
            // Thanh gạch chân cực mảnh chỉ xuất hiện khi active
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 1.5,
              width: isSelected ? 15 : 0,
              color: Colors.black,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w400,
                letterSpacing: 2,
                color: isSelected ? Colors.black : Colors.black26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}