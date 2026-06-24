import 'package:flutter/material.dart';

import 'package:indirimbo/src/data/book_groups.dart';
import 'package:indirimbo/src/data/models.dart';
import 'package:indirimbo/src/core/app_theme.dart';

/// A solid single-colour "book cover" for a hymn collection — a deep library
/// spine colour with a darker spine edge, an embossed rule, the collection name
/// in a display serif, and a small monospace `CODE · count` line.
class CollectionCover extends StatelessWidget {
  final Collection collection;
  final int index;
  final VoidCallback? onTap;
  final bool compact;

  const CollectionCover({
    super.key,
    required this.collection,
    required this.index,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.bookColorFor(index);
    final spine = AppTheme.spineOf(color);
    final code = bookGroupOf(collection.id).code;

    final book = DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 10,
            offset: const Offset(2, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LayoutBuilder(
          builder: (context, c) {
            final spineW = c.maxWidth * 0.12;
            final pad = compact ? 11.0 : 15.0;
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: color),
                // Spine + its highlight seam.
                Positioned(left: 0, top: 0, bottom: 0, width: spineW, child: ColoredBox(color: spine)),
                Positioned(
                  left: spineW,
                  top: 0,
                  bottom: 0,
                  width: 1.5,
                  child: ColoredBox(color: Colors.white.withValues(alpha: 0.08)),
                ),
                // Soft sheen + bottom shading for depth.
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0x14FFFFFF), Color(0x00000000), Color(0x1A000000)],
                        stops: [0, 0.5, 1],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(spineW + pad, pad, pad, pad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: 26, height: 2, color: Colors.white.withValues(alpha: 0.34)),
                      const Spacer(),
                      Text(
                        collection.name,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontWeight: FontWeight.w700,
                          height: 1.12,
                          fontSize: compact ? 15 : 16.5,
                          color: const Color(0xFFF3ECDD),
                        ),
                      ),
                      SizedBox(height: compact ? 5 : 7),
                      Text(
                        '$code · ${collection.songCount} SONGS',
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          fontSize: compact ? 9 : 10,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    if (onTap == null) return book;
    return GestureDetector(onTap: onTap, child: book);
  }
}
