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
                timeout: 8000,  // Increased from 4s to 8s
                headers: { 
                    'User-Agent': `SmridgeApp - Android/iOS - 1.0 - contact@smridge.com`,
                    'Accept': 'application/json'
                }
            });

            const data = response.data;
            // 🛡️ Robust status check: 1 = Found, 0 = Not Found
            if (data.status == 1 && data.product) {
                console.log(`✅ [OFF] Product found on ${sub} server! Name: ${data.product.product_name || 'N/A'}`);
                return data.product;
            } else {
                console.log(`⚠️ [OFF] Status ${data.status} on ${sub}. verbose: ${data.status_verbose || 'N/A'}`);
            }
        } catch (err) {
            if (err.code === 'ECONNABORTED') {
                console.error(`⏱️ [OFF] Timeout on ${sub} subdomain (8s exceeded)`);
            } else {
                console.error(`❌ [OFF] Error on ${sub} server: ${err.message}`);
            }
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
