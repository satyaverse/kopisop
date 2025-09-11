import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../db.dart';
import '../widgets/drawer.dart';
import 'package:intl/intl.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  Map<String, Map<String, int>> dailyReport = {};
  List<Map<String, dynamic>> todayTransactions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => isLoading = true);
    final transactions = await DBHelper().getTransactionsWithItems();

    final Map<String, Map<String, int>> report = {};
    final List<Map<String, dynamic>> todayTrx = [];
    final today = DateTime.now();

    for (var trx in transactions) {
      final date = DateTime.tryParse(trx['date']);
      if (date == null) continue;

      final key =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

      final total = (trx['total'] ?? 0) as num;
      final dibayar = (trx['dibayar'] ?? 0) as num;
      final status = trx['status'] ?? 'lunas';

      report.putIfAbsent(key, () => {"penjualan": 0, "piutang": 0, "count": 0});

      report[key]!["count"] = (report[key]!["count"] ?? 0) + 1;
      report[key]!["penjualan"] =
          (report[key]!["penjualan"] ?? 0) + dibayar.toInt();

      if (status != "lunas") {
        final sisa = total - dibayar;
        report[key]!["piutang"] =
            (report[key]!["piutang"] ?? 0) + sisa.toInt();
      }

      if (date.year == today.year &&
          date.month == today.month &&
          date.day == today.day) {
        todayTrx.add(trx);
      }
    }

    setState(() {
      dailyReport = report;
      todayTransactions = todayTrx;
      isLoading = false;
    });
  }

  String _formatCurrency(int amount) {
    final formatter = NumberFormat("#,##0", "id_ID");
    return formatter.format(amount);
  }

  // === Chart per jam (Harian) ===
  Widget _buildHourlyChart() {
    final lineData = _generateHourlyLineData();
    final maxY = [
      ...(lineData["penjualan"] ?? []).map((e) => e.y),
      ...(lineData["piutang"] ?? []).map((e) => e.y),
      100
    ].reduce((a, b) => a > b ? a : b) * 1.2;

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          titlesData: const FlTitlesData(show: true),
          gridData: const FlGridData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: lineData["penjualan"] ?? [],
              isCurved: true,
              preventCurveOverShooting: true,
              color: Colors.green,
              barWidth: 3,
            ),
            LineChartBarData(
              spots: lineData["piutang"] ?? [],
              isCurved: true,
              preventCurveOverShooting: true,
              color: Colors.red,
              barWidth: 3,
            ),
          ],

