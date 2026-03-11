import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../models/inventory_item.dart';
import '../utils/snackbar_utils.dart';
import 'add_inventory_screen.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final Function(InventoryItem) onSave;
  final VoidCallback? onBack;

  const BarcodeScannerScreen({super.key, required this.onSave, this.onBack});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController();
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
      final String barcode = barcodes.first.rawValue!;
      
      setState(() {
        _isProcessing = true;
      });
      
      // Suspend camera while fetching
      controller.stop();

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.tealAccent),
        ),
      );

      final result = await ApiService.scanBarcode(barcode);
      
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (result != null) {
        // Data found
        final newItem = InventoryItem(
          name: result['name'] ?? '',
          brand: result['brand'],
          category: result['category'],
          quantity: 1, // Default from back-end logic
          weight: result['weight'] != null ? double.tryParse(result['weight'].toString()) : null,
          litres: result['litres'] != null ? double.tryParse(result['litres'].toString()) : null,
          barcode: barcode,
          isPackaged: true,
          expiryDate: DateTime.parse(result['expiryDate']),
          expirySource: result['expirySource'],
          imageUrl: result['imageUrl'],
          dateAdded: DateTime.now(),
        );
        widget.onSave(newItem);
      } else {
        // Not found message
        SnackbarUtils.showWarning(context, "Product not found. Please enter details manually.");
        
        widget.onSave(
          InventoryItem(
            name: '',
            barcode: barcode,
            isPackaged: true,
            quantity: 1,
            expiryDate: DateTime.now().add(const Duration(days: 7)),
            dateAdded: DateTime.now(),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final themeType = themeProvider.currentTheme;
    final isLight = themeType == ThemeType.light;
    
    Color textColor = isLight ? Colors.black87 : Colors.white;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: isLight ? Colors.white.withOpacity(0.8) : Colors.black.withOpacity(0.5),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: textColor),
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text("Scan Barcode", style: TextStyle(color: textColor)),
        actions: [
          IconButton(
            color: isLight ? Colors.amber[700] : Colors.yellow,
            icon: const Icon(Icons.flash_on),
            iconSize: 32.0,
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: isLight ? Colors.teal : Colors.tealAccent, width: 4),
                borderRadius: BorderRadius.circular(12),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
             .fadeIn(duration: 800.ms).scaleXY(begin: 0.95, end: 1.05),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Text(
              "Align barcode within the frame",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(color: isLight ? Colors.black54 : Colors.black87, blurRadius: 10)],
              ),
            ).animate().fade().slideY(begin: 0.5),
          ),
        ],
      ),
    );
  }
}
