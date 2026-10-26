import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Demo map surface backed by the Google Maps Flutter package.
///
/// On web this renders a real interactive [GoogleMap]; the Maps JavaScript
/// API key is loaded from `web/index.html`, so the demo entry point
/// (`flutter run -t lib/main_demo.dart -d chrome`) shows a live map. On
/// platforms without the native Maps SDK (Linux/Windows desktop) and in
/// widget tests it keeps the grey placeholder, so everything still renders.
class MapSurface extends StatelessWidget {
  /// Sana'a city centre — the demo map's default camera target.
  static const LatLng defaultCenter = LatLng(15.3694, 44.1910);

  final LatLng initialCenter;
  final double initialZoom;
  final LatLng? markerPosition;
  final String markerLabel;
  final String placeholderLabel;

  /// Additional pins (e.g. pickup/destination chosen from search) rendered
  /// alongside [markerPosition] on the web map.
  final Set<Marker> extraMarkers;

  const MapSurface({
    this.initialCenter = defaultCenter,
    this.initialZoom = 12,
    this.markerPosition,
    this.markerLabel = '',
    this.placeholderLabel = 'الخريطة (بانتظار مزود خرائط حقيقي)',
    this.extraMarkers = const {},
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return GoogleMap(
        initialCameraPosition:
            CameraPosition(target: initialCenter, zoom: initialZoom),
        markers: {
          if (markerPosition != null)
            Marker(
              markerId: const MarkerId('demo-marker'),
              position: markerPosition!,
              infoWindow: InfoWindow(title: markerLabel),
            ),
          ...extraMarkers,
        },
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: true,
      );
    }
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.grey.shade200,
      child: Center(child: Text(placeholderLabel)),
    );
  }
}
