/// Selectable characters for the Sky Balance mini-game.
///
/// The frog is the game's mascot; the four portraits are bundled photographs
/// that are only ever cropped to a circle, never retouched.
enum SkyCharacterKind { mascot, photo }

enum SkyCharacter {
  katak(
    id: 'katak',
    label: 'Katak',
    asset: 'lib/assets/sky_frog.svg',
    kind: SkyCharacterKind.mascot,
  ),
  rara(
    id: 'rara',
    label: 'Rara',
    asset: 'lib/assets/avatar_rara.png',
    kind: SkyCharacterKind.photo,
  ),
  nadia(
    id: 'nadia',
    label: 'Nadia',
    asset: 'lib/assets/avatar_nadia.png',
    kind: SkyCharacterKind.photo,
  ),
  bima(
    id: 'bima',
    label: 'Bima',
    asset: 'lib/assets/avatar_bima.png',
    kind: SkyCharacterKind.photo,
  ),
  dosen(
    id: 'dosen',
    label: 'Dosen',
    asset: 'lib/assets/avatar_lecturer.png',
    kind: SkyCharacterKind.photo,
  );

  const SkyCharacter({
    required this.id,
    required this.label,
    required this.asset,
    required this.kind,
  });

  final String id;
  final String label;
  final String asset;
  final SkyCharacterKind kind;

  bool get isMascot => kind == SkyCharacterKind.mascot;

  static SkyCharacter fromId(String? id) => values.firstWhere(
    (character) => character.id == id,
    orElse: () => katak,
  );
}
