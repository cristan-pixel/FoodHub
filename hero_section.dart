import 'package:flutter/material.dart';
import 'package:foodhub1/menu_items.dart';

class HeroSection extends StatefulWidget {
  final void Function(String query) onSearch;

  const HeroSection({super.key, required this.onSearch});

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _suggestions = [];
  bool _showDropdown = false;

  // All searchable names: every partner in the catalog plus every dish
  // they serve, so typing any restaurant or menu item finds it.
  final List<String> _allSuggestions = {
    ...allRestaurants.map((r) => r['name'] ?? '').where((n) => n.isNotEmpty),
    ...restaurantMenus.values
        .expand((items) => items.map((item) => item['name'] ?? ''))
        .where((name) => name.isNotEmpty),
  }.toList();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() => _showDropdown = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    widget.onSearch(query);
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showDropdown = false;
      });
      return;
    }

    final q = query.toLowerCase();
    final matched = _allSuggestions
        .where((s) => s.toLowerCase().contains(q))
        .toList();

    setState(() {
      _suggestions = matched;
      _showDropdown = matched.isNotEmpty;
    });
  }

  void _onSelect(String value) {
    _controller.text = value;
    widget.onSearch(value);
    setState(() => _showDropdown = false);
    _focusNode.unfocus();
  }

  void _onClear() {
    _controller.clear();
    widget.onSearch('');
    setState(() {
      _suggestions = [];
      _showDropdown = false;
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF7F0),
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(
            child: Text(
              "Your favorite food, delivered",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),

          // Search bar + dropdown wrapped in a Stack
          Stack(
            children: [
              // Search bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: _onChanged,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (v) {
                    widget.onSearch(v);
                    setState(() => _showDropdown = false);
                    _focusNode.unfocus();
                  },
                  decoration: InputDecoration(
                    hintText: "Search restaurants or dishes...",
                    hintStyle: const TextStyle(
                        color: Color(0xFFBDBDBD), fontSize: 14),
                    prefixIcon: const Icon(Icons.search,
                        color: Color(0xFFFF6600)),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.grey, size: 20),
                            onPressed: _onClear,
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Dropdown suggestions
              if (_showDropdown)
                Padding(
                  padding: const EdgeInsets.only(top: 58),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 260),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shrinkWrap: true, 
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) => const Divider(
                          height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (_, i) {
                        final suggestion = _suggestions[i];
                        final query = _controller.text.toLowerCase();
                        final matchIndex =
                            suggestion.toLowerCase().indexOf(query);

                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.search,
                              size: 18, color: Color(0xFFFF6600)),
                          title: matchIndex >= 0
                              ? RichText(
                                  text: TextSpan(
                                    style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87),
                                    children: [
                                      TextSpan(
                                          text: suggestion.substring(
                                              0, matchIndex)),
                                      TextSpan(
                                        text: suggestion.substring(
                                            matchIndex,
                                            matchIndex +
                                                query.length),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFF6600),
                                        ),
                                      ),
                                      TextSpan(
                                          text: suggestion.substring(
                                              matchIndex +
                                                  query.length)),
                                    ],
                                  ),
                                )
                              : Text(suggestion,
                                  style: const TextStyle(fontSize: 14)),
                          onTap: () => _onSelect(suggestion),
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}