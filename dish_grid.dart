import 'package:flutter/material.dart';

/// Shows individual dishes from all restaurants that match a category.
class DishGrid extends StatelessWidget {
  final List<Map<String, dynamic>> dishes;
  final Function(Map<String, dynamic>) onAddToCart;

  const DishGrid({
    super.key,
    required this.dishes,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    if (dishes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Center(
          child: Text("No dishes found in this category",
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${dishes.length} dish${dishes.length == 1 ? '' : 'es'} found",
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.68,
            ),
            itemCount: dishes.length,
            itemBuilder: (context, index) {
              final dish = dishes[index];
              return _DishCard(dish: dish, onAddToCart: onAddToCart);
            },
          ),
        ],
      ),
    );
  }
}

class _DishCard extends StatelessWidget {
  final Map<String, dynamic> dish;
  final Function(Map<String, dynamic>) onAddToCart;

  const _DishCard({required this.dish, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    final imagePath = dish['image'] ?? '';
    final name = dish['name'] ?? '';
    final price = dish['price'] ?? '0';
    final restaurantName = dish['restaurant_name'] ?? '';
    final desc = dish['desc'] ?? '';

    return GestureDetector(
      onTap: () => onAddToCart(dish),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(imagePath, fit: BoxFit.cover),
                    // Restaurant badge
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          restaurantName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style:
                          const TextStyle(fontSize: 10, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "\u20B1$price",
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF6600),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => onAddToCart(dish),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF6600),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
