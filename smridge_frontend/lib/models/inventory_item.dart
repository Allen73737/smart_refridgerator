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
    this.notes,
    required this.dateAdded,
    this.imagePath,
    this.imageUrl,
  });
}
