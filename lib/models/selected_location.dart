enum LocationSource { currentGps, citySearch }

class SelectedLocation {
  final double latitude;
  final double longitude;
  final String? cityName;
  final LocationSource source;

  SelectedLocation({
    required this.latitude,
    required this.longitude,
    this.cityName,
    required this.source,
  });

  bool get isGps => source == LocationSource.currentGps;
  bool get isCitySearch => source == LocationSource.citySearch;

  String get displayTitle {
    if (cityName != null && cityName!.trim().isNotEmpty && !cityName!.contains('GPS Location')) {
      return cityName!.trim();
    }
    return 'Current GPS (${latitude.toStringAsFixed(3)}, ${longitude.toStringAsFixed(3)})';
  }

  String get sourceBadgeText {
    if (isGps) {
      return 'Using your current location';
    }
    final name = (cityName != null && cityName!.trim().isNotEmpty) ? cityName!.trim() : 'searched area';
    return 'Showing hospitals near $name';
  }

  String get badgeText => sourceBadgeText;
}
