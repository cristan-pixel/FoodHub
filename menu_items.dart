// lib/data/menu_items.dart

// Restaurant-specific menus, keyed by exact restaurant name.
const Map<String, List<Map<String, String>>> restaurantMenus = {
  "JB LutongBahay Resto": _jbMenu,
  "Bibiana FoodHouse": _bibianaMenu,
  "Mamos Tasty Ramen": _mamosMenu,
  "Pareng Eling": _parengMenu,
  "Pastilan": _pastilanMenu,
};

// Home-page restaurant catalog (display metadata: tags, rating,
// category, delivery price, prep time). Shared by the HomePage and the
// Firestore seeder so the online catalog always matches the app bundle.
const List<Map<String, String>> allRestaurants = [
  {
    "name": "JB LutongBahay Resto",
    "tags": "Filipino, Lutong Bahay",
    "rating": "4.8",
    "category": "Filipino",
    "price": "120.00",
    "prep": "25",
  },
  {
    "name": "Bibiana FoodHouse",
    "tags": "Filipino, Combo Meals",
    "rating": "4.6",
    "category": "Filipino",
    "price": "150.00",
    "prep": "20",
  },
  {
    "name": "Mamos Tasty Ramen",
    "tags": "Japanese, Ramen, Noodles",
    "rating": "4.7",
    "category": "Japanese",
    "price": "25.00",
    "prep": "15",
  },
  {
    "name": "Pareng Eling",
    "tags": "Filipino, Street Food, Snacks",
    "rating": "4.5",
    "category": "Filipino",
    "price": "40.00",
    "prep": "10",
  },
  {
    "name": "Pastilan",
    "tags": "Filipino, Pastil, Rice Meal",
    "rating": "4.6",
    "category": "Filipino",
    "price": "50.00",
    "prep": "12",
  },
];

// ── JB LutongBahay Resto ──────────────────────────────────────────────
const List<Map<String, String>> _jbMenu = [
  {"name": "Humba", "desc": "Braised pork belly in soy sauce, vinegar, and spices", "price": "30.00", "image": "assets/JB_LutongBahay_Resto_Images/humba.jpg", "category": "Pork"},
  {"name": "Adobo", "desc": "Classic Filipino pork adobo in vinegar and soy sauce", "price": "30.00", "image": "assets/JB_LutongBahay_Resto_Images/adobo.jpg", "category": "Pork"},
  {"name": "Adobong Atay", "desc": "Sautéed liver in adobo-style sauce", "price": "30.00", "image": "assets/JB_LutongBahay_Resto_Images/adobong_atay.jpg", "category": "Pork"},
  {"name": "Nilagang Baboy", "desc": "Boiled pork soup with vegetables and peppercorns", "price": "30.00", "image": "assets/JB_LutongBahay_Resto_Images/nilagang_baboy.jpg", "category": "Soup"},
  {"name": "Bihon", "desc": "Stir-fried rice noodles with vegetables and meat", "price": "20.00", "image": "assets/JB_LutongBahay_Resto_Images/bihon.jpg", "category": "Ramen/Noodles"},
  {"name": "Ginagmay", "desc": "Sliced meat sautéed with vegetables and spices", "price": "40.00", "image": "assets/JB_LutongBahay_Resto_Images/ginagmay.jpg", "category": "Pork"},
  {"name": "Tinolang Barilis", "desc": "Hearty tinola soup with green papaya and chili leaves", "price": "50.00", "image": "assets/JB_LutongBahay_Resto_Images/Tinolang_Barilis.jpg", "category": "Soup"},
  {"name": "Bicol Express", "desc": "Spicy pork in coconut milk with chili", "price": "40.00", "image": "assets/JB_LutongBahay_Resto_Images/bicol.jpg", "category": "Pork"},
  {"name": "Otan", "desc": "Fresh vegetable dish with local spices", "price": "20.00", "image": "assets/JB_LutongBahay_Resto_Images/otan.jpg", "category": "Veggies"},
  {"name": "Itlog (Egg)", "desc": "Fried egg, a perfect side to any meal", "price": "15.00", "image": "assets/JB_LutongBahay_Resto_Images/egg.jpg", "category": "Snacks"},
];

