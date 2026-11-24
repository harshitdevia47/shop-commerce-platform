import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/l10n.dart';
import '../../domain/order_models.dart';

/// "12:00 PM – 4:00 PM" in the app language.
String formatWindow(TimeWindow window, Locale locale) {
  final time = DateFormat.jm(locale.languageCode);
  return '${time.format(window.start)} – ${time.format(window.end)}';
}

/// "Today" / "Tomorrow" / "Thu, 26 Nov".
String formatDay(BuildContext context, DateTime day, DateTime now) {
  final l10n = context.l10n;
  final date = DateUtils.dateOnly(day);
  final today = DateUtils.dateOnly(now);
  if (date == today) return l10n.today;
  if (date == today.add(const Duration(days: 1))) return l10n.tomorrow;
  return DateFormat.MMMEd(Localizations.localeOf(context).languageCode).format(day);
}

/// Delivery windows grouped by day; full windows are shown but cannot be picked.
class SlotPicker extends StatelessWidget {
  const SlotPicker({required this.slots, required this.selected, required this.onSelected, this.now, super.key});

  final List<DeliverySlot> slots;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final byDay = <DateTime, List<DeliverySlot>>{};
    for (final slot in slots) {
      byDay.putIfAbsent(DateUtils.dateOnly(slot.start), () => []).add(slot);
    }
    if (slots.isEmpty) return Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noSlots));
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          for (final MapEntry(key: day, value: daySlots) in byDay.entries) ...[
            Text(formatDay(context, day, now ?? DateTime.now()), style: Theme.of(context).textTheme.labelLarge),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in daySlots)
                  ChoiceChip(
                    key: ValueKey('slot-${slot.start.toUtc().toIso8601String()}'),
                    label: Text(slot.available ? formatWindow(slot, locale) : '${formatWindow(slot, locale)} · ${l10n.slotFull}'),
                    selected: selected == slot.start,
                    onSelected: slot.available ? (_) => onSelected(slot.start) : null,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
