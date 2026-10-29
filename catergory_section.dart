import 'package:flutter/material.dart';

class CategorySection extends StatelessWidget {
  final String selectedCategory;
  final Function(String) onCategorySelected;

  const CategorySection({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  static const List<Map<String, dynamic>> categories = [
    {"name": "All",           "icon": Icons.grid_view},
    {"name": "Pork",          "icon": Icons.lunch_dining},
    {"name": "Chicken",       "icon": Icons.emoji_food_beverage},
    {"name": "Seafood",       "icon": Icons.set_meal},
    {"name": "Ramen/Noodles", "icon": Icons.ramen_dining},
    {"name": "Soup",          "icon": Icons.soup_kitchen},
    {"name": "Snacks",        "icon": Icons.fastfood},
    {"name": "Pater/Pastil",  "icon": Icons.rice_bowl},
    {"name": "Drinks",        "icon": Icons.local_cafe},
    {"name": "Veggies",       "icon": Icons.eco},
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            "Browse by category",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final isSelected = selectedCategory == cat['name'];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GestureDetector(
                  onTap: () => onCategorySelected(cat['name'] as String),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFF6600)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Icon(
                          cat['icon'] as IconData,
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFFFF6600),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        cat['name'] as String,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}