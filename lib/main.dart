import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

// 位置数据模型
class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;
  final double direction;
  final DateTime timestamp;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.direction,
    required this.timestamp,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      accuracy: double.parse(json['accuracy'].toString()),
      speed: double.parse(json['speed'].toString()),
      direction: double.parse(json['direction'].toString()),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

// 位置数据提供者
class LocationProvider with ChangeNotifier {
  LocationData? _currentLocation;
  Timer? _timer;
  final String baseUrl = 'http://8.148.153.92:8081';

  LocationData? get currentLocation => _currentLocation;

  LocationProvider() {
    // 每5秒获取一次最新位置
    _timer = Timer.periodic(Duration(seconds: 5), (_) => fetchLatestLocation());
  }

  Future<void> fetchLatestLocation() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/location/latest/1'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          _currentLocation = LocationData.fromJson(data['data']);
          notifyListeners();
        }
      }
    } catch (e) {
      print('获取位置失败: $e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => LocationProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS 追踪',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GPS 追踪'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<LocationProvider>(
        builder: (context, provider, child) {
          final location = provider.currentLocation;
          
          if (location != null) {
            final position = LatLng(location.latitude, location.longitude);
            
            // 更新地图标记
            _markers = {
              Marker(
                markerId: MarkerId('current_location'),
                position: position,
                infoWindow: InfoWindow(
                  title: '当前位置',
                  snippet: '精度: ${location.accuracy.toStringAsFixed(2)}m',
                ),
              ),
            };

            // 更新地图视角
            _mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(position, 15),
            );

            return Column(
              children: [
                Expanded(
                  flex: 2,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: position,
                      zoom: 15,
                    ),
                    markers: _markers,
                    onMapCreated: (controller) => _mapController = controller,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Container(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('纬度: ${location.latitude.toStringAsFixed(6)}'),
                        Text('经度: ${location.longitude.toStringAsFixed(6)}'),
                        Text('精度: ${location.accuracy.toStringAsFixed(2)}m'),
                        Text('速度: ${(location.speed * 3.6).toStringAsFixed(2)}km/h'),
                        Text('方向: ${location.direction.toStringAsFixed(1)}°'),
                        Text('时间: ${location.timestamp.toString()}'),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return Center(
            child: CircularProgressIndicator(),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}