// ── Bibiana FoodHouse ─────────────────────────────────────────────────
const List<Map<String, String>> _bibianaMenu = [
  {"name": "Chicken Combo", "desc": "Juicy fried chicken served with rice", "price": "59.00", "image": "assets/Bibian_FoodHouse_Images/Chicken_Combo.jpg", "category": "Chicken"},
  {"name": "Grilled Bangus Combo", "desc": "Grilled milkfish with rice and dipping sauce", "price": "79.00", "image": "assets/Bibian_FoodHouse_Images/Grilled_Bangus_Combo.jpg", "category": "Seafood"},
  {"name": "Grilled Pusit Combo", "desc": "Grilled squid stuffed with tomato and onion", "price": "79.00", "image": "assets/Bibian_FoodHouse_Images/Grilled_Pusit_Combo.jpg", "category": "Seafood"},
  {"name": "Grilled Tuna Combo", "desc": "Grilled tuna belly with rice", "price": "79.00", "image": "assets/Bibian_FoodHouse_Images/Grilled_Tuna_Combo.jpg", "category": "Seafood"},
  {"name": "Lechon Kawali Combo", "desc": "Crispy deep-fried pork belly with rice", "price": "59.00", "image": "assets/Bibian_FoodHouse_Images/Lechon_Kawali_Combo.jpg", "category": "Pork"},
  {"name": "Pater", "desc": "Steamed rice topped with pork and spices", "price": "10.00", "image": "assets/Bibian_FoodHouse_Images/Pater.jpg", "category": "Pater/Pastil"},
];

// ── Mamos Tasty Ramen ───────────────────────────────────────────
const List<Map<String, String>> _mamosMenu = [
  {"name": "Japanese Ramen (25)", "desc": "Classic Japanese ramen with rich broth, topped with chashu and egg", "price": "25.00", "image": "assets/Mamos_TastyRamen_Images/japanese_ramen25.jpg", "category": "Ramen/Noodles"},
  {"name": "Japanese Ramen (35)", "desc": "Classic Japanese ramen with rich broth, topped with chashu and egg", "price": "35.00", "image": "assets/Mamos_TastyRamen_Images/japanese_ramen35.jpg", "category": "Ramen/Noodles"},
  {"name": "Japanese Ramen (40)", "desc": "Classic Japanese ramen with rich broth, topped with chashu and egg", "price": "40.00", "image": "assets/Mamos_TastyRamen_Images/japanese_ramen40.jpg", "category": "Ramen/Noodles"},
  {"name": "Seafood Ramen (25)", "desc": "Savory ramen loaded with shrimp, squid, and fish cake in seafood broth", "price": "25.00", "image": "assets/Mamos_TastyRamen_Images/seafood_ramen25.jpg", "category": "Ramen/Noodles"},
  {"name": "Seafood Ramen (35)", "desc": "Savory ramen loaded with shrimp, squid, and fish cake in seafood broth", "price": "35.00", "image": "assets/Mamos_TastyRamen_Images/seafood_ramen35.jpg", "category": "Ramen/Noodles"},
  {"name": "Seafood Ramen (40)", "desc": "Savory ramen loaded with shrimp, squid, and fish cake in seafood broth", "price": "40.00", "image": "assets/Mamos_TastyRamen_Images/seafood_ramen40.jpg", "category": "Ramen/Noodles"},
  {"name": "Spicy Beef Ramen (25)", "desc": "Fiery beef ramen with tender slices in a spicy chili broth", "price": "25.00", "image": "assets/Mamos_TastyRamen_Images/spicy_beef25.jpg", "category": "Ramen/Noodles"},
  {"name": "Spicy Beef Ramen (35)", "desc": "Fiery beef ramen with tender slices in a spicy chili broth", "price": "35.00", "image": "assets/Mamos_TastyRamen_Images/spicy_beef35.jpg", "category": "Ramen/Noodles"},
  {"name": "Spicy Beef Ramen (40)", "desc": "Fiery beef ramen with tender slices in a spicy chili broth", "price": "40.00", "image": "assets/Mamos_TastyRamen_Images/spicy_beef40.jpg", "category": "Ramen/Noodles"},
];

