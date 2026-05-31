/// Human-readable label for a pot size given in litres.
///
/// Used wherever the UI needs a friendly representation of
/// `Plant.potSizeLitres` — the plant-detail header, the rootbound
/// banner, the add/edit-plant sheet, etc.
///
/// Rules:
///   * 25 L and up collapses to "25 L+" because growers don't pick larger
///     sizes from the chip list — the value comes from a manual entry
///     and the exact litres aren't actionable.
///   * Whole numbers render without decimals ("5 L", not "5.0 L").
///   * Fractional sizes (e.g. 3.5 L) keep one decimal.
String potLabel(double litres) {
  if (litres >= 25) return '25 L+';
  if (litres == litres.truncateToDouble()) {
    return '${litres.toInt()} L';
  }
  return '${litres.toStringAsFixed(1)} L';
}
