const axios = require("axios");

// Liquid keywords for detection
const LIQUID_KEYWORDS = [
    'milk', 'juice', 'water', 'soda', 'cola', 'yogurt', 'yoghurt',
    'drink', 'sauce', 'oil', 'vinegar', 'cream', 'syrup', 'soup',
    'broth', 'smoothie', 'shake', 'tea', 'coffee', 'lemonade',
    'curd', 'buttermilk', 'lassi', 'beer', 'wine', 'beverage',
];

const LIQUID_CATEGORIES = ['beverages', 'dairy', 'condiments'];

function isLiquidItem(productName, category) {
    const nameLower = (productName || '').toLowerCase();
    const catLower = (category || '').toLowerCase();
    if (LIQUID_CATEGORIES.some(lc => catLower.includes(lc))) return true;
    return LIQUID_KEYWORDS.some(kw => nameLower.includes(kw));
}

function parseQuantityString(quantityStr) {
    // Parse OpenFoodFacts quantity string like "500 ml", "1.5 l", "250 g", "1 kg"
    if (!quantityStr) return { weight: null, litres: null };

    const str = quantityStr.toLowerCase().trim();

    // Try to find volume (ml, l, cl)
    let litres = null;
    const mlMatch = str.match(/([\d.]+)\s*ml/);
    const lMatch = str.match(/([\d.]+)\s*l(?:itre|iter)?s?/);
    const clMatch = str.match(/([\d.]+)\s*cl/);

    if (mlMatch) litres = parseFloat(mlMatch[1]) / 1000;
    else if (clMatch) litres = parseFloat(clMatch[1]) / 100;
    else if (lMatch) litres = parseFloat(lMatch[1]);

    // Try to find weight (g, kg)
    let weight = null;
    const gMatch = str.match(/([\d.]+)\s*g(?:ram)?s?(?!\s*l)/);
    const kgMatch = str.match(/([\d.]+)\s*kg/);

    if (kgMatch) weight = parseFloat(kgMatch[1]);
    else if (gMatch) weight = parseFloat(gMatch[1]) / 1000; // Convert g to kg

    // If neither matched, try plain number
    if (!weight && !litres) {
        const plain = parseFloat(str);
        if (!isNaN(plain)) weight = plain > 100 ? plain / 1000 : plain;
    }

    return { weight, litres };
}

// 🟢 Scan Barcode (OpenFoodFacts API)
exports.scanBarcode = async (req, res) => {
    try {
        const { barcodeNumber } = req.params;
        if (!barcodeNumber) return res.status(400).json({ message: "Barcode is required" });

        const response = await axios.get(`https://world.openfoodfacts.org/api/v0/product/${barcodeNumber}.json`, {
            headers: { 'User-Agent': 'SmridgeApp - Android - Version 1.0' }
        });

        if (response.data.status !== 1) {
            return res.status(404).json({ message: "Product not found. Please enter details manually." });
        }

        const product = response.data.product;

        // Extract required fields
        const product_name = product.product_name || '';
        const brands = product.brands || '';
        const quantityStr = product.quantity || '';
        const categories = product.categories ? product.categories.split(',')[0].trim() : 'Unknown';
        const image_url = product.image_url || '';
        const ingredients_text = product.ingredients_text || '';

        // Parse weight and volume from quantity string
        const { weight, litres } = parseQuantityString(quantityStr);

        // Detect if liquid
        const liquid = isLiquidItem(product_name, categories);

        // Estimate expiry
        let expiryDays = 7; // default
        const catLower = categories.toLowerCase();
        if (catLower.includes('milk')) expiryDays = 5;
        else if (catLower.includes('yogurt') || catLower.includes('yoghurt')) expiryDays = 7;
        else if (catLower.includes('cheese')) expiryDays = 14;
        else if (catLower.includes('bread')) expiryDays = 4;
        else if (catLower.includes('sauce')) expiryDays = 30;
        else if (catLower.includes('chocolate')) expiryDays = 180;

        const estimatedExpiry = new Date();
        estimatedExpiry.setDate(estimatedExpiry.getDate() + expiryDays);

        return res.json({
            name: product_name,
            brand: brands,
            category: categories,
            quantity: 1,
            weight: weight,       // Already in kg
            litres: litres,       // Already in litres
            isLiquid: liquid,
            imageUrl: image_url,
            expiryDate: estimatedExpiry,
            expirySource: 'estimated',
            ingredients: ingredients_text,
            barcode: barcodeNumber
        });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
};
