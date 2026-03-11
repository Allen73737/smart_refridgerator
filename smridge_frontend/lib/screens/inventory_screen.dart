import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AddInventoryScreen extends StatefulWidget {
  final Function(String, int, DateTime, File?) onSave;

  const AddInventoryScreen({
    super.key,
    required this.onSave,
  });

  @override
  State<AddInventoryScreen> createState() =>
      _AddInventoryScreenState();
}

class _AddInventoryScreenState
    extends State<AddInventoryScreen> {

  final nameController =
      TextEditingController();
  final unitsController =
      TextEditingController();

  DateTime? expiry;
  File? imageFile;

  final DateTime currentDate =
      DateTime.now();

  Future pickImage() async {
    final picked =
        await ImagePicker()
            .pickImage(
                source:
                    ImageSource.gallery);
    if (picked != null) {
      setState(() {
        imageFile =
            File(picked.path);
      });
    }
  }

  Future pickDate() async {
    final date =
        await showDatePicker(
      context: context,
      firstDate:
          DateTime.now(),
      lastDate:
          DateTime(2030),
      initialDate:
          DateTime.now(),
    );
    if (date != null) {
      setState(() {
        expiry = date;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF101820),
      appBar:
          AppBar(title:
              const Text("Add Inventory")),
      body: Padding(
        padding:
            const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [

            Text(
              "Current Date: ${currentDate.toLocal().toString().split(' ')[0]}",
              style:
                  const TextStyle(
                      color:
                          Colors.white),
            ),

            const SizedBox(height: 20),

            TextField(
              controller:
                  nameController,
              decoration:
                  const InputDecoration(
                labelText:
                    "Item Name",
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              controller:
                  unitsController,
              keyboardType:
                  TextInputType.number,
              decoration:
                  const InputDecoration(
                labelText: "Units",
              ),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: pickDate,
              child: Text(
                  expiry == null
                      ? "Select Expiry Date"
                      : expiry!
                          .toString()
                          .split(
                              ' ')[0]),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: pickImage,
              child:
                  const Text(
                      "Upload Image"),
            ),

            const Spacer(),

            ElevatedButton(
              onPressed: () {
                widget.onSave(
                  nameController.text,
                  int.parse(
                      unitsController
                          .text),
                  expiry!,
                  imageFile,
                );
                Navigator.pop(
                    context);
              },
              child:
                  const Text(
                      "Save Item"),
            ),
          ],
        ),
      ),
    );
  }
}
