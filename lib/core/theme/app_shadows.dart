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
    BoxShadow(color: Color(0x0F121212), blurRadius: 14, offset: Offset(0, 5)),
  ];

  /// Default card elevation — the white Retro Pop card on pale yellow.
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x14121212), blurRadius: 18, offset: Offset(0, 8)),
  ];

  /// Keepsake / print preview elevation.
  static const List<BoxShadow> lifted = <BoxShadow>[
    BoxShadow(color: Color(0x24121212), blurRadius: 30, offset: Offset(0, 14)),
  ];

  /// Coral glow used to mark a selected card.
  static const List<BoxShadow> selected = <BoxShadow>[
    BoxShadow(color: Color(0x40EB3E54), blurRadius: 18, offset: Offset(0, 8)),
  ];

  /// White inner rim that gives a selected card a printed-edge highlight.
  static const List<BoxShadow> rim = <BoxShadow>[
    BoxShadow(color: Color(0x66FFFFFF), blurRadius: 0, spreadRadius: 2),
  ];
}
