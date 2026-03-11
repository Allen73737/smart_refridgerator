/// Helper class for automatic product categorization.
class CategoryHelper {
  /// A comprehensive map of product categories to their associated keywords.
  static const Map<String, List<String>> categoryKeywords = {
    "Dairy": [
      "milk", "cheese", "butter", "yogurt", "curd", "paneer", "cream",
      "ghee", "mozzarella", "cheddar", "buttermilk", "custard", "milkshake"
    ],
    "Fruits": [
      "apple", "banana", "orange", "mango", "grape", "pineapple",
      "strawberry", "blueberry", "watermelon", "papaya", "pear", "kiwi", "cherry"
    ],
    "Vegetables": [
      "carrot", "tomato", "potato", "onion", "cabbage", "broccoli",
      "spinach", "lettuce", "cucumber", "pepper", "beetroot", "radish", "garlic"
    ],
    "Meat": [
      "chicken", "beef", "pork", "lamb", "mutton", "turkey",
      "ham", "bacon", "sausages", "salami", "steak", "cutlet"
    ],
    "Seafood": [
      "fish", "salmon", "tuna", "shrimp", "prawn", "crab",
      "lobster", "sardine", "mackerel", "squid", "octopus"
    ],
    "Eggs": [
      "egg", "boiled egg", "omelette", "egg white", "egg yolk",
      "duck egg", "quail egg", "egg curry", "egg salad"
    ],
    "Bakery": [
      "bread", "cake", "pastry", "bun", "croissant", "donut",
      "muffin", "bagel", "brownie", "cupcake", "waffle", "pancake"
    ],
    "Beverages": [
      "juice", "soda", "cola", "water", "smoothie", "milkshake", "coffee",
      "tea", "energy drink", "soft drink", "lemonade", "coconut water"
    ],
    "Frozen Foods": [
      "ice cream", "frozen pizza", "frozen vegetables", "frozen chicken",
      "frozen fish", "frozen fries", "frozen nuggets", "frozen berries", "frozen corn"
    ],
    "Sauces & Condiments": [
      "ketchup", "mayonnaise", "mustard", "soy sauce", "barbecue sauce",
      "tomato sauce", "vinegar", "salad dressing", "hot sauce", "salsa", "teriyaki sauce"
    ],
    "Snacks": [
      "chips", "nachos", "popcorn", "chocolate", "cookies", "biscuits",
      "crackers", "granola", "energy bar", "protein bar", "pretzels"
    ],
    "Cooked Food": [
      "rice", "pasta", "noodles", "curry", "pizza", "burger",
      "sandwich", "fried rice", "biryani", "spaghetti", "soup", "stew"
    ],
    "Packaged Foods": [
      "cereal", "oats", "canned beans", "canned soup", "granola",
      "instant noodles", "ready to eat", "chips", "crisps", "trail mix"
    ],
    "Spreads": [
      "jam", "peanut butter", "chocolate spread", "nutella", "honey",
      "fruit spread", "almond butter", "hazelnut spread"
    ],
    "Others": []
  };

  /// Automatically categorizes a product based on its name using keyword matching.
  /// 
  /// How it works:
  /// 1. Converts the product name to lowercase.
  /// 2. Iterates through the predefined keyword list per category.
  /// 3. Returns the corresponding category String if a contained keyword matches.
  /// 4. Defaults to "Others" if no keyword matches.
  static String autoCategorizeProduct(String productName) {
    if (productName.trim().isEmpty) return "Others";

    String lowerCaseName = productName.toLowerCase();

    for (var entry in categoryKeywords.entries) {
      for (var keyword in entry.value) {
        if (lowerCaseName.contains(keyword.toLowerCase())) {
          return entry.key;
        }
      }
    }

    return "Others";
  }
}
