import 'package:flutter/material.dart';
import '../models/client_model.dart';
import '../models/budget_model.dart';
import '../services/database_helper.dart';
import '../services/pdf_service.dart';

class BudgetEditorScreen extends StatefulWidget {
  final Budget? budgetToEdit; // 👈 Opcional: si viene, estamos editando

  const BudgetEditorScreen({super.key, this.budgetToEdit});

  @override
  State<BudgetEditorScreen> createState() => _BudgetEditorScreenState();
}

class _BudgetEditorScreenState extends State<BudgetEditorScreen> {
  List<Client> _clients = [];
  Client? _selectedClient;
  bool _isLoading = true;

  // Controlador para el título personalizado del presupuesto
  final TextEditingController _titleController = TextEditingController();
  
  // Variable para manejar el estado del presupuesto
  String _selectedStatus = 'Emitido';

  final List<_ItemRowData> _itemRows = [];

  bool get _isEditing => widget.budgetToEdit != null;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var row in _itemRows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    final clients = await DatabaseHelper.instance.getClients();
    
    setState(() {
      _clients = clients;
      
      if (_clients.isNotEmpty) {
        if (_isEditing) {
          // Seleccionar el cliente correspondiente al presupuesto que se edita
          try {
            _selectedClient = _clients.firstWhere((c) => c.id == widget.budgetToEdit!.clientId);
          } catch (_) {
            _selectedClient = _clients.first;
          }
          
          // Cargar el título y el estado existente
          _titleController.text = widget.budgetToEdit!.title;
          _selectedStatus = widget.budgetToEdit!.status;

          // Cargar los ítems existentes del presupuesto
          for (var item in widget.budgetToEdit!.items) {
            final row = _ItemRowData();
            row.descController.text = item.description;
            row.qtyController.text = item.quantity.toString();
            row.priceController.text = item.unitPrice.toString();
            _itemRows.add(row);
          }
        } else {
          _selectedClient = _clients.first;
          _selectedStatus = 'Emitido';
        }
      }

      // Si por alguna razón no hay filas (presupuesto vacío), agregar una por defecto
      if (_itemRows.isEmpty) {
        _itemRows.add(_ItemRowData());
      }

      _isLoading = false;
    });
  }

  void _addItemRow() {
    setState(() {
      _itemRows.add(_ItemRowData());
    });
  }

  void _removeItemRow(int index) {
    setState(() {
      final removed = _itemRows.removeAt(index);
      removed.dispose();
    });
  }

  double _calculateTotal() {
    double total = 0.0;
    for (var row in _itemRows) {
      total += row.subtotal;
    }
    return total;
  }

  Budget? _buildCurrentBudgetObject() {
    if (_selectedClient == null || _itemRows.isEmpty) return null;

    List<BudgetItem> items = [];
    for (var row in _itemRows) {
      if (row.descController.text.trim().isEmpty) continue;
      double qty = double.tryParse(row.qtyController.text) ?? 1.0;
      double price = double.tryParse(row.priceController.text) ?? 0.0;

      items.add(BudgetItem(
        description: row.descController.text.trim(),
        quantity: qty,
        unitPrice: price,
      ));
    }

    if (items.isEmpty) return null;

    return Budget(
      id: _isEditing ? widget.budgetToEdit!.id : null, // Mantiene el ID si estamos editando
      clientId: _selectedClient!.id!,
      title: _titleController.text.trim().isEmpty 
          ? 'Cotización sin título' 
          : _titleController.text.trim(),
      date: _isEditing ? widget.budgetToEdit!.date : DateTime.now().toIso8601String().split('T')[0],
      totalAmount: _calculateTotal(),
      status: _selectedStatus, // 👈 Pasamos el estado seleccionado
      items: items,
    );
  }

  Future<void> _saveBudget() async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona un cliente')),
      );
      return;
    }

    final budgetToSave = _buildCurrentBudgetObject();
    if (budgetToSave == null || budgetToSave.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega y completa al menos un ítem válido')),
      );
      return;
    }

    if (_isEditing) {
      // Actualizar registro existente
      await DatabaseHelper.instance.updateBudget(budgetToSave);
    } else {
      // Insertar nuevo registro
      await DatabaseHelper.instance.insertBudget(budgetToSave);
    }

    Navigator.pop(context, true);
  }

  Future<void> _generatePdfDirectly() async {
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un cliente antes de generar el PDF')),
      );
      return;
    }

    final currentBudget = _buildCurrentBudgetObject();
    if (currentBudget == null || currentBudget.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa los ítems para la cotización en PDF')),
      );
      return;
    }

    await PdfService.saveAndOpenPdf(
      budget: currentBudget,
      client: _selectedClient!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final titleAppBar = _isEditing ? 'Editar Cotización' : 'Crear Cotización';

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(titleAppBar)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_clients.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(titleAppBar)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'No hay clientes registrados. Debes registrar al menos un cliente antes de crear una cotización.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(titleAppBar),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Generar PDF',
            onPressed: _generatePdfDirectly,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Guardar',
            onPressed: _saveBudget,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Campo para el Título del Presupuesto
              const Text('Título del Presupuesto:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Ej. Mantenimiento Redes UMSA',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Selector de Estado del Presupuesto
              const Text('Estado del Presupuesto:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedStatus,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'Emitido',
                    child: Text('Emitido', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  ),
                  DropdownMenuItem(
                    value: 'Aceptado',
                    child: Text('Aceptado', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                  DropdownMenuItem(
                    value: 'Rechazado',
                    child: Text('Rechazado', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedStatus = value;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // 3. Selector de cliente
              const Text('Seleccionar Cliente:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<Client>(
                value: _selectedClient,
                items: _clients.map((client) {
                  return DropdownMenuItem(
                    value: client,
                    child: Text(client.name),
                  );
                }).toList(),
                onChanged: (client) {
                  setState(() {
                    _selectedClient = client;
                  });
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 16),

              // 4. Cabecera de ítems
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Detalle de Ítems:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: _addItemRow,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Añadir ítem'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // 5. Lista de ítems
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _itemRows.length,
                itemBuilder: (context, index) {
                  final row = _itemRows[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: row.descController,
                                  decoration: const InputDecoration(labelText: 'Descripción (ej. Monitor 30")'),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: _itemRows.length > 1 ? () => _removeItemRow(index) : null,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: row.qtyController,
                                  decoration: const InputDecoration(labelText: 'Cant.'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: row.priceController,
                                  decoration: const InputDecoration(labelText: 'P. Unit.'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Sub: Bs. ${row.subtotal.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),

              // 6. Panel de Total
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('TOTAL:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      'Bs. ${_calculateTotal().toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Botón de Guardar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  onPressed: _saveBudget,
                  icon: const Icon(Icons.save),
                  label: Text(_isEditing ? 'Actualizar Presupuesto' : 'Guardar Presupuesto', style: const TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),

              // Botón de PDF
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.red[700]!),
                  ),
                  onPressed: _generatePdfDirectly,
                  icon: Icon(Icons.picture_as_pdf, color: Colors.red[700]),
                  label: Text('Generar PDF y Compartir', style: TextStyle(fontSize: 15, color: Colors.red[700])),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemRowData {
  final TextEditingController descController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController priceController = TextEditingController(text: '0');

  void dispose() {
    descController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }

  double get subtotal {
    double q = double.tryParse(qtyController.text) ?? 0;
    double p = double.tryParse(priceController.text) ?? 0;
    return q * p;
  }
}