// ── Pareng Eling ──────────────────────────────────────────────
const List<Map<String, String>> _parengMenu = [
  {"name": "Chili Cheese Nachos", "desc": "Crispy nachos loaded with melted cheese and spicy chili", "price": "85.00", "image": "assets/Pareng_Elings_images/Chili_Cheese_Nachos.jpg", "category": "Snacks"},
  {"name": "Cheese Lompia", "desc": "Crispy fried spring rolls filled with melted cheese", "price": "60.00", "image": "assets/Pareng_Elings_images/cheese_lompia.jpg", "category": "Snacks"},
  {"name": "Calamares", "desc": "Golden-fried squid rings served with tangy dipping sauce", "price": "95.00", "image": "assets/Pareng_Elings_images/Calamares.jpg", "category": "Snacks"},
  {"name": "Fish Balls & Squid Balls", "desc": "Classic street food fish and squid balls with sweet and spicy sauce", "price": "40.00", "image": "assets/Pareng_Elings_images/FishBalls_SquidBalls.jpg", "category": "Snacks"},
  {"name": "Siomai", "desc": "Steamed pork dumplings with soy-calamansi dip", "price": "55.00", "image": "assets/Pareng_Elings_images/SIOMAI.jpg", "category": "Snacks"},
  {"name": "Garlic", "desc": "Crispy garlic chips, a savory topping or snack", "price": "30.00", "image": "assets/Pareng_Elings_images/Garlic_price.jpg", "category": "Snacks"},
  {"name": "Calamansi Juice", "desc": "Refreshing freshly squeezed calamansi drink", "price": "25.00", "image": "assets/Pareng_Elings_images/Calamansi.jpg", "category": "Drinks"},
  {"name": "Buko Pandan", "desc": "Chilled coconut strips in sweet pandan-flavored cream", "price": "35.00", "image": "assets/Pareng_Elings_images/Buko_pandan.jpg", "category": "Drinks"},
  {"name": "Iced Tea", "desc": "Cool and refreshing iced tea to complement your meal", "price": "20.00", "image": "assets/Pareng_Elings_images/Iced_tea.jpg", "category": "Drinks"},
  {"name": "Melon Juice", "desc": "Sweet and chilled fresh melon juice", "price": "30.00", "image": "assets/Pareng_Elings_images/Melon.jpg", "category": "Drinks"},
];

// ── Pastilan ─────────────────────────────────────────────────
const List<Map<String, String>> _pastilanMenu = [
  {"name": "Normal Chicken Pastil", "desc": "Savory shredded chicken pastil served over rice", "price": "50.00", "image": "assets/Pastil_an_images/normal_chicken.jpg", "category": "Pater/Pastil"},
  {"name": "Normal Beef Pastil", "desc": "Tender shredded beef pastil served over rice", "price": "55.00", "image": "assets/Pastil_an_images/normal_beef.jpg", "category": "Pater/Pastil"},
  {"name": "Extra Hot Chicken Pastil", "desc": "Spicy shredded chicken pastil with extra chili kick", "price": "55.00", "image": "assets/Pastil_an_images/extrahot_chicken.jpg", "category": "Pater/Pastil"},
  {"name": "Extra Hot Beef Pastil", "desc": "Spicy shredded beef pastil with extra chili kick", "price": "60.00", "image": "assets/Pastil_an_images/extrahot_beef.jpg", "category": "Pater/Pastil"},
  {"name": "Pineapple Juice", "desc": "Fresh and sweet pineapple juice", "price": "30.00", "image": "assets/Pastil_an_images/Pineapple_Juice.jpg", "category": "Drinks"},
  {"name": "Mango Shake", "desc": "Creamy and refreshing mango shake", "price": "40.00", "image": "assets/Pastil_an_images/Mango_Shake.jpg", "category": "Drinks"},
  {"name": "Iced Tea", "desc": "Cool and refreshing iced tea", "price": "20.00", "image": "assets/Pastil_an_images/IcedTea.jpg", "category": "Drinks"},
  {"name": "Calamansi Juice", "desc": "Freshly squeezed calamansi drink", "price": "25.00", "image": "assets/Pastil_an_images/calamansi Juice.jpg", "category": "Drinks"},
];

// ── Backwards-compatible flat category map for search etc. ────────────
const Map<String, List<Map<String, String>>> categoryMenuItems = {
  "All": _allItems,
  "JB LutongBahay Resto": _jbMenu,
  "Bibiana FoodHouse": _bibianaMenu,
  "Mamos Tasty Ramen": _mamosMenu,
  "Pareng Eling": _parengMenu,
  "Pastilan": _pastilanMenu,
};

const List<Map<String, String>> _allItems = [
  ..._jbMenu,
  ..._bibianaMenu,
  ..._mamosMenu,
  ..._parengMenu,
  ..._pastilanMenu,
];
