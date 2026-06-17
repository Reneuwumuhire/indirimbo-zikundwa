import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/book_groups.dart';
import '../../data/models.dart';
import '../../state/settings.dart';
import '../../theme/app_theme.dart';

/// A single-row representation of a collection for the "list" library layout:
/// a slim book-spine swatch, the name, a monospace meta line, and a chevron.
class CollectionListTile extends ConsumerWidget {
  final Collection collection;
  final int index;
  final VoidCallback onTap;
  const CollectionListTile({
    super.key,
    required this.collection,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final theme = Theme.of(context);
    final reader = theme.extension<ReaderPalette>()!;
    final color = AppTheme.bookColorFor(index);
    final code = bookGroupOf(collection.id).code;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
        child: Row(
          children: [
            // mini book spine
            Container(
              width: 38,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
                border: Border(left: BorderSide(color: AppTheme.spineOf(color), width: 5)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$code · ${t.songs(collection.songCount).toUpperCase()}',
                    style: TextStyle(
                        fontFamily: AppFonts.mono, fontSize: 10.5, letterSpacing: 0.4, color: reader.muted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: reader.muted, size: 20),
          ],
        ),
      ),
    );
  }
}
