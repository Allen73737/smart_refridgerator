import 'package:flutter/material.dart';
import '../models/inventory_item.dart';

class AddItemScreen extends StatefulWidget {
  final Function(InventoryItem) onAdd;

  const AddItemScreen({
    super.key,
    required this.onAdd,
  });

  @override
  State<AddItemScreen> createState() =>
      _AddItemScreenState();
}

class _AddItemScreenState
    extends State<AddItemScreen> {

  final nameController = TextEditingController();
  final quantityController =
      TextEditingController();

  DateTime? selectedDate;

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar:
          AppBar(title: const Text("Add Item")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Item Name",
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: quantityController,
              keyboardType:
                  TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Quantity",
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () async {

                final picked =
                    await showDatePicker(
                  context: context,
                  firstDate:
                      DateTime.now(),
                  lastDate:
                      DateTime.now().add(
                          const Duration(
                              days: 365)),
                );

                if (picked != null) {
                  setState(() {
                    selectedDate = picked;
                  });
                }
              },
              child:
                  const Text("Select Expiry Date"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {

                if (nameController.text.isEmpty ||
                    quantityController.text.isEmpty ||
                    selectedDate == null) {
                  return;
                }

                final item = InventoryItem(
                  name: nameController.text,
                  quantity: int.parse(
                      quantityController.text),
                  expiryDate: selectedDate!,
                  dateAdded: DateTime.now(),
                );

                widget.onAdd(item);
                Navigator.pop(context);
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }
}
