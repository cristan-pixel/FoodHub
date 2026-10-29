// lib/widgets/restaurant_menu_sheet.dart
//
// Reusable bottom-sheet menu for one restaurant. Used both by the
// restaurant grid card and the Favorites tab, so ordering always happens
// per menu item — a whole restaurant "profile" is never added to the cart.

import 'package:flutter/material.dart';
import 'package:foodhub1/menu_items.dart';

/// Opens the menu sheet for [restaurant]. Tapping "Add" on a menu item
/// closes the sheet and fires [onItemPressed] with the item (including
/// its `restaurant_name`) so the caller can add it to the cart.
void openRestaurantMenu(
  BuildContext context,
  Map<String, String> restaurant,
  void Function(Map<String, String>) onItemPressed,
) {
  final List items = restaurantMenus[restaurant['name']] ?? [];

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          restaurant['name'] ?? 'Restaurant',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          restaurant['tags'] ?? '',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ratingBadge(restaurant['rating'] ?? '0.0'),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text("No menu available."))
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 24),
                      itemBuilder: (context, index) => _menuItemRow(
                        context,
                        items[index],
                        restaurant,
                        onItemPressed,
                      ),
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _menuItemRow(
  BuildContext context,
  Map item,
  Map<String, String> restaurant,
  void Function(Map<String, String>) onItemPressed,
) {
  final String imagePath = item['image'] ?? '';
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: imagePath.isNotEmpty
            ? Image.asset(
                imagePath,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _itemImageFallback(),
              )
            : _itemImageFallback(),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['name'] ?? 'Item',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              item['desc'] ?? '',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              "\u20B1${item['price']}",
              style: const TextStyle(
                color: Color(0xFFFF6600),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Align(
        alignment: Alignment.center,
        child: SizedBox(
          height: 36,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // close the menu sheet
              onItemPressed({
                ...Map<String, String>.from(item),
                'restaurant_name': restaurant['name']!,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6600),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text("Add", style: TextStyle(fontSize: 13)),
          ),
        ),
      ),
    ],
  );
}

Widget _itemImageFallback() => Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.restaurant_menu_rounded,
          color: Colors.orange, size: 28),
    );

Widget ratingBadge(String rating) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF3E0),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, color: Colors.orange, size: 16),
        const SizedBox(width: 2),
        Text(
          rating,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.orange,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}