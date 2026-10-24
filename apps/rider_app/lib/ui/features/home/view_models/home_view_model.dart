library rider_app.ui.features.home.view_models.home_view_model;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../data/repositories/map_repository.dart';
import '../../../../data/services/connectivity_service.dart';
import '../../../../domain/models/saved_place.dart';
import '../../../../data/services/map_service.dart';

/// ViewModel for the home screen: location picking, saved places, connectivity.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required MapRepository mapRepository,
    required ConnectivityService connectivityService,
  })  : _mapRepository = mapRepository,
        _connectivityService = connectivityService {
    _listenConnectivity();
  }

  final MapRepository _mapRepository;
  final ConnectivityService _connectivityService;
  StreamSubscription? _connectivitySubscription;

  LatLng? _currentLocation;
  LatLng? get currentLocation => _currentLocation;

  LatLng? _pickup;
  LatLng? get pickup => _pickup;

  LatLng? _destination;
  LatLng? get destination => _destination;

  List<SavedPlace> _savedPlaces = const [];
  List<SavedPlace> get savedPlaces => _savedPlaces;

  ConnectionStatus _connectionStatus = ConnectionStatus.unknown;
  ConnectionStatus get connectionStatus => _connectionStatus;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  void _listenConnectivity() {
    _connectivitySubscription = _connectivityService.watch().listen((status) {
      _connectionStatus = status;
      notifyListeners();
    });
  }

  Future<List<PlaceResult>> searchPlaces(String query) async => _mapRepository.searchPlaces(query);

  Future<void> locateMe() async {
    _setLoading(true, error: null);
    try {
      final picked = await _mapRepository.pickLocation();
      _currentLocation = picked;
      _setLoading(false);
    } catch (e) {
      _setLoading(false, error: 'تعذر تحديد الموقع الحالي');
    }
  }

  void setPickup(LatLng? point) {
    _pickup = point;
    notifyListeners();
  }

  void setDestination(LatLng? point) {
    _destination = point;
    notifyListeners();
  }

  void clearSelection() {
    _pickup = null;
    _destination = null;
    notifyListeners();
  }

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void _setLoading(bool loading, {String? error}) {
    _isLoading = loading;
    if (error != null) _error = error;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

final homeViewModelProvider = ChangeNotifierProvider(
  (ref) => HomeViewModel(
    mapRepository: ref.read(mapRepositoryProvider),
    connectivityService: ref.read(connectivityServiceProvider),
  ),
);
