library rider_app.domain.models.saved_place;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Clean domain model for a saved place (favorite pickup / destination).
class SavedPlace {
  const SavedPlace({required this.id, required this.name, required this.latLng});

  final String id;
  final String name;
  final LatLng latLng;
}
