import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../models/venue.dart';
import '../services/api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;

  final Set<Marker> _markers = {};
  Venue? _selectedVenue;

  LatLng _currentLocation = const LatLng(-26.2041, 28.0473); // Johannesburg fallback
  bool _isLoading = true;
  bool _locationReady = false;
  String? _errorMessage;

  @override
void initState() {
  super.initState();

  // Let UI load first, then run async stuff
  Future.microtask(() async {
    await _getUserLocation();
    await _loadVenues();
  });
  }


  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    if (_locationReady) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation, 14),
      );
    }
  }

  Future<void> _getUserLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _errorMessage = "Location services are disabled.";
        });
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = "Location permission was denied.";
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _currentLocation = LatLng(position.latitude, position.longitude);
      _locationReady = true;
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to get location: $e";
      });
    }
  }

  Future<void> _loadVenues() async {
  if (!mounted) return;

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    final venues = await ApiService.getVenues(
      lat: _currentLocation.latitude,
      lng: _currentLocation.longitude,
    );

    final markers = <Marker>{};

    // User marker
    markers.add(
      Marker(
        markerId: const MarkerId("user_location"),
        position: _currentLocation,
        infoWindow: const InfoWindow(title: "You are here"),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
      ),
    );

    // Venue markers
    for (final venue in venues) {
      markers.add(
        Marker(
          markerId: MarkerId(venue.id),
          position: LatLng(venue.lat, venue.lng),
          infoWindow: InfoWindow(title: venue.name),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _getMarkerColor(venue.rating),
          ),
          onTap: () {
            if (!mounted) return;
            setState(() {
              _selectedVenue = venue;
            });
          },
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      _markers
        ..clear()
        ..addAll(markers);
    });

    if (_mapController != null && _locationReady) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_currentLocation, 14),
      );
    }
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _errorMessage = "Failed to load venues: $e";
    });
  } finally {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }
}

  double _getMarkerColor(double rating) {
    if (rating >= 4.2) return BitmapDescriptor.hueGreen;
    if (rating >= 3.5) return BitmapDescriptor.hueYellow;
    return BitmapDescriptor.hueRed;
  }

  Widget _buildVenueCard() {
    if (_selectedVenue == null) return const SizedBox();

    return Positioned(
      bottom: 20,
      left: 16,
      right: 16,
      child: Card(
        elevation: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedVenue!.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "⭐ Rating: ${_selectedVenue!.rating.toStringAsFixed(1)}",
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 6),
              Text(
                _selectedVenue!.address,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _selectedVenue!.types.take(3).map((type) {
                  return Chip(
                    label: Text(type.toString()),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        debugPrint("Open details for ${_selectedVenue!.name}");
                      },
                      child: const Text("View Venue"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedVenue = null;
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBarPlaceholder() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        child: TextField(
          readOnly: true,
          decoration: InputDecoration(
            hintText: "Search clubs, lounges, bars...",
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.grey[900],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Positioned(
      bottom: _selectedVenue != null ? 210 : 100,
      right: 20,
      child: FloatingActionButton(
        onPressed: _loadVenues,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildErrorBanner() {
    if (_errorMessage == null) return const SizedBox();

    return Positioned(
      top: 90,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("YIYO"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _currentLocation,
              zoom: 12,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
          ),
          _buildSearchBarPlaceholder(),
          _buildErrorBanner(),
          _buildVenueCard(),
          _buildRefreshButton(),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.25),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}