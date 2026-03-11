class ExpiryEstimator {
  // Dictionary locking products to their LOWEST safest refrigerator expiry limit in days
  static const Map<String, int> productExpiryDays = {
    // Dairy & Eggs
    'milk': 3,
    'cheese': 7,
    'butter': 30,
    'yogurt': 5,
    'curd': 3,
    'paneer': 3,
    'cream': 5,
    'egg': 21,
    'boiled egg': 7,
    'omelet': 3,
    'ghee': 180,
    'ice cream': 60,
    'margarine': 90,
    'sour cream': 7,
    'cream cheese': 14,

    // Fruits
    'apple': 7,
    'banana': 3,
    'orange': 10,
    'mango': 5,
    'grapes': 5,
    'strawberry': 2,
    'blueberry': 3,
    'raspberry': 2,
    'blackberry': 2,
    'watermelon': 5,
    'melon': 5,
    'cantaloupe': 5,
    'peach': 3,
    'plum': 3,
    'pear': 5,
    'cherry': 4,
    'kiwi': 5,
    'pineapple': 3,
    'lemon': 14,
    'lime': 14,
    'avocado': 3,

    // Vegetables
    'carrot': 14,
    'tomato': 5,
    'potato': 30, // Usually pantry, but if in fridge
    'onion': 30,
    'broccoli': 5,
    'spinach': 3,
    'lettuce': 5,
    'cabbage': 7,
    'cauliflower': 5,
    'cucumber': 7,
    'zucchini': 5,
    'eggplant': 5,
    'bell pepper': 7,
    'chili': 14,
    'garlic': 60,
    'ginger': 30,
    'mushroom': 3,
    'celery': 10,
    'corn': 3,
    'peas': 3,
    'asparagus': 3,
    'kale': 5,
    'green bean': 5,
    'sweet potato': 30,

    // Meats (Raw/Cooked)
    'chicken': 1,
    'beef': 3,
    'pork': 3,
    'lamb': 3,
    'bacon': 5,
    'sausage': 2,
    'ham': 3,
    'turkey': 1,
    'meatball': 3,
    'steak': 3,
    'ground beef': 1,
    'ground turkey': 1,

    // Seafood
    'fish': 1,
    'salmon': 1,
    'tuna': 1,
    'shrimp': 1,
    'crab': 1,
    'lobster': 1,
    'scallop': 1,
    'oyster': 1,
    'squid': 1,
    'octopus': 1,

    // Bakery
    'bread': 3,
    'cake': 3,
    'pastry': 2,
    'donut': 2,
    'muffin': 3,
    'bagel': 3,
    'croissant': 2,
    'pie': 3,
    'cookie': 30,
    'biscuit': 30,
    'brownie': 4,
    'bun': 3,

    // Leftovers & Prepared
    'rice': 3,
    'pasta': 3,
    'pizza': 3,
    'burger': 1,
    'sandwich': 2,
    'soup': 3,
    'salad': 2,
    'curry': 3,
    'stew': 3,
    'noodle': 3,
    'sushi': 1,

    // Beverages
    'juice': 7,
    'soda': 30,
    'coffee': 7,
    'tea': 7,
    'smoothie': 2,
    'water': 365,
    'beer': 180,
    'wine': 5,
    'kombucha': 30,
    'energy drink': 180,

    // Condiments & Pantry
    'ketchup': 180,
    'mayonnaise': 90,
    'mustard': 180,
    'soy sauce': 365,
    'hot sauce': 180,
    'jam': 180,
    'jelly': 180,
    'peanut butter': 180,
    'honey': 365,
    'syrup': 365,
    'dressing': 30,
    'salsa': 7,
    'hummus': 5,
    'pesto': 3,

    // Snacks
    'chips': 30,
    'chocolate': 180,
    'popcorn': 7,
    'pretzel': 30,
    'cracker': 30,
    'nut': 90,
    'trail mix': 90,
  };

  /// Estimates the exact expiry Date by scanning product name against the cache
  static DateTime estimateExpiryDate(String productName) {
    if (productName.isEmpty) {
      return DateTime.now().add(const Duration(days: 5));
    }

    final lowerName = productName.toLowerCase();
    
    // Sort keys by length descending to match longest phrases first (e.g. "sweet potato" over "potato")
    final sortedKeys = productExpiryDays.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (var keyword in sortedKeys) {
      if (lowerName.contains(keyword)) {
        return DateTime.now().add(Duration(days: productExpiryDays[keyword]!));
      }
    }

    // Default safety return
    return DateTime.now().add(const Duration(days: 5));
  }
}
