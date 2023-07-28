import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

Future<List<Map<String, dynamic>>> parseGeoJson() async {
  // Read the GeoJSON data from the file
  String jsonString = await rootBundle.loadString('Assets/COLOMBO.geojson');

  // Parse the GeoJSON data
  List<Map<String, dynamic>> areaList = [];
  Map<String, dynamic> data = json.decode(jsonString);
  // debugPrint(data.toString());
  List<dynamic> features = data['features'];
  // debugPrint(features.toString());

  // var dat = await jsonDecode(result.body);

  // List<String> listofid = arealist.map((map) => map['_id'] as String).toList();
  // debugPrint(listofid.toString());

  for (var feature in features) {
    Map<String, dynamic> geometry = feature['geometry'];
    Map<String, dynamic> properties = feature['properties'];
    String name = properties['name'];
    String type = geometry['type'];
    // String id = feature['id'];

    // var res = await jsonDecode(result.body);
    // debugPrint(result.body);
    // debugPrint(result.body);
    if (type == 'MultiPolygon') {
      List<dynamic> polygons = geometry['coordinates'];
      for (var polygon in polygons) {
        List<LatLng> coordinates = [];
        for (var ring in polygon) {
          for (var coord in ring) {
            coordinates.add(LatLng(coord[1], coord[0]));
          }
        }
        areaList.add({
          'name': name,
          'coordinates': coordinates,
        });
      }
    }
  }
  var result = await http.get(
    Uri.parse("http://192.168.8.183:5000/api/mapdetails"),
  );
  List<Map<String, dynamic>> arealist =
      List<Map<String, dynamic>>.from(jsonDecode(result.body));
  List<Map<String, dynamic>> filteredarea = [];
  for (var area in areaList) {
    var datamatch = arealist.firstWhere(
      (data) => data['area'] == area['name'],
      orElse: ()=> {},
    );
    // debugPrint(datamatch.toString());
    if (datamatch.isNotEmpty) {
      area['_id'] = datamatch['_id'];
      area['count'] = datamatch['count'];
      filteredarea.add(area);
    }
  }
   debugPrint(filteredarea.toString());
  return filteredarea;
}

class GoogleMapScreen extends StatefulWidget {
  @override
  _GoogleMapScreenState createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  late GoogleMapController _mapController;
  late Future<List<Map<String, dynamic>>> _mapAreas;
  Set<Polygon> _polygons = {};
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadMapAreas();
  }

  Future<void> _loadMapAreas() async {
    _mapAreas = parseGeoJson();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: const Text('Dengue Affected Areas'), centerTitle: true),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _mapAreas,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading GeoJSON data'));
          } else {
            // Clear any existing polygons and markers before building the map
            _polygons.clear();
            _markers.clear();

            return GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  snapshot.data!.first['coordinates'][0].latitude,
                  snapshot.data!.first['coordinates'][0].longitude,
                ),
                zoom: 15.0,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
              },
              polygons: snapshot.data!.map((area) {
                // List<String> redarea = [
                //   "Malapalla East",
                //   "Thaldiyawala",
                //   "Sri Saranankara",
                //   "Fort",
                // ];
                return Polygon(
                  polygonId: PolygonId(area['name']),
                  points: area['coordinates'],
                  fillColor: area['count'] >= 100 ? Colors.red.withOpacity(1):(area['count'] >= 50 ? Colors.red.withOpacity(0.5):Colors.red.withOpacity(0.2)),
                  strokeColor: Colors.red,
                  strokeWidth: 2,
                  onTap: () {
                    // When the polygon is tapped, show the corresponding marker's info window
                    String name = area['name'];
                    for (Marker marker in _markers) {
                      if (marker.markerId.value == name) {
                        _mapController.showMarkerInfoWindow(marker.markerId);
                        break;
                      }
                    }
                  },
                );
              }).toSet(),
              markers: snapshot.data!.map((area) {
                // List<String> redarea = [
                //   "Malapalla East",
                //   "Thaldiyawala",
                //   "Sri Saranankara",
                //   "Fort",
                // ];
                // Create a marker for each polygon at its centroid
                LatLng centroid = _calculateCentroid(area['coordinates']);
                return Marker(
                  markerId: MarkerId(area['name']),
                  position: centroid,
                  visible: true,
                  onTap: () {
                    showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                              title: Text(area['name']),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [Text("Dengue Affected Count = "+area['count'].toString()),],
                              ),
                            ));
                  },
                  flat: Paint.enableDithering,
                  // infoWindow: InfoWindow(title: area['name']),
                );
              }).toSet(),
            );
          }
        },
      ),
    );
  }

  LatLng _calculateCentroid(List<LatLng> points) {
    double latitudeSum = 0;
    double longitudeSum = 0;

    for (LatLng point in points) {
      latitudeSum += point.latitude;
      longitudeSum += point.longitude;
    }

    double centroidLatitude = latitudeSum / points.length;
    double centroidLongitude = longitudeSum / points.length;

    return LatLng(centroidLatitude, centroidLongitude);
  }
}

// void main() => runApp(MaterialApp(home: GoogleMapScreen()));
