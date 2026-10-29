import 'package:flutter/material.dart';
import 'package:foodhub1/menu_items.dart';
import 'package:foodhub1/widgets/restaurant_menu_sheet.dart';

class RestaurantCard extends StatelessWidget {
  final Map<String, String> restaurant;
  final Function(Map<String, String>) onOrderPressed;
  final Function(String) onToggleFavorite;
  final bool isFavorite;

  /// True when the partner has paused incoming orders — the card shows a
  /// paused badge and ordering is disabled.
  final bool isPaused;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onOrderPressed,
    required this.onToggleFavorite,
    required this.isFavorite,
    this.isPaused = false,
  });

  // FIX: helper to get first menu image for the restaurant
  String _getMenuImage() {
    final List items = restaurantMenus[restaurant['name']] ?? [];
    if (items.isNotEmpty) {
      return items.first['image'] ?? '';
    }
    return '';
  }

  void _showMenu(BuildContext context) {
    openRestaurantMenu(context, restaurant, onOrderPressed);
  }

  @override
  Widget build(BuildContext context) {
    final String restaurantName = restaurant['name'] ?? '';
    final String imageUrl = _getMenuImage();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // FIX: Use Column with a fixed-height image instead of AspectRatio
      // so the card never overflows its grid cell
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner image — fixed 110px height ────────────────
          SizedBox(
            height: 110,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  imageUrl.isNotEmpty
                      ? Image.asset(
                          imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade100,
                            child: Icon(
                              Icons.fastfood_rounded,
                              color: Colors.orange.withValues(alpha: 0.5),
                              size: 40,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade100,
                          child: Icon(
                            Icons.fastfood_rounded,
                            color: Colors.orange.withValues(alpha: 0.5),
                            size: 40,
                          ),
                        ),

                  // Gradient overlay
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 🚫 Paused badge — bottom left of the banner
                  if (isPaused)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "PAUSED",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),

                  // Rating badge — top right
                  Positioned(
                    top: 8,
                    right: 8,
                    child: ratingBadge(restaurant['rating'] ?? '0.0'),
                  ),

                  // ❤ Favorite button — top left
                  Positioned(
                    top: 8,
                    left: 8,
                    child: GestureDetector(
                      onTap: () => onToggleFavorite(restaurantName),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isFavorite
                              ? const Color(0xFFFF6600)
                              : Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFavorite ? Colors.white : Colors.grey,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Card body — Expanded so it fills remaining cell space ─
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Restaurant name
                  Text(
                    restaurantName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Tags
                  Text(
                    restaurant['tags'] ?? '',
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Prep time
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 12, color: Colors.grey.shade500),
                      const SizedBox(width: 3),
                      Text(
                        "${restaurant['prep']} mins",
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Menu button — opens the restaurant menu; ordering only
                  // happens per menu item inside.
                  SizedBox(
                    width: double.infinity,
                    height: 32,
                    child: OutlinedButton(
                      onPressed: isPaused ? null : () => _showMenu(context),
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.disabled)
                              ? Colors.grey.shade400
                              : const Color(0xFFFF6600),
                        ),
                        side: WidgetStateProperty.resolveWith(
                          (states) => BorderSide(
                            color: states.contains(WidgetState.disabled)
                                ? Colors.grey.shade300
                                : const Color(0xFFFF6600),
                            width: 1.0,
                          ),
                        ),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                      ),
                      child: Text(isPaused ? "Paused" : "Menu",
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}