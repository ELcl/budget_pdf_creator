class Client {
  final int? id;
  final String name;
  final String phone;
  final String address;
  final String email;

  Client({
    this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.email,
  });

  // Convertir de Map (SQLite) a Objeto Client
  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'],
      name: map['name'],
      phone: map['phone'],
      address: map['address'],
      email: map['email'],
    );
  }

  // Convertir de Objeto Client a Map (para insertar en SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'email': email,
    };
  }
}