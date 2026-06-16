import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPage extends StatelessWidget {
  final double? driverLat;
  final double? driverLon;
  final double? riderLat;
  final double? riderLon;
  final double? pickupLat;
  final double? pickupLon;

  final String driverLabel;
  final String riderLabel;
  final String pickupLabel;

  const MapPage({
    super.key,
    required this.driverLat,
    required this.driverLon,
    required this.riderLat,
    required this.riderLon,
    required this.pickupLat,
    required this.pickupLon,
    required this.driverLabel,
    required this.riderLabel,
    required this.pickupLabel,
  });

  @override
  Widget build(BuildContext context) {
    final points = <LatLng>[];

    if (driverLat != null && driverLon != null) {
      points.add(LatLng(driverLat!, driverLon!));
    }

    if (riderLat != null && riderLon != null) {
      points.add(LatLng(riderLat!, riderLon!));
    }

    if (pickupLat != null && pickupLon != null) {
      points.add(LatLng(pickupLat!, pickupLon!));
    }

    final center = points.isNotEmpty
        ? points.first
        : const LatLng(37.5665, 126.9780);

    final markers = <Marker>[];

    if (driverLat != null && driverLon != null) {
      markers.add(
        Marker(
          point: LatLng(driverLat!, driverLon!),
          width: 90,
          height: 70,
          child: const Column(
            children: [
              Icon(Icons.directions_car, color: Colors.blue, size: 36),
              Text('운전자', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    if (riderLat != null && riderLon != null) {
      markers.add(
        Marker(
          point: LatLng(riderLat!, riderLon!),
          width: 90,
          height: 70,
          child: const Column(
            children: [
              Icon(Icons.person_pin_circle, color: Colors.red, size: 36),
              Text('신청자', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    if (pickupLat != null && pickupLon != null) {
      markers.add(
        Marker(
          point: LatLng(pickupLat!, pickupLon!),
          width: 100,
          height: 70,
          child: const Column(
            children: [
              Icon(Icons.place, color: Colors.green, size: 38),
              Text('AI 픽업', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('픽업 지도'),
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.hanggun_app',
                ),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('운전자 위치: $driverLabel'),
                Text('신청자 위치: $riderLabel'),
                Text('AI 픽업 위치: $pickupLabel'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}