import 'package:flutter/material.dart';
import '../models/budget_model.dart';
import '../models/client_model.dart';
import '../services/database_helper.dart';
import '../services/pdf_service.dart';

class BudgetDetailScreen extends StatefulWidget {
  final int budgetId;

  const BudgetDetailScreen({super.key, required this.budgetId});

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  bool _isLoading = true;
  Budget? _budget;
  Client? _client;

  @override
  void initState() {
    super.initState();
    _loadBudgetData();
  }

  Future<void> _loadBudgetData() async {
    final budget = await DatabaseHelper.instance.getBudgetById(widget.budgetId);
    if (budget != null) {
      final client = await DatabaseHelper.instance.getClientById(budget.clientId);
      setState(() {
        _budget = budget;
        _client = client;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle de Presupuesto')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_budget == null || _client == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle de Presupuesto')),
        body: const Center(child: Text('No se encontró el presupuesto especificado.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Presupuesto'),
        actions: [
          // Botón superior derecho: Descargar / Guardar copia con flecha intuitiva
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Descargar / Guardar PDF',
            onPressed: () => PdfService.saveAndOpenPdf(
              budget: _budget!,
              client: _client!,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tarjeta de información general y cliente
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _budget!.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      const Divider(height: 20),
                      Text('Cliente: ${_client!.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('Teléfono: ${_client!.phone}', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text('Dirección: ${_client!.address}', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text('Fecha de Emisión: ${_budget!.date}', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Productos / Servicios Cotizados:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),

              // Lista de Ítems
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _budget!.items.length,
                itemBuilder: (context, index) {
                  final item = _budget!.items[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.description,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Cant: ${item.quantity}  |  P. Unit: Bs. ${item.unitPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            'Bs. ${item.subtotal.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueGrey),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Total General
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL GENERAL:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      'Bs. ${_budget!.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botón inferior: Compartir Presupuesto (Versátil para cualquier app)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => PdfService.shareBudgetPdf(
                    budget: _budget!,
                    client: _client!,
                  ),
                  icon: const Icon(Icons.share),
                  label: const Text('Compartir Presupuesto', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}