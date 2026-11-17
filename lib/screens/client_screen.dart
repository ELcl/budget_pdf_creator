import 'package:flutter/material.dart';
import '../models/client_model.dart';
import '../services/database_helper.dart';

class ClientScreen extends StatefulWidget {
  const ClientScreen({super.key});

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  List<Client> _allClients = [];
  List<Client> _filteredClients = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchController.addListener(_filterClients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Cargar clientes desde SQLite
  Future<void> _loadClients() async {
    final clients = await DatabaseHelper.instance.getClients();
    setState(() {
      _allClients = clients;
      _filteredClients = clients;
      _isLoading = false;
    });
    // Aplicar filtro por si había texto escrito al recargar
    _filterClients();
  }

  // Búsqueda reactiva en tiempo real
  void _filterClients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredClients = _allClients.where((client) {
        final nameMatches = client.name.toLowerCase().contains(query);
        final phoneMatches = client.phone.toLowerCase().contains(query);
        final addressMatches = client.address.toLowerCase().contains(query);
        return nameMatches || phoneMatches || addressMatches;
      }).toList();
    });
  }

  // Modal unificado para Crear o Editar un cliente
  void _showClientDialog({Client? clientToEdit}) {
    final isEditing = clientToEdit != null;
    final nameController = TextEditingController(text: isEditing ? clientToEdit.name : '');
    final phoneController = TextEditingController(text: isEditing ? clientToEdit.phone : '');
    final addressController = TextEditingController(text: isEditing ? clientToEdit.address : '');
    final emailController = TextEditingController(text: isEditing ? clientToEdit.email : '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Editar Cliente' : 'Nuevo Cliente'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nombre *'),
                ),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Teléfono / Celular'),
                  keyboardType: TextInputType.phone,
                ),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Dirección o Zona'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Correo Electrónico'),
                  keyboardType: TextInputType.emailAddress,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  return; // El nombre es obligatorio
                }

                if (isEditing) {
                  // Actualizar cliente existente manteniendo su ID
                  final updatedClient = Client(
                    id: clientToEdit.id,
                    name: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                    address: addressController.text.trim(),
                    email: emailController.text.trim(),
                  );
                  await DatabaseHelper.instance.updateClient(updatedClient);
                } else {
                  // Crear nuevo cliente
                  final newClient = Client(
                    name: nameController.text.trim(),
                    phone: phoneController.text.trim(),
                    address: addressController.text.trim(),
                    email: emailController.text.trim(),
                  );
                  await DatabaseHelper.instance.insertClient(newClient);
                }

                Navigator.pop(context);
                _loadClients(); // Recargar la lista
              },
              child: Text(isEditing ? 'Actualizar' : 'Guardar'),
            ),
          ],
        );
      },
    );
  }

  // Diálogo de confirmación para eliminar cliente con icono rojo
  void _confirmDeleteClient(Client client) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar Cliente'),
          content: Text('¿Estás seguro de que deseas eliminar a "${client.name}"? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () async {
                await DatabaseHelper.instance.deleteClient(client.id!);
                Navigator.pop(context);
                _loadClients();
              },
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Clientes'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Barra de búsqueda reactiva superior
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Buscar cliente por nombre, teléfono...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                
                // Lista de clientes filtrados
                Expanded(
                  child: _filteredClients.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.people_outline, size: 80, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No se encontraron clientes',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredClients.length,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemBuilder: (context, index) {
                            final client = _filteredClients[index];
                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  child: Text(
                                    client.name.isNotEmpty ? client.name[0].toUpperCase() : 'C',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                  ),
                                ),
                                title: Text(
                                  client.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'Tel: ${client.phone.isNotEmpty ? client.phone : "Sin teléfono"}\nDir: ${client.address.isNotEmpty ? client.address : "Sin dirección"}',
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Botón Editar
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      tooltip: 'Editar cliente',
                                      onPressed: () => _showClientDialog(clientToEdit: client),
                                    ),
                                    // Botón Eliminar con basurero rojo
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      tooltip: 'Eliminar cliente',
                                      onPressed: () => _confirmDeleteClient(client),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showClientDialog(),
        child: const Icon(Icons.person_add),
      ),
    );
  }
}