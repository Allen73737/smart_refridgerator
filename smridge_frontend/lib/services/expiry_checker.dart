// import 'dart:async';
// import '../models/inventory_item.dart';
// import 'notification_service.dart';

// class ExpiryChecker {
//   final List<InventoryItem> inventory;
//   final Set<String> notifiedItems = {};
//   late Timer timer;

//   ExpiryChecker(this.inventory);

//   void start() {
//     timer = Timer.periodic(
//       const Duration(seconds: 30),
//       (_) => check(),
//     );
//   }

//   void check() {
//     for (var item in inventory) {
//       if (item.isExpired &&
//           !notifiedItems.contains(item.name)) {
//         NotificationService()
//             .showExpiryNotification(item.name);
//         notifiedItems.add(item.name);
//       }
//     }
//   }

//   void dispose() {
//     timer.cancel();
//   }
// }
