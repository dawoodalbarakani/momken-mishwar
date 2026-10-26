
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../data/services/connectivity_service.dart';
import '../../../../data/services/map_service.dart';
import '../../../core/map_surface.dart';
import '../../../core/responsive.dart';
import '../view_models/home_view_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeViewModelProvider);
    final notifier = ref.read(homeViewModelProvider.notifier);
    final isTabletOrLarger = context.deviceSize != DeviceSize.mobile;
    return Scaffold(
      // SafeArea keeps the floating layers clear of the status/home bars.
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: MapSurface(
                extraMarkers: {
                  if (state.pickup != null)
                    Marker(
                      markerId: const MarkerId('pickup'),
                      position: state.pickup!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                      infoWindow: const InfoWindow(title: 'نقطة الانطلاق'),
                    ),
                  if (state.destination != null)
                    Marker(
                      markerId: const MarkerId('destination'),
                      position: state.destination!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      infoWindow: const InfoWindow(title: 'الوجهة'),
                    ),
                },
              ),
            ),
            if (state.connectionStatus == ConnectionStatus.offline)
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Card(
                  margin: EdgeInsets.zero,
                  color: Colors.amber,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('لا يوجد اتصال بالإنترنت', textAlign: TextAlign.center),
                  ),
                ),
              ),
            // On mobile the search card floats over the map full-width; on
            // tablet/desktop it becomes a fixed-width panel docked to the
            // leading edge, leaving the rest of the wider canvas visible.
            if (isTabletOrLarger)
              Align(
                alignment: AlignmentDirectional.topStart,
                child: Padding(
                  padding: EdgeInsets.only(top: 16, left: 24, right: 24),
                  child: const _SearchCard(),
                ),
              )
            else
              Positioned(
                top: 16,
                left: 12,
                right: 12,
                child: const _SearchCard(),
              ),
            Align(
              alignment: AlignmentDirectional.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 16, left: 12, right: 12),
                child: _TripSummaryCard(state: state, notifier: notifier),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Which endpoint the search box is currently assigning results to.
enum _PickTarget { pickup, destination }

/// Search panel: pick whether you are choosing the pickup or the destination,
/// search places, and tap a result to assign it. Also exposes "locate me"
/// with its loading/error states surfaced from [HomeNotifier].
class _SearchCard extends ConsumerStatefulWidget {
  const _SearchCard();

  @override
  ConsumerState<_SearchCard> createState() => _SearchCardState();
}

class _SearchCardState extends ConsumerState<_SearchCard> {
  final TextEditingController _queryController = TextEditingController();
  _PickTarget _target = _PickTarget.pickup;
  List<PlaceResult>? _results;
  bool _searching = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = null);
      return;
    }
    setState(() => _searching = true);
    final results = await ref.read(homeViewModelProvider.notifier).searchPlaces(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  void _pick(PlaceResult place) {
    final notifier = ref.read(homeViewModelProvider.notifier);
    if (_target == _PickTarget.pickup) {
      notifier.setPickup(place.latLng);
    } else {
      notifier.setDestination(place.latLng);
    }
    _queryController.clear();
    setState(() => _results = null);
  }

  Future<void> _locateMe() async {
    final notifier = ref.read(homeViewModelProvider.notifier);
    await notifier.locateMe();
    if (!mounted) return;
    // Ride-hailing convention: a fresh fix becomes the pickup unless the
    // rider has already chosen one.
    final current = ref.read(homeViewModelProvider);
    if (current.currentLocation != null && current.pickup == null) {
      notifier.setPickup(current.currentLocation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeViewModelProvider);
    return SizedBox(
      width: responsiveValue<double>(context, mobile: double.infinity, tablet: 360, desktop: 360),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<_PickTarget>(
                segments: const [
                  ButtonSegment(
                    value: _PickTarget.pickup,
                    label: Text('نقطة الانطلاق'),
                    icon: Icon(Icons.trip_origin),
                  ),
                  ButtonSegment(
                    value: _PickTarget.destination,
                    label: Text('الوجهة'),
                    icon: Icon(Icons.place_outlined),
                  ),
                ],
                selected: {_target},
                showSelectedIcon: false,
                onSelectionChanged: (selection) => setState(() => _target = selection.first),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _queryController,
                enabled: !_searching,
                decoration: InputDecoration(
                  hintText: _target == _PickTarget.pickup
                      ? 'ابحث عن حي أو معلم للانطلاق'
                      : 'ابحث عن حي أو معلم للوجهة',
                  prefixIcon: _searching
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : const Icon(Icons.search),
                  filled: true,
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _search,
              ),
              if (_results != null) ..._resultRows(_results!),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: state.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.my_location),
                label: const Text('تحديد موقعي'),
                onPressed: state.isLoading ? null : _locateMe,
              ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 18),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          state.error!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'إخفاء الخطأ',
                        onPressed: () =>
                            ref.read(homeViewModelProvider.notifier).setError(null),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _resultRows(List<PlaceResult> results) {
    if (results.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('لا توجد نتائج مطابقة', textAlign: TextAlign.center),
        ),
      ];
    }
    return [
      const SizedBox(height: 4),
      ...results.take(5).map(
            (place) => ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const Icon(Icons.place_outlined),
              title: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(place.address, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => _pick(place),
            ),
          ),
    ];
  }
}

class _TripSummaryCard extends StatelessWidget {
  final HomeState state;
  final HomeNotifier notifier;

  const _TripSummaryCard({required this.state, required this.notifier});

  static String _coords(LatLng? point) =>
      point == null ? '' : '${point.latitude.toStringAsFixed(3)}, ${point.longitude.toStringAsFixed(3)}';

  @override
  Widget build(BuildContext context) {
    final hasSelection = state.pickup != null || state.destination != null;
    return ContentMaxWidth(
      maxWidth: 480,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Chip(
                      avatar: const Icon(Icons.trip_origin, size: 18),
                      label: Text(
                        state.pickup != null
                            ? 'الانطلاق: ${_coords(state.pickup)}'
                            : 'اختر نقطة الانطلاق',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onDeleted: state.pickup != null ? () => notifier.setPickup(null) : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Chip(
                      avatar: const Icon(Icons.place_outlined, size: 18),
                      label: Text(
                        state.destination != null
                            ? 'الوجهة: ${_coords(state.destination)}'
                            : 'اختر الوجهة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onDeleted:
                          state.destination != null ? () => notifier.setDestination(null) : null,
                    ),
                  ),
                ],
              ),
              if (hasSelection) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: const Text('مسح الكل'),
                    onPressed: notifier.clearSelection,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: (state.pickup == null || state.destination == null)
                    ? null
                    : () => context.go('/quote'),
                child: const Text('احسب الأجرة'),
              ),
              if (!hasSelection)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'ابحث عن نقطة الانطلاق والوجهة لبدء الرحلة',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

