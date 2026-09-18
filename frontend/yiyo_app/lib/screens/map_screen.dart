import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'profile_screen.dart';
import '../models/venue.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'venue_details_screen.dart';
import '../widgets/vibe_report_sheet.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final Set<Marker> _markers = {};
  List<Venue> _venues = [];
  Venue? _selectedVenue;

  LatLng _currentLocation = const LatLng(-26.2041, 28.0473);
  bool _isLoading = true;
  bool _locationReady = false;
  bool _isPanelExpanded = false;
  bool _showYiyoOnly = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        _collapsePanel();
      }
      if (mounted) {
        setState(() {});
      }
    });

    Future.microtask(() async {
      await _getUserLocation();
      await _loadCurrentView();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  bool _isKeyboardOpen(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _collapsePanel() {
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.12,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
    if (mounted) {
      setState(() {
        _isPanelExpanded = false;
      });
    }
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _currentLocation = LatLng(position.latitude, position.longitude);
      _locationReady = true;
    } catch (e) {
      setState(() {
        _errorMessage = "Location error: $e";
      });
    }
  }

  Future<void> _loadCurrentView() async {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      await _performSearch(query);
      return;
    }

    if (_showYiyoOnly) {
      await _loadYiyoVenues();
      return;
    }

    await _loadVenues();
  }

  Future<void> _applyVenueList(List<Venue> venues) async {
    final markers = <Marker>{};

    markers.add(
      Marker(
        markerId: const MarkerId("user"),
        position: _currentLocation,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
        infoWindow: const InfoWindow(title: "You"),
      ),
    );

    for (final venue in venues) {
      markers.add(
        Marker(
          markerId: MarkerId(venue.id),
          position: LatLng(venue.lat, venue.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _getMarkerColor(venue.rating),
          ),
          onTap: () {
            if (!mounted) return;
            _dismissKeyboard();
            _focusVenue(venue);
          },
        ),
      );
    }

    Venue? refreshedSelected;
    if (_selectedVenue != null) {
      try {
        refreshedSelected = venues.firstWhere((v) => v.id == _selectedVenue!.id);
      } catch (_) {
        refreshedSelected = null;
      }
    }

    if (!mounted) return;

    setState(() {
      _venues = venues;
      _selectedVenue = refreshedSelected;
      _markers
        ..clear()
        ..addAll(markers);
    });
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

      await _applyVenueList(venues);

      if (_mapController != null) {
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadYiyoVenues() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final venues = await ApiService.getYiyoVenues(
        lat: _currentLocation.latitude,
        lng: _currentLocation.longitude,
      );

      await _applyVenueList(venues);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Failed to load YIYO venues: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;

    _dismissKeyboard();
    _collapsePanel();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ApiService.searchVenues(
        query: query,
        lat: _currentLocation.latitude,
        lng: _currentLocation.longitude,
        enrichArea: false,
      );

      final Venue? bestMatch = result["best_match"] as Venue?;
      final List<Venue> related = result["related_venues"] as List<Venue>;

      final combined = <Venue>[];
      final seen = <String>{};

      if (bestMatch != null) {
        combined.add(bestMatch);
        seen.add(bestMatch.id);
      }

      for (final venue in related) {
        if (!seen.contains(venue.id)) {
          combined.add(venue);
          seen.add(venue.id);
        }
      }

      await _applyVenueList(combined);

      if (bestMatch != null) {
        _focusVenue(bestMatch);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result["used_places_call"] == true
                ? "Search used Places API"
                : "Search found cached result",
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = "Search failed: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearSearch() {
    _dismissKeyboard();
    _searchController.clear();
    _loadCurrentView();
  }

  double _getMarkerColor(double rating) {
    if (rating >= 4.2) return BitmapDescriptor.hueGreen;
    if (rating >= 3.5) return BitmapDescriptor.hueYellow;
    return BitmapDescriptor.hueRed;
  }

  void _togglePanel() {
    if (!_sheetController.isAttached) return;

    _dismissKeyboard();

    if (_isPanelExpanded) {
      _sheetController.animateTo(
        0.12,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      _sheetController.animateTo(
        0.45,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }

    setState(() {
      _isPanelExpanded = !_isPanelExpanded;
    });
  }

  void _focusVenue(Venue venue) {
    _dismissKeyboard();

    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(venue.lat, venue.lng),
        16,
      ),
    );

    setState(() {
      _selectedVenue = venue;
    });

    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.18,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    setState(() {
      _isPanelExpanded = false;
    });
  }

  String _badgeText(Venue venue) {
    final raw = (venue.yiyoBadge ?? "MID").toUpperCase();
    if (raw == "YIYO") return "YIYO";
    if (raw == "NOT YIYO") return "NOT YIYO";
    return "MID";
  }

  Color _badgeColor(Venue venue) {
    final badge = _badgeText(venue);
    if (badge == "YIYO") return Colors.green;
    if (badge == "NOT YIYO") return Colors.red;
    return Colors.orange;
  }

  Future<void> _openReportSheet(Venue venue) async {
  final submitted = await showVibeReportSheet(
    context: context,
    venue: venue,
  );

  if (submitted != true || !mounted) return;

  await _loadCurrentView();

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text("Vibe report submitted"),
    ),
  );
}


  Future<void> _openVenueDetails() async {
    if (_selectedVenue == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VenueDetailsScreen(
          venue: _selectedVenue!,
        ),
      ),
    );

    await _loadCurrentView();
  }

  Future<void> _logout() async {
    await AuthService.signOut();
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Material(
        elevation: 5,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    _performSearch(value.trim());
                  }
                },
                decoration: InputDecoration(
                  hintText: "Search places like Drama, LIV, Piano Bar...",
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                final query = _searchController.text.trim();
                if (query.isNotEmpty) {
                  _performSearch(query);
                }
              },
              icon: const Icon(Icons.arrow_forward),
            ),
            if (_searchController.text.trim().isNotEmpty)
              IconButton(
                onPressed: _clearSearch,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeChips() {
    return Positioned(
      top: 86,
      left: 16,
      right: 16,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text("All"),
            selected: !_showYiyoOnly,
            onSelected: (_) {
              _dismissKeyboard();
              setState(() {
                _showYiyoOnly = false;
              });
              if (_searchController.text.trim().isEmpty) {
                _loadCurrentView();
              }
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text("YIYO Now"),
            selected: _showYiyoOnly,
            onSelected: (_) {
              _dismissKeyboard();
              setState(() {
                _showYiyoOnly = true;
              });
              if (_searchController.text.trim().isEmpty) {
                _loadCurrentView();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    if (_errorMessage == null) return const SizedBox();

    return Positioned(
      top: 128,
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

  Widget _buildTopSpotsPanel() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.12,
      minChildSize: 0.12,
      maxChildSize: 0.45,
      snap: true,
      snapSizes: const [0.12, 0.45],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 12,
                offset: Offset(0, -3),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 80,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      _showYiyoOnly ? "YIYO Right Now" : "Top Nearby Spots",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.only(bottom: 20),
                  itemCount: _venues.length,
                  itemBuilder: (context, index) {
                    final venue = _venues[index];
                    final isSelected = _selectedVenue?.id == venue.id;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Material(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          onTap: () => _focusVenue(venue),
                          leading: CircleAvatar(
                            backgroundColor: isSelected
                                ? Colors.green
                                : Colors.grey[800],
                            child: Text(
                              "${index + 1}",
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            venue.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            "${_badgeText(venue)} • ⭐ ${venue.rating.toStringAsFixed(1)}",
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPanelToggleButton() {
    return Positioned(
      bottom: 95,
      right: 16,
      child: FloatingActionButton(
        heroTag: "panel_toggle",
        onPressed: _togglePanel,
        child: Icon(
          _isPanelExpanded
              ? Icons.keyboard_arrow_down
              : Icons.keyboard_arrow_up,
        ),
      ),
    );
  }

  Widget _buildVenueCard(BuildContext context) {
    if (_selectedVenue == null || _isKeyboardOpen(context)) {
      return const SizedBox();
    }

    return Positioned(
      left: 16,
      right: 16,
      bottom: 180,
      child: Material(
        color: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          child: Card(
            elevation: 14,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedVenue!.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _badgeColor(_selectedVenue!),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _badgeText(_selectedVenue!),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
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
                  const SizedBox(height: 6),
                  Text(
                    "⭐ ${_selectedVenue!.rating.toStringAsFixed(1)}",
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _selectedVenue!.address,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _openVenueDetails,
                          child: const Text("View Venue"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openReportSheet(_selectedVenue!),
                          icon: const Icon(Icons.campaign_outlined),
                          label: const Text("Report"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    if (!_isLoading) return const SizedBox();

    return const Positioned(
      top: 170,
      left: 0,
      right: 0,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = _isKeyboardOpen(context);

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text("YIYO"),
          actions: [
            IconButton(
              tooltip: "Profile",
              icon: const Icon(
                Icons.person_outline,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const ProfileScreen(),
                  ),
                );
              },
            ),
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
            ),
          ],
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
              onTap: (_) => _dismissKeyboard(),
            ),
            _buildSearchBar(),
            _buildModeChips(),
            _buildErrorBanner(),
            if (!keyboardOpen) _buildTopSpotsPanel(),
            if (!keyboardOpen) _buildPanelToggleButton(),
            _buildVenueCard(context),
            _buildLoadingIndicator(),
          ],
        ),
      ),
    );
  }
}