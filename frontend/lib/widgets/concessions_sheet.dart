import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SnackItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String iconEmoji;
  final String badge;
  int quantity;

  SnackItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.iconEmoji,
    required this.badge,
    this.quantity = 0,
  });
}

class ConcessionsSheet extends StatefulWidget {
  final double seatTotal;
  final int ticketCount;
  final String currencySymbol;
  final ValueChanged<List<SnackItem>> onProceed;
  final VoidCallback onSkip;

  const ConcessionsSheet({
    super.key,
    required this.seatTotal,
    required this.ticketCount,
    required this.currencySymbol,
    required this.onProceed,
    required this.onSkip,
  });

  @override
  State<ConcessionsSheet> createState() => _ConcessionsSheetState();
}

class _ConcessionsSheetState extends State<ConcessionsSheet> {
  late final List<SnackItem> _snacks;

  @override
  void initState() {
    super.initState();
    final isINR = widget.currencySymbol == '₹';
    _snacks = [
      SnackItem(
        id: 'caramel_popcorn',
        name: 'Jumbo Caramel Popcorn',
        description: 'Warm, golden kettle-popped corn coated in rich sweet caramel',
        price: isINR ? 290 : 5.50,
        iconEmoji: '🍿',
        badge: 'BESTSELLER',
      ),
      SnackItem(
        id: 'cheese_nachos',
        name: 'Crispy Cheese Nachos',
        description: 'Crisp corn tortilla chips served with warm melted cheese dip & salsa',
        price: isINR ? 240 : 4.50,
        iconEmoji: '🧀',
        badge: 'POPULAR',
      ),
      SnackItem(
        id: 'fountain_soda',
        name: 'Ice-Cold Beverage (650ml)',
        description: 'Fountain dispenser: Chilled Pepsi, Mountain Dew, 7UP or Mirinda',
        price: isINR ? 150 : 3.00,
        iconEmoji: '🥤',
        badge: 'REFRESH',
      ),
      SnackItem(
        id: 'cinephile_combo',
        name: 'Grand Cineza Duo Combo',
        description: '1 Large Popcorn + 2 Beverages + 1 Mexican Nachos (Save 20%)',
        price: isINR ? 580 : 11.00,
        iconEmoji: '🎬',
        badge: 'SAVER 20%',
      ),
      SnackItem(
        id: 'choco_lava',
        name: 'Molten Choco Lava Cake',
        description: 'Decadent chocolate cake with molten fudge center served warm',
        price: isINR ? 190 : 3.50,
        iconEmoji: '🍫',
        badge: 'SWEET',
      ),
    ];
  }

  double get _snacksTotal {
    double sum = 0;
    for (final s in _snacks) {
      sum += s.price * s.quantity;
    }
    return sum;
  }

  int get _snacksCount {
    int c = 0;
    for (final s in _snacks) {
      c += s.quantity;
    }
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final grandTotal = widget.seatTotal + _snacksTotal;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
        maxWidth: 620,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.goldAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('🍿', style: TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Movie Snacks & Drinks',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          'Delivered directly to your seat before showtime',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                TextButton(
                  onPressed: widget.onSkip,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Snacks List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              itemCount: _snacks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final snack = _snacks[index];
                final isSelected = snack.quantity > 0;

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? (isSelected
                            ? AppTheme.primary.withValues(alpha: 0.1)
                            : const Color(0xFF1E293B))
                        : (isSelected
                            ? const Color(0xFFEFF6FF)
                            : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primary
                          : (isDark ? Colors.white10 : Colors.black12),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Emoji Icon
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black26
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            snack.iconEmoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Title & Description
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  snack.name,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: snack.badge.contains('20%')
                                        ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                        : AppTheme.goldAccent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    snack.badge,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: snack.badge.contains('20%')
                                          ? const Color(0xFF10B981)
                                          : AppTheme.goldAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              snack.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : Colors.black45,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.currencySymbol}${snack.price.toInt()}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Quantity Stepper
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (snack.quantity > 0) ...[
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded),
                              color: isDark ? Colors.white70 : Colors.black54,
                              iconSize: 22,
                              onPressed: () {
                                setState(() => snack.quantity--);
                              },
                            ),
                            Text(
                              '${snack.quantity}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                          IconButton(
                            icon: const Icon(Icons.add_circle_rounded),
                            color: AppTheme.primary,
                            iconSize: 24,
                            onPressed: () {
                              setState(() => snack.quantity++);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // Bottom Action Tray
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B1329) : const Color(0xFFF1F5F9),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.ticketCount} Tickets' +
                          (_snacksCount > 0 ? ' + $_snacksCount Snacks' : ''),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${widget.currencySymbol}${grandTotal.toInt()}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primary,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  onPressed: () {
                    final picked =
                        _snacks.where((s) => s.quantity > 0).toList();
                    widget.onProceed(picked);
                  },
                  child: Text(
                    _snacksCount > 0
                        ? 'Proceed with Snacks →'
                        : 'Continue without Snacks →',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
