import 'package:flutter/material.dart';

/// Centralized elevation tokens.
///
/// PhotoBooth leans on soft, low-contrast shadows over hard Material elevation
/// so cards read as printed paper rather than floating chrome. All shadows use
/// the charcoal ink color at low alpha to stay consistent with the palette.
abstract final class AppShadows {
  /// No shadow at all (the default for flat surfaces).
  static const List<BoxShadow> none = <BoxShadow>[];

  /// Barely-there lift for resting cards.
  static const List<BoxShadow> soft = <BoxShadow>[
    BoxShadow(color: Color(0x0F302B30), blurRadius: 16, offset: Offset(0, 6)),
  ];

  /// Default card elevation.
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x14302B30), blurRadius: 26, offset: Offset(0, 10)),
  ];

  /// Keepsake / print preview elevation.
  static const List<BoxShadow> lifted = <BoxShadow>[
    BoxShadow(color: Color(0x1F302B30), blurRadius: 38, offset: Offset(0, 18)),
  ];

  /// Pink glow used to mark a selected card.
  static const List<BoxShadow> selected = <BoxShadow>[
    BoxShadow(color: Color(0x3DF4A7B9), blurRadius: 22, offset: Offset(0, 10)),
  ];

  /// White inner rim that gives a selected card a printed-edge highlight.
  static const List<BoxShadow> rim = <BoxShadow>[
    BoxShadow(color: Color(0x66FFFFFF), blurRadius: 0, spreadRadius: 2),
  ];
}
