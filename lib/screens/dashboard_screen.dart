import 'package:flutter/material.dart';
import '../models/budget_model.dart';
import '../services/database_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  List<Budget> _budgets = [];

  // Métricas
  double _totalAmount = 0.0;
  double _acceptedAmount = 0.0;
  double _pendingAmount = 0.0;
  
  int _countIssued = 0;
  int _countAccepted = 0;
  int _countRejected = 0;

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    final budgets = await DatabaseHelper.instance.getBudgets();
    
    double total = 0.0;
    double accepted = 0.0;
    double pending = 0.0;
    int issued = 0;
    int acc = 0;
    int rej = 0;

    for (var b in budgets) {
      total += b.totalAmount;
      if (b.status == 'Aceptado') {
        accepted += b.totalAmount;
        acc++;
      } else if (b.status == 'Rechazado') {
        rej++;
      } else {
        pending += b.totalAmount; // Consideramos Emitido como pendiente/activo
        issued++;
      }
    }

    setState(() {
      _budgets = budgets;
      _totalAmount = total;
      _acceptedAmount = accepted;
      _pendingAmount = pending;
      _countIssued = issued;
      _countAccepted = acc;
      _countRejected = rej;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard y Métricas'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _budgets.isEmpty
              ? const Center(
                  child: Text(
                    'No hay suficientes datos para mostrar estadísticas',
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMetrics,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Resumen Financiero Global',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        
                        // Tarjeta Principal de Monto Total Cotizado
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue.shade700, Colors.blue.shade900],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'MONTO TOTAL COTIZADO',
                                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Bs. ${_totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_budgets.length} cotizaciones registradas en total',
                                style: const TextStyle(color: Colors.white60, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tarjetas Secundarias: Aceptados vs Pendientes (Emitidos)
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                title: 'Aceptados',
                                amount: _acceptedAmount,
                                count: _countAccepted,
                                color: Colors.green,
                                icon: Icons.check_circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricCard(
                                title: 'Emitidos / Activos',
                                amount: _pendingAmount,
                                count: _countIssued,
                                color: Colors.blue,
                                icon: Icons.hourglass_top,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        const Text(
                          'Desglose por Estado',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),

                        // Lista de conteos por estatus
                        _buildStatusRow('Aceptados', _countAccepted, Colors.green),
                        const Divider(),
                        _buildStatusRow('Emitidos', _countIssued, Colors.blue),
                        const Divider(),
                        _buildStatusRow('Rechazados', _countRejected, Colors.red),
                        
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required double amount,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title, 
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13), 
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Bs. ${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '$count cotizaciones',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
          Chip(
            label: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            backgroundColor: color.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ],
      ),
    );
  }
}