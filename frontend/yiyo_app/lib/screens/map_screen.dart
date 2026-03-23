import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {

  late GoogleMapController mapController;

  final Set<Marker> _markers = {};

  Map<String, dynamic>? selectedVenue;

  LatLng currentLocation = const LatLng(-26.2041, 28.0473);

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _loadVenues();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _getUserLocation() async {

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {

      currentLocation = LatLng(
        position.latitude,
        position.longitude,
      );

    });

    mapController.animateCamera(
      CameraUpdate.newLatLngZoom(currentLocation, 14),
    );

  }

  Future<void> _loadVenues() async {

    try {

      final venues = await ApiService.getVenues();

      setState(() {

        _markers.clear();

        for (var venue in venues) {

          _markers.add(
            Marker(
              markerId: MarkerId(venue["name"]),
              position: LatLng(venue["lat"], venue["lng"]),
              infoWindow: InfoWindow(
                title: venue["name"],
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                _getMarkerColor(venue["vibe"].toDouble()),
              ),
              onTap: () {
                setState(() {
                  selectedVenue = venue;
                });
              },
            ),
          );

        }

      });

    } catch (e) {

      print("Error loading venues: $e");

    }

  }

  double _getMarkerColor(double vibe) {

    if (vibe >= 8.5) {
      return BitmapDescriptor.hueGreen;
    }

    if (vibe >= 7) {
      return BitmapDescriptor.hueYellow;
    }

    return BitmapDescriptor.hueRed;

  }

  Widget venueCard() {

    if (selectedVenue == null) {
      return const SizedBox();
    }

    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Card(
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              Text(
                selectedVenue!["name"],
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "Vibe Score: ${selectedVenue!["vibe"]}",
                style: const TextStyle(fontSize: 16),
              ),

              const SizedBox(height: 10),

              ElevatedButton(
                onPressed: () {},
                child: const Text("View Venue"),
              )

            ],
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
      ),

      body: Stack(
        children: [

          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: currentLocation,
              zoom: 12,
            ),
            markers: _markers,
            myLocationEnabled: true,
          ),

          venueCard()

        ],
      ),

    );

  }
}