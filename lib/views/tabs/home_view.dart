import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/dashboard_viewmodel.dart';
import '../../utils/app_theme.dart';
import '../components/add_password_sheet.dart';
import '../components/password_details_sheet.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<DashboardViewModel>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER SECTION
              const Text(
                  "THE VAULT",
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -1)
              ),
              const SizedBox(height: 5),
              const Text(
                  "SECURED ECOSYSTEM",
                  style: TextStyle(fontSize: 9, letterSpacing: 4, color: Colors.grey, fontWeight: FontWeight.bold)
              ),

              const SizedBox(height: 50),

              // QUICK ACCESS LABEL
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      "QUICK ACCESS",
                      style: theme.textTheme.labelLarge?.copyWith(
                          color: Colors.black,
                          letterSpacing: 2,
                          fontSize: 11,
                          fontWeight: FontWeight.w900
                      )
                  ),
                  Container(height: 1, width: 40, color: Colors.black12),
                ],
              ),
              const SizedBox(height: 25),

              // HORIZONTAL LIST AREA
              SizedBox(
                height: 130, // Tăng nhẹ chiều cao để không bị khít
                child: viewModel.isLoadingPasswords
                    ? const Center(child: CircularProgressIndicator(color: Colors.black, strokeWidth: 1))
                    : viewModel.passwords.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: viewModel.passwords.length,
                  itemBuilder: (context, index) {
                    final item = viewModel.passwords[index];
                    return _buildPasswordItem(context, item);
                  },
                ),
              ),

              const SizedBox(height: 40),
              // Bạn có thể thêm các phần khác ở đây (ví dụ: Security Score, v.v.)
            ],
          ),
        ),
      ),

      // FLOATING ACTION BUTTON - SQUARE LUXURY
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        elevation: 10,
        highlightElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            builder: (context) => const AddPasswordSheet(),
          );
          viewModel.loadPasswords();
        },
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
    );
  }

  // WIDGET CHO TỪNG Ô MẬT KHẨU
  Widget _buildPasswordItem(BuildContext context, Map<String, dynamic> item) {
    return GestureDetector(
      onTap: () => _showPasswordDetails(context, item),
      child: Container(
        width: 115,
        margin: const EdgeInsets.only(right: 20, bottom: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(4, 4),
              blurRadius: 0,
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.key_outlined, size: 28, color: Colors.black),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                item['app_name'].toString().toUpperCase(),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    overflow: TextOverflow.ellipsis
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET KHI KHÔNG CÓ DỮ LIỆU
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black.withOpacity(0.05), width: 1),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.layers_clear_outlined, color: Colors.black12, size: 30),
          SizedBox(height: 10),
          Text(
              "NO DATA IN VAULT",
              style: TextStyle(fontSize: 9, letterSpacing: 2, color: Colors.grey, fontWeight: FontWeight.bold)
          ),
        ],
      ),
    );
  }

  void _showPasswordDetails(BuildContext context, Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      isScrollControlled: true,
      builder: (context) => PasswordDetailsSheet(item: item),
    );
  }
}