//  Tooltip custom
    lineTouchData: LineTouchData(
  touchTooltipData: LineTouchTooltipData(
    tooltipRoundedRadius: 8,
    tooltipPadding: const EdgeInsets.all(8),
    getTooltipColor: (touchedSpot) {
      // bisa dinamis berdasarkan bar/spot
      return Colors.black.withValues(alpha: 0.7);
    },
    getTooltipItems: (touchedSpots) {
      return touchedSpots.map((spot) {
        return LineTooltipItem(
          '${spot.bar.color == Colors.green ? "Penjualan" : "Piutang"}\n${spot.y.toInt()}',
          TextStyle(
            color: spot.bar.color, // teks ikut warna garis
            fontWeight: FontWeight.bold,
          ),
        );
      }).toList();
    },
  ),
),


        ),
      ),
    );
  }

  Map<String, List<FlSpot>> _generateHourlyLineData() {
    final Map<int, int> penjualanPerJam = {};
    final Map<int, int> piutangPerJam = {};
    for (int i = 0; i < 24; i++) {
      penjualanPerJam[i] = 0;
      piutangPerJam[i] = 0;
    }

    for (var trx in todayTransactions) {
      final date = DateTime.tryParse(trx['date']);
      if (date == null) continue;

      final hour = date.hour;
      final total = (trx['total'] ?? 0) as num;
      final dibayar = (trx['dibayar'] ?? 0) as num;
      final status = trx['status'] ?? 'lunas';

      penjualanPerJam[hour] = (penjualanPerJam[hour] ?? 0) + dibayar.toInt();
      if (status != "lunas") {
        final sisa = total - dibayar;
        piutangPerJam[hour] = (piutangPerJam[hour] ?? 0) + sisa.toInt();
      }
    }

    final penjualanSpots = <FlSpot>[];
    final piutangSpots = <FlSpot>[];
    for (int i = 0; i < 24; i++) {
      penjualanSpots.add(FlSpot(i.toDouble(), penjualanPerJam[i]!.toDouble()));
      piutangSpots.add(FlSpot(i.toDouble(), piutangPerJam[i]!.toDouble()));
    }

    return {"penjualan": penjualanSpots, "piutang": piutangSpots};
  }

  // === Chart per hari (Mingguan) ===
  Widget _buildWeeklyChart() {
    final today = DateTime.now();
    final last7Days = List.generate(7, (i) {
      final d = today.subtract(Duration(days: 6 - i));
      return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
    });

    final spotsPenjualan = <FlSpot>[];
    final spotsPiutang = <FlSpot>[];

    for (int i = 0; i < last7Days.length; i++) {
      final key = last7Days[i];
      final data = dailyReport[key] ?? {"penjualan": 0, "piutang": 0};
      spotsPenjualan
          .add(FlSpot(i.toDouble(), (data["penjualan"] ?? 0).toDouble()));
      spotsPiutang
          .add(FlSpot(i.toDouble(), (data["piutang"] ?? 0).toDouble()));
    }

    final maxY = [
      ...spotsPenjualan.map((e) => e.y),
      ...spotsPiutang.map((e) => e.y),
      100
    ].reduce((a, b) => a > b ? a : b) * 1.2;

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          titlesData: const FlTitlesData(show: true),
          gridData: const FlGridData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spotsPenjualan,
              isCurved: true,
              preventCurveOverShooting: true,
              color: Colors.green,
              barWidth: 3,
            ),
            LineChartBarData(
              spots: spotsPiutang,
              isCurved: true,
              preventCurveOverShooting: true,
              color: Colors.red,
              barWidth: 3,
            ),
          ],

          //  Tooltip custom
    lineTouchData: LineTouchData(
  touchTooltipData: LineTouchTooltipData(
    tooltipRoundedRadius: 8,
    tooltipPadding: const EdgeInsets.all(8),
    getTooltipColor: (touchedSpot) {
      // bisa dinamis berdasarkan bar/spot
      return Colors.black.withValues(alpha: 0.7);
    },
    getTooltipItems: (touchedSpots) {
      return touchedSpots.map((spot) {
        return LineTooltipItem(
          '${spot.bar.color == Colors.green ? "Penjualan" : "Piutang"}\n${spot.y.toInt()}',
          TextStyle(
            color: spot.bar.color, // teks ikut warna garis
            fontWeight: FontWeight.bold,
          ),
        );
      }).toList();
    },
  ),
),
        ),
      ),
    );
  }

  // === Chart bulanan ===
  Widget _buildMonthlyChart() {
    final today = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(today.year, today.month);

    final spotsPenjualan = <FlSpot>[];
    final spotsPiutang = <FlSpot>[];

    for (int i = 1; i <= daysInMonth; i++) {
      final key =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${i.toString().padLeft(2, '0')}";
      final data = dailyReport[key] ?? {"penjualan": 0, "piutang": 0};

      spotsPenjualan
          .add(FlSpot(i.toDouble(), (data["penjualan"] ?? 0).toDouble()));
      spotsPiutang
          .add(FlSpot(i.toDouble(), (data["piutang"] ?? 0).toDouble()));
    }

    final maxY = [
      ...spotsPenjualan.map((e) => e.y),
      ...spotsPiutang.map((e) => e.y),
      100
    ].reduce((a, b) => a > b ? a : b) * 1.2;

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          titlesData: const FlTitlesData(show: true),
          gridData: const FlGridData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spotsPenjualan,
              isCurved: true,
              preventCurveOverShooting: true,
              color: Colors.green,
              barWidth: 3,
            ),
            LineChartBarData(
              spots: spotsPiutang,
              isCurved: true,
              preventCurveOverShooting: true,
              color: Colors.red,
              barWidth: 3,
            ),
          ],

          //  Tooltip custom
    lineTouchData: LineTouchData(
  touchTooltipData: LineTouchTooltipData(
    tooltipRoundedRadius: 8,
    tooltipPadding: const EdgeInsets.all(8),
    getTooltipColor: (touchedSpot) {
      // bisa dinamis berdasarkan bar/spot
      return Colors.black.withValues(alpha: 0.7);
    },
    getTooltipItems: (touchedSpots) {
      return touchedSpots.map((spot) {
        return LineTooltipItem(
          '${spot.bar.color == Colors.green ? "Penjualan" : "Piutang"}\n${spot.y.toInt()}',
          TextStyle(
            color: spot.bar.color, // teks ikut warna garis
            fontWeight: FontWeight.bold,
          ),
        );
      }).toList();
    },
  ),
),
        ),
      ),
    );
  }

  // === Chart tahunan ===
  Widget _buildYearlyChart() {
    final today = DateTime.now();

    final spotsPenjualan = <FlSpot>[];
    final spotsPiutang = <FlSpot>[];

    for (int month = 1; month <= 12; month++) {
      final dataThisMonth = dailyReport.entries.where((entry) {
        final date = DateTime.tryParse(entry.key);
        return date != null &&
            date.year == today.year &&
            date.month == month;
      });

      int totalPenjualan = 0;
      int totalPiutang = 0;

      for (var entry in dataThisMonth) {
        totalPenjualan += entry.value["penjualan"] ?? 0;
        totalPiutang += entry.value["piutang"] ?? 0;
      }

      spotsPenjualan.add(FlSpot(month.toDouble(), totalPenjualan.toDouble()));
      spotsPiutang.add(FlSpot(month.toDouble(), totalPiutang.toDouble()));
    }

    final maxY = [
      ...spotsPenjualan.map((e) => e.y),
      ...spotsPiutang.map((e) => e.y),
      100
    ].reduce((a, b) => a > b ? a : b) * 1.2;

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          titlesData: const FlTitlesData(show: true),
          gridData: const FlGridData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spotsPenjualan,
              isCurved: true,
              preventCurveOverShooting: true,
              color: Colors.green,
              barWidth: 3,
            ),
            LineChartBarData(
              spots: spotsPiutang,
              isCurved: true,
              preventCurveOverShooting: true,
              color: Colors.red,
              barWidth: 3,
            ),
          ],

          //  Tooltip custom
    lineTouchData: LineTouchData(
  touchTooltipData: LineTouchTooltipData(
    tooltipRoundedRadius: 8,
    tooltipPadding: const EdgeInsets.all(8),
    getTooltipColor: (touchedSpot) {
      // bisa dinamis berdasarkan bar/spot
      return Colors.black.withValues(alpha: 0.7);
    },
    getTooltipItems: (touchedSpots) {
      return touchedSpots.map((spot) {
        return LineTooltipItem(
          '${spot.bar.color == Colors.green ? "Penjualan" : "Piutang"}\n${spot.y.toInt()}',
          TextStyle(
            color: spot.bar.color, // teks ikut warna garis
            fontWeight: FontWeight.bold,
          ),
        );
      }).toList();
    },
  ),
),
        ),
      ),
    );
  }

  // === Ringkasan mingguan ===
  Map<String, int> _getWeeklySummary() {
    final today = DateTime.now();
    int totalPenjualan = 0;
    int totalPiutang = 0;
    int totalCount = 0;

    for (int i = 0; i < 7; i++) {
      final d = today.subtract(Duration(days: i));
      final key =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      final data =
          dailyReport[key] ?? {"penjualan": 0, "piutang": 0, "count": 0};
      totalPenjualan += data["penjualan"] ?? 0;
      totalPiutang += data["piutang"] ?? 0;
      totalCount += data["count"] ?? 0;
    }

    return {
      "penjualan": totalPenjualan,
      "piutang": totalPiutang,
      "count": totalCount,
    };
  }

  // === Ringkasan bulanan ===
  Map<String, int> _getMonthlySummary() {
    final today = DateTime.now();
    int totalPenjualan = 0;
    int totalPiutang = 0;
    int totalCount = 0;

    for (var entry in dailyReport.entries) {
      final date = DateTime.tryParse(entry.key);
      if (date == null) continue;

      if (date.year == today.year && date.month == today.month) {
        final data = entry.value;
        totalPenjualan += data["penjualan"] ?? 0;
        totalPiutang += data["piutang"] ?? 0;
        totalCount += data["count"] ?? 0;
      }
    }

    return {
      "penjualan": totalPenjualan,
      "piutang": totalPiutang,
      "count": totalCount,
    };
  }

  // === Ringkasan tahunan ===
  Map<String, int> _getYearlySummary() {
    final today = DateTime.now();
    int totalPenjualan = 0;
    int totalPiutang = 0;
    int totalCount = 0;

    for (var entry in dailyReport.entries) {
      final date = DateTime.tryParse(entry.key);
      if (date == null) continue;

      if (date.year == today.year) {
        final data = entry.value;
        totalPenjualan += data["penjualan"] ?? 0;
        totalPiutang += data["piutang"] ?? 0;
        totalCount += data["count"] ?? 0;
      }
    }

    return {
      "penjualan": totalPenjualan,
      "piutang": totalPiutang,
      "count": totalCount,
    };
  }

  // === UI ===
  @override
  Widget build(BuildContext context) {
    final todayKey =
        "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
    final todayData =
        dailyReport[todayKey] ?? {"penjualan": 0, "piutang": 0, "count": 0};
    final weeklyData = _getWeeklySummary();
    final monthlyData = _getMonthlySummary();
    final yearlyData = _getYearlySummary();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Laporan"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Harian"),
              Tab(text: "Mingguan"),
              Tab(text: "Bulanan"),
              Tab(text: "Tahunan"),
            ],
          ),
        ),
        drawer: const AppDrawer(),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // === Tab Harian ===
                  RefreshIndicator(
                    onRefresh: _loadReport,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _summaryCard(
                                title: "Penjualan",
                                value: _formatCurrency(
                                    todayData['penjualan'] ?? 0),
                                color: Colors.green,
                                subtitle: todayKey,
                              ),
                            ),
                            Expanded(
                              child: _summaryCard(
                                title: "Piutang",
                                value: _formatCurrency(
                                    todayData['piutang'] ?? 0),
                                color: Colors.red,
                                subtitle: "Belum Lunas",
                              ),
                            ),
                            Expanded(
                              child: _summaryCard(
                                title: "Transaksi",
                                value: "${todayData['count'] ?? 0}",
                                color: Colors.blue,
                                subtitle: "Pesanan",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                //const Text("Transaksi Harian"),
                                _buildHourlyChart(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // === Tab Mingguan ===
                  RefreshIndicator(
                    onRefresh: _loadReport,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _summaryCard(
                                title: "Penjualan",
                                value: _formatCurrency(
                                    weeklyData['penjualan'] ?? 0),
                                color: Colors.green,
                                subtitle: "7 Hari",
                              ),
                            ),
                            Expanded(
                              child: _summaryCard(
                                title: "Piutang",
                                value: _formatCurrency(
                                    weeklyData['piutang'] ?? 0),
                                color: Colors.red,
                                subtitle: "7 Hari",
                              ),
                            ),
                            Expanded(
                              child: _summaryCard(
                                title: "Transaksi",
                                value: "${weeklyData['count'] ?? 0}",
                                color: Colors.blue,
                                subtitle: "7 Hari",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                //const Text("Transaksi 7 Hari Terakhir"),
                                _buildWeeklyChart(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // === Tab Bulanan ===
                  RefreshIndicator(
                    onRefresh: _loadReport,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _summaryCard(
                                title: "Penjualan",
                                value: _formatCurrency(
                                    monthlyData['penjualan'] ?? 0),
                                color: Colors.green,
                                subtitle: "Bulan Ini",
                              ),
                            ),
                            Expanded(
                              child: _summaryCard(
                                title: "Piutang",
                                value: _formatCurrency(
                                    monthlyData['piutang'] ?? 0),
                                color: Colors.red,
                                subtitle: "Bulan Ini",
                              ),
                            ),
                            Expanded(
                              child: _summaryCard(
                                title: "Transaksi",
                                value: "${monthlyData['count'] ?? 0}",
                                color: Colors.blue,
                                subtitle: "Bulan Ini",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                //const Text("Transaksi Bulan Ini"),
                                _buildMonthlyChart(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // === Tab Tahunan ===
                  RefreshIndicator(
                    onRefresh: _loadReport,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _summaryCard(
                                title: "Penjualan",
                                value: _formatCurrency(
                                    yearlyData['penjualan'] ?? 0),
                                color: Colors.green,
                                subtitle: "Tahun Ini",
                              ),
                            ),
                            Expanded(
                              child: _summaryCard(
                                title: "Piutang",
                                value: _formatCurrency(
                                    yearlyData['piutang'] ?? 0),
                                color: Colors.red,
                                subtitle: "Tahun Ini",
                              ),
                            ),
                            Expanded(
                              child: _summaryCard(
                                title: "Transaksi",
                                value: "${yearlyData['count'] ?? 0}",
                                color: Colors.blue,
                                subtitle: "Tahun Ini",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                //const Text("Transaksi Tahunan"),
                                _buildYearlyChart(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required Color color,
    required String subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: color, fontSize: 14)),
            const SizedBox(height: 8),
            Text(value,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
