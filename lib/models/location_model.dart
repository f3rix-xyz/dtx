class LocationState {
  final bool isLoading;
  final bool isFetching;
  final double latitude;
  final double longitude;
  final double? cachedLatitude;
  final double? cachedLongitude;
  final bool isMapReady;

  LocationState({
    this.isLoading = true,
    this.isFetching = false,
    this.latitude = 19.2183, // Default location
    this.longitude = 73.0864,
    this.cachedLatitude,
    this.cachedLongitude,
    this.isMapReady = false,
  });

  LocationState copyWith({
    bool? isLoading,
    bool? isFetching,
    double? latitude,
    double? longitude,
    double? cachedLatitude,
    double? cachedLongitude,
    bool? isMapReady,
  }) {
    return LocationState(
      isLoading: isLoading ?? this.isLoading,
      isFetching: isFetching ?? this.isFetching,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      cachedLatitude: cachedLatitude ?? this.cachedLatitude,
      cachedLongitude: cachedLongitude ?? this.cachedLongitude,
      isMapReady: isMapReady ?? this.isMapReady,
    );
  }
}
