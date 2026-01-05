import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  List<dynamic> _dailyRanking = [];
  List<dynamic> _monthlyRanking = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchRankings();
  }

  Future<void> _fetchRankings() async {
    try {
      final data = await _apiService.getRankings();
      setState(() {
        _dailyRanking = data['daily'] ?? [];
        _monthlyRanking = data['monthly'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🏆 Ranking Técnicos'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Diario'),
            Tab(text: 'Mensual'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRankingList(_dailyRanking, 'Hoy'),
                    _buildRankingList(_monthlyRanking, 'Este Mes'),
                  ],
                ),
    );
  }

  Widget _buildRankingList(List<dynamic> ranking, String period) {
    if (ranking.isEmpty) {
      return Center(child: Text('No hay registros para $period'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: ranking.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final item = ranking[index];
        final isTop3 = index < 3;
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isTop3 ? Colors.amber : Colors.grey[200],
            foregroundColor: isTop3 ? Colors.white : Colors.black,
            child: Text(
              '#${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            item['name'] ?? 'Desconocido',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${item['count']} Órdenes',
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
