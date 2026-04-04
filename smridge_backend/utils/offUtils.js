const axios = require("axios");

/**
 * 🧊 OpenFoodFacts High-Resilience Fetcher
 * Rotates subdomains and standardizes status parsing
 */
exports.fetchProductByBarcode = async (barcode) => {
    const subdomains = ['world', 'in', 'us'];
    const cleanCode = String(barcode).trim();
    
    for (const sub of subdomains) {
        try {
            const url = `https://${sub}.openfoodfacts.org/api/v2/product/${cleanCode}.json`;
            console.log(`📡 [OFF] Attempting ${sub} subdomain: ${url}`);
            
            const response = await axios.get(url, {
                timeout: 4000,
                headers: { 
                    'User-Agent': `SmridgeApp - Android/iOS - 1.0 - contact@smridge.com`,
                    'Accept': 'application/json'
                }
            });

            const data = response.data;
            // 🛡️ Robust status check: 1 = Found, 0 = Not Found
            if (data.status == 1 && data.product) {
                console.log(`✅ [OFF] Product found on ${sub} server!`);
                return data.product;
            } else {
                console.log(`⚠️ [OFF] Product not found on ${sub} server (Status: ${data.status})`);
            }
        } catch (err) {
            console.error(`❌ [OFF] Error on ${sub} server:`, err.message);
        }
    }
    
    return null; // All attempts failed
};

/**
 * 🧊 Search OpenFoodFacts by Name (Fallback for AI)
 */
exports.searchProductByName = async (query) => {
    try {
        const url = `https://world.openfoodfacts.org/cgi/search.pl?search_terms=${encodeURIComponent(query)}&search_simple=1&action=process&json=1&page_size=1`;
        const resp = await axios.get(url, { 
            timeout: 5000,
            headers: { 'User-Agent': 'SmridgeApp - 1.0' }
        });
        if (resp.data.products && resp.data.products.length > 0) {
            return resp.data.products[0];
        }
    } catch (e) {
        console.error("OFF search error:", e.message);
    }
    return null;
};
