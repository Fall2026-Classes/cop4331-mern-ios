import 'package:flutter/material.dart';

const kBg = Color(0xFF14181C);
const kSurface = Color(0xFF1C232B);
const kSurface2 = Color(0xFF242D36);
const kBorder = Color(0xFF33404C);
const kText = Color(0xFFE6EBF0);
const kMuted = Color(0xFF8A99A8);
const kAccent = Color(0xFF00C46A);
const kStar = Color(0xFFFFB21E);
const kStarEmpty = Color(0xFF3A4652);
const kDanger = Color(0xFFFF5C5C);
const kMovie = Color(0xFF3D8BFD);
const kShow = Color(0xFFC069FF);

/// "Reel" + green "Talk".
class Brand extends StatelessWidget {
  const Brand({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        const TextSpan(text: 'Reel'),
        TextSpan(text: 'Talk', style: TextStyle(color: kAccent, fontSize: size)),
      ]),
      style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: kText),
    );
  }
}

/// 0-5 stars in half steps. With [onChanged], tap the left half of a star for ½.
/// Tapping the current rating again clears it.
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, this.onChanged, this.size = 20});
  final double value;
  final ValueChanged<double>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final fill = (value - i).clamp(0.0, 1.0);
        final star = SizedBox(
          width: size,
          height: size,
          child: Stack(children: [
            Icon(Icons.star_rounded, size: size, color: kStarEmpty),
            ClipRect(
              clipper: _WidthClipper(fill),
              child: Icon(Icons.star_rounded, size: size, color: kStar),
            ),
          ]),
        );
        if (onChanged == null) return star;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final v = d.localPosition.dx < size / 2 ? i + 0.5 : i + 1.0;
            onChanged!(v == value ? 0 : v);
          },
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: star),
        );
      }),
    );
  }
}

class _WidthClipper extends CustomClipper<Rect> {
  _WidthClipper(this.fraction);
  final double fraction;
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * fraction, size.height);
  @override
  bool shouldReclip(_WidthClipper old) => old.fraction != fraction;
}

/// Real poster when the title matched the catalog, otherwise a colored card
/// whose color comes from the title.
class Poster extends StatelessWidget {
  const Poster({super.key, required this.title, required this.type, this.url, this.width = 72});
  final String title;
  final String type;
  final String? url;
  final double width;

  Widget _fallback() {
    var hash = 0;
    for (final c in title.codeUnits) {
      hash = (hash * 31 + c) & 0xFFFFFFFF;
    }
    final hue = (hash % 360).toDouble();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1, hue, 0.55, 0.38).toColor(),
            HSLColor.fromAHSL(1, (hue + 40) % 360, 0.6, 0.18).toColor(),
          ],
        ),
      ),
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(type == 'show' ? 'TV' : 'FILM',
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white70)),
          const Spacer(),
          Text(title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: width,
        height: width * 1.5,
        child: url == null
            ? _fallback()
            : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => _fallback()),
      ),
    );
  }
}

class TypeBadge extends StatelessWidget {
  const TypeBadge(this.type, {super.key});
  final String type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: type == 'show' ? kShow : kMovie, borderRadius: BorderRadius.circular(4)),
      child: Text(type == 'show' ? 'TV' : 'Movie',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
    );
  }
}

void showError(BuildContext context, Object err) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('$err'), backgroundColor: kDanger),
  );
}
