# Smridge Backend API Documentation

## Base URL
`http://<SERVER_IP>:5000/api`

## Authentication (`/auth`)

### `POST /auth/signup`
Creates a new user.
- **Body**: `{ "name": "User", "email": "test@test.com", "password": "password123" }`
- **Response**: `{ "msg": "User registered" }`

### `POST /auth/login`
Logs in a user and returns a JWT token.
- **Body**: `{ "email": "test@test.com", "password": "password123" }`
- **Response**: `{ "token": "jwt_token_here", "user": { ... } }`

---

## User Profile (`/user`)
*Requires `x-auth-token` header.*

### `GET /user/profile`
Gets the logged-in user's profile.

### `PUT /user/profile`
Updates the user's name or email.
- **Body**: `{ "name": "New Name", "email": "new@test.com" }`

### `PUT /user/change-password`
Updates password.
- **Body**: `{ "oldPassword": "...", "newPassword": "..." }`

### `POST /user/save-fcm-token`
Saves the Firebase device token for push notifications.
- **Body**: `{ "token": "fcm_token_string" }`

---

## Inventory Items (`/items`)
*Requires `x-auth-token` header.*

### `GET /items`
Returns all active inventory items and checks for expiry to send notifications.
- **Response**: `[ { "name": "Milk", "quantity": 1, ... } ]`

### `POST /items` (multipart/form-data)
Adds a new item, optionally with an uploaded image.
- **Form Fields**: `name`, `category`, `packaged`, `quantity`, `weight`, `barcode`, `brand`, `expiryDate`, `expirySource`, `notes`
- **File**: `image`

### `PUT /items/:id`
Updates an item by ID.

### `DELETE /items/:id`
Deletes an item by ID.

---

## Barcode Scanning (`/barcode`)
*Requires `x-auth-token` header.*

### `GET /barcode/:barcodeNumber`
Fetches item details from OpenFoodFacts based on barcode number.
- **Response**: `{ "name": "Brand Milk", "category": "Dairy", "expiryDate": "2024-12-01T...", "imageUrl": "..." }`

---

## Analytics (`/analytics`)
*Requires `x-auth-token` header.*

### `GET /analytics/temperature`
Returns the recent temperature history (last 50 data points from ESP32).

### `GET /analytics/inventory`
Returns aggregated count of items by category.

### `GET /analytics/spoilage`
Returns total number of spoilage alerts and expired items.

---

## Notifications (`/notifications`)
*Requires `x-auth-token` header.*

### `GET /notifications`
Returns a list of alerts and notifications for the user.

### `PUT /notifications/:id/read`
Marks a specific notification as `isRead: true`.

---

## Sensors (`/sensors`)
*Public Endpoint - Used by ESP32.*

### `POST /sensors/data`
Sends sensor readings to the backend. Triggers alerts if thresholds are exceeded.
- **Body**:
```json
{
  "temperature": 5.4,
  "humidity": 72,
  "gasLevel": 310,
  "weight": 450,
  "doorStatus": "closed"
}
```
