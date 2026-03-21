import 'package:add_2_calendar/add_2_calendar.dart';
import '../models/inventory_item.dart';

class CalendarService {
  static Future<bool> addEvent({
    required String title,
    required String description,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final Event event = Event(
      title: title,
      description: description,
      location: 'Smridge Fridge',
      startDate: startDate,
      endDate: endDate,
      allDay: false,
    );

    try {
      return await Add2Calendar.addEvent2Cal(event);
    } catch (e) {
      print("Error adding to calendar: $e");
      return false;
    }
  }

  static Future<void> syncItemExpiry(InventoryItem item) async {
    final String title = "Expiry: ${item.name}";
    final String description = "Your ${item.name} in the Smridge Fridge is expiring. \nCategory: ${item.category}\nNotes: ${item.notes ?? 'None'}";
    
    // Set event for the same day as expiryDate, or custom reminder date
    final DateTime targetDate = item.expiryDate;
    
    await addEvent(
      title: title,
      description: description,
      startDate: targetDate,
      endDate: targetDate.add(const Duration(hours: 1)),
    );
  }
}
