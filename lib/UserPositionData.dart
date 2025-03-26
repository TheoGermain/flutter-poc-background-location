import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

class UserPositionData extends Equatable {
  final LatLng position;
  final DateTime timestamp;

  const UserPositionData({required this.position, required this.timestamp});

  UserPositionData.fromJson(Map<String, dynamic> json)
    : position = LatLng(double.parse(json['latitude']), double.parse(json['longitude'])),
      timestamp = DateTime.parse(json['timestamp']);

  Map<String, dynamic> toJson() => {
    'latitude': position.latitude.toString(),
    'longitude': position.longitude.toString(),
    'timestamp': timestamp.toIso8601String(),
  };

  @override
  List<Object> get props => [position, timestamp];
}
