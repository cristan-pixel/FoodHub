import 'package:foodhub1/restaurant_card.dart';
import 'package:flutter/material.dart';

class RestaurantGrid extends StatelessWidget {
  final List<Map<String, String>> restaurants;
  final Function(Map<String, String>) onOrderPressed;
  final Set<String> favoriteNames;
  final Function(String) onToggleFavorite;

  /// Restaurant names that are currently not accepting orders.
  final Set<String> pausedNames;

  const RestaurantGrid({
    super.key,
    required this.restaurants,
    required this.onOrderPressed,
    this.favoriteNames = const {},
    required this.onToggleFavorite,
    this.pausedNames = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Popular restaurants",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          restaurants.isEmpty
              ? const Center(child: Text("No restaurants found"))
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    // FIX: card = 110px image + ~120px body = ~230px tall.
                    // At crossAxisCount 2 on a ~390px screen each cell is
                    // roughly (390-40-15)/2 ≈ 167px wide → ratio 167/230 ≈ 0.73
                    childAspectRatio: 0.73,
                  ),
                  itemCount: restaurants.length,
                  itemBuilder: (context, index) {
                    final r = restaurants[index];
                    return RestaurantCard(
                      restaurant: r,
                      onOrderPressed: onOrderPressed,
                      onToggleFavorite: onToggleFavorite,
                      isFavorite: favoriteNames.contains(r['name']),
                      isPaused: pausedNames.contains(r['name']),
                    );
                  },
                ),
        ],
      ),
    );
  }
}