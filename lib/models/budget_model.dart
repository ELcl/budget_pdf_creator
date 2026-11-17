class BudgetItem {
  final int? id;
  final int? budgetId;
  final String description;
  final double quantity;
  final double unitPrice;
  final double subtotal;

  BudgetItem({
    this.id,
    this.budgetId,
    required this.description,
    required this.quantity,
    required this.unitPrice,
  }) : subtotal = quantity * unitPrice; // Se calcula automáticamente

  factory BudgetItem.fromMap(Map<String, dynamic> map) {
    return BudgetItem(
      id: map['id'],
      budgetId: map['budget_id'],
      description: map['description'],
      quantity: map['quantity'],
      unitPrice: map['unit_price'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'budget_id': budgetId,
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'subtotal': subtotal,
    };
  }
}

class Budget {
  final int? id;
  final int clientId;
  final String title; // 👈 Nuevo campo para el nombre del presupuesto
  final String date;
  final double totalAmount;
  final String status; // Ejemplo: 'Emitido', 'Borrador'
  final List<BudgetItem> items;

  Budget({
    this.id,
    required this.clientId,
    required this.title,
    required this.date,
    required this.totalAmount,
    required this.status,
    required this.items,
  });

  factory Budget.fromMap(Map<String, dynamic> map, List<BudgetItem> items) {
    return Budget(
      id: map['id'],
      clientId: map['client_id'],
      title: map['title'] ?? 'Cotización sin título', // 👈 Valor por defecto por seguridad
      date: map['date'],
      totalAmount: map['total_amount'],
      status: map['status'],
      items: items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client_id': clientId,
      'title': title, // 👈 Se incluye al guardar en la BD
      'date': date,
      'total_amount': totalAmount,
      'status': status,
    };
  }
}