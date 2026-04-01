class InventoryItem {
  final String? id;
  final String name;
  final String? category;
  final bool isPackaged;
  final int quantity;
  final double? weight; // Added for Load Cell Support
  final double? litres; // For liquid items
  final String? barcode;
  final String? brand;
  final DateTime expiryDate;
  final String? expirySource;
  final DateTime? reminderDate; // 👈 New field
  final String? notes;
  final DateTime dateAdded;
  final String? imagePath;
  final String? imageUrl;

  InventoryItem({
    this.id,
    required this.name,
    this.category,
    this.isPackaged = false,
    required this.quantity,
    this.weight,
    this.litres,
    this.barcode,
    this.brand,
    required this.expiryDate,
    this.expirySource,
    this.reminderDate,
    this.notes,
    required this.dateAdded,
    this.imagePath,
    this.imageUrl,
  });

  bool get isExpired => expiryDate.isBefore(DateTime.now());
  bool get isCritical => !isExpired && daysLeft <= 3;
  int get units => quantity;
  int get daysLeft => expiryDate.difference(DateTime.now()).inDays;

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['_id'],
      name: json['name'] ?? 'Unknown',
      category: json['category'],
      isPackaged: json['packaged'] ?? json['isPackaged'] ?? false,
      quantity: int.tryParse(json['quantity']?.toString() ?? "") ?? 1,
      weight: double.tryParse(json['weight']?.toString() ?? "") ?? 0.0,
      litres: double.tryParse(json['litres']?.toString() ?? "") ?? 0.0,
      barcode: json['barcode'],
      brand: json['brand'],
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate']).toLocal()
          : DateTime.now().add(const Duration(days: 7)),
      expirySource: json['expirySource'],
      reminderDate: json['reminderDate'] != null 
          ? DateTime.parse(json['reminderDate']).toLocal() 
          : null,
      notes: json['notes'],
      // Backend uses 'createdAt' (Mongoose auto-field), not 'dateAdded'
      dateAdded: json['createdAt'] != null
          ? DateTime.parse(json['createdAt']).toLocal()
          : (json['dateAdded'] != null ? DateTime.parse(json['dateAdded']).toLocal() : DateTime.now()),
      imagePath: json['imagePath'],
      // Backend stores image URL in 'image' field, fallback to 'imageUrl'
      imageUrl: json['imageUrl'] ?? json['image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'category': category,
      'isPackaged': isPackaged,
      'quantity': quantity,
      'weight': weight,
      'litres': litres,
      'barcode': barcode,
      'brand': brand,
      'expiryDate': expiryDate.toIso8601String(),
      'expirySource': expirySource,
      'reminderDate': reminderDate?.toIso8601String(),
      'notes': notes,
      'dateAdded': dateAdded.toIso8601String(),
      'imagePath': imagePath,
      'image': imageUrl, // 💎 Aligned with Backend 'image' field
    };
  }

  InventoryItem copyWith({
    String? id,
    String? name,
    String? category,
    bool? isPackaged,
    int? quantity,
    double? weight,
    double? litres,
    String? barcode,
    String? brand,
    DateTime? expiryDate,
    String? expirySource,
    DateTime? reminderDate,
    String? notes,
    DateTime? dateAdded,
    String? imagePath,
    String? imageUrl,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      isPackaged: isPackaged ?? this.isPackaged,
      quantity: quantity ?? this.quantity,
      weight: weight ?? this.weight,
      litres: litres ?? this.litres,
      barcode: barcode ?? this.barcode,
      brand: brand ?? this.brand,
      expiryDate: expiryDate ?? this.expiryDate,
      expirySource: expirySource ?? this.expirySource,
      reminderDate: reminderDate ?? this.reminderDate,
      notes: notes ?? this.notes,
      dateAdded: dateAdded ?? this.dateAdded,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
