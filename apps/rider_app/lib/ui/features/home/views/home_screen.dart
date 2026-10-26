
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../data/services/connectivity_service.dart';
import '../../../../data/services/map_service.dart';
import '../../../core/app_theme.dart';
import '../../../core/map_surface.dart';
import '../../../core/responsive.dart';
import '../view_models/home_view_model.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Opens Uber-style place search for the tapped endpoint and assigns the
  /// chosen result to pickup/destination.
  Future<void> _searchFor(_PickTarget target) async {
    final place = await showModalBottomSheet<PlaceResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlaceSearchSheet(target: target),
    );
    if (place == null || !mounted) return;
    final notifier = ref.read(homeViewModelProvider.notifier);
    if (target == _PickTarget.pickup) {
      notifier.setPickup(place.latLng);
    } else {
      notifier.setDestination(place.latLng);
    }
  }

  /// Locates the rider and uses the fix as the pickup point (the Uber default:
  /// "your current position is where you start").
  Future<void> _useMyLocation() async {
    final notifier = ref.read(homeViewModelProvider.notifier);
    await notifier.locateMe();
    if (!mounted) return;
    final latest = ref.read(homeViewModelProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (latest.error != null) {
      messenger.showSnackBar(SnackBar(
        content: Text(latest.error!),
        backgroundColor: Colors.red.shade700,
      ));
    } else if (latest.currentLocation != null) {
      notifier.setPickup(latest.currentLocation);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeViewModelProvider);
    final isTabletOrLarger = context.deviceSize != DeviceSize.mobile;
    return Scaffold(
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
                    ),
                  if (state.destination != null)
                    Marker(
                      markerId: const MarkerId('destination'),
                      position: state.destination!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
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
            // The booking card docks at the bottom (Uber's "Go anywhere"
            // widget); on wide screens it caps at 480px and stays centred.
            Align(
              alignment: AlignmentDirectional.bottomCenter,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTabletOrLarger ? 24 : 12,
                  vertical: 16,
                ),
                child: _BookingCard(
                  state: state,
                  onPickupTap: () => _searchFor(_PickTarget.pickup),
                  onDestinationTap: () => _searchFor(_PickTarget.destination),
                  onClear: ref.read(homeViewModelProvider.notifier).clearSelection,
                ),
              ),
            ),
            // Map recenter/locate control, floating opposite the booking
            // card like Uber's on-map location button. Last in the Stack so
            // it stays on top of whatever docks at the edges.
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _RoundMapButton(
                  icon: Icons.my_location,
                  tooltip: 'استخدم موقعي كنقطة انطلاق',
                  busy: state.isLoading,
                  onPressed: _useMyLocation,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Which endpoint the place-search sheet is filling in.
enum _PickTarget { pickup, destination }

/// Small white circular button used on top of the map surface.
class _RoundMapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool busy;
  final VoidCallback? onPressed;

  const _RoundMapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: UberColors.white,
        shape: const CircleBorder(side: BorderSide.none),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: busy ? null : onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, color: UberColors.black),
          ),
        ),
      ),
    );
  }
}

/// Uber-style booking widget: destination/pickup rows plus a prices CTA,
/// docked at the bottom of the map.
class _BookingCard extends StatelessWidget {
  final HomeState state;
  final VoidCallback onPickupTap;
  final VoidCallback onDestinationTap;
  final VoidCallback onClear;

  const _BookingCard({
    required this.state,
    required this.onPickupTap,
    required this.onDestinationTap,
    required this.onClear,
  });

  static String _endpointLabel(String fallback, LatLng? point) => point == null
      ? fallback
      : '${point.latitude.toStringAsFixed(3)}, ${point.longitude.toStringAsFixed(3)}';

  @override
  Widget build(BuildContext context) {
    final hasSelection = state.pickup != null || state.destination != null;
    // ConstrainedBox (not ContentMaxWidth) here: the card must shrink-wrap
    // so the outer bottomCentre Align can dock it at the bottom edge.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Card(
        margin: EdgeInsets.zero,
        // Theme keeps cards flat; floating over the map the booking card
        // needs a visible shadow separation.
        elevation: 4,
        shadowColor: const Color(0x33000000),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'إلى أين تريدين الذهاب؟',
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasSelection)
                    IconButton(
                      icon: const Icon(Icons.clear_all, size: 20),
                      tooltip: 'مسح التحديد',
                      onPressed: onClear,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _EndpointTile(
                color: Colors.green,
                filled: state.pickup != null,
                label: _endpointLabel('اختر نقطة الانطلاق', state.pickup),
                onTap: onPickupTap,
              ),
              const SizedBox(height: 8),
              _EndpointTile(
                color: UberColors.black,
                filled: state.destination != null,
                label: _endpointLabel('الوجهة', state.destination),
                onTap: onDestinationTap,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: (state.pickup == null || state.destination == null)
                    ? null
                    : () => context.go('/quote'),
                child: const Text('عرض الأسعار'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One pickup/dropoff row: leading endpoint glyph, label, chevron.
class _EndpointTile extends StatelessWidget {
  final Color color;
  final bool filled;
  final String label;
  final VoidCallback onTap;

  const _EndpointTile({
    required this.color,
    required this.filled,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: UberColors.chipGray,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (filled)
              Icon(Icons.location_on, size: 20, color: color)
            else
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: filled ? UberColors.black : UberColors.mutedGray,
                  fontSize: 15,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: UberColors.bodyGray),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet with autofocus search; an empty query lists every demo place
/// (recent-places style). Pops with the selected [PlaceResult].
class _PlaceSearchSheet extends ConsumerStatefulWidget {
  final _PickTarget target;

  const _PlaceSearchSheet({required this.target});

  @override
  ConsumerState<_PlaceSearchSheet> createState() => _PlaceSearchSheetState();
}

class _PlaceSearchSheetState extends ConsumerState<_PlaceSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  late List<PlaceResult> _results = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    // Show the full demo place list first, like "recent" suggestions.
    _runSearch('');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searching = true);
    final results = await ref.read(homeViewModelProvider.notifier).searchPlaces(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hint = widget.target == _PickTarget.pickup
        ? 'ابحث عن حي أو معلم للانطلاق منه'
        : 'ابحث عن حي أو معلم للذهاب إليه';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          // Cap the sheet so the map stays visible behind it on tall screens.
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: UberColors.mutedGray,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: _runSearch,
                  decoration: InputDecoration(
                    hintText: hint,
                    prefixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.search),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'مسح البحث',
                            onPressed: () {
                              _controller.clear();
                              _runSearch('');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: _results.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text('لا توجد نتائج مطابقة', textAlign: TextAlign.center),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: _results.length,
                          itemBuilder: (_, i) {
                            final place = _results[i];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              leading: const Icon(Icons.place_outlined),
                              title: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                place.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: UberColors.bodyGray),
                              ),
                              onTap: () => Navigator.of(context).pop(place),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
