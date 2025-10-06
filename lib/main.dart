import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

void main() {
  // 添加错误处理
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    runApp(
      ChangeNotifierProvider(
        create: (_) => LocationProvider(),
        child: MyApp(),
      ),
    );
  }, (error, stack) {
    print('❌ 错误: $error');
    print('📜 堆栈: $stack');
  });
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
  String _error = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('GPS 追踪'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          if (_error.isNotEmpty)
            Container(
              padding: EdgeInsets.all(8),
              color: Colors.red[100],
              child: Text(_error, style: TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: Consumer<LocationProvider>(
              builder: (context, provider, child) {
                final location = provider.currentLocation;
                
                if (provider.error.isNotEmpty) {
                  return Center(
                    child: Text(
                      provider.error,
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (location != null) {
                  final position = LatLng(location.latitude, location.longitude);
                  
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
                          onMapCreated: (controller) {
                            _mapController = controller;
                            controller.animateCamera(
                              CameraUpdate.newLatLngZoom(position, 15),
                            );
                          },
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
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

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

class LocationProvider with ChangeNotifier {
  LocationData? _currentLocation;
  Timer? _timer;
  String _error = '';
  final String baseUrl = 'http://8.148.153.92:8081';

  LocationData? get currentLocation => _currentLocation;
  String get error => _error;

  LocationProvider() {
    _timer = Timer.periodic(Duration(seconds: 5), (_) => fetchLatestLocation());
  }

  Future<void> fetchLatestLocation() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/location/latest/1'));
      print('📡 API响应: ${response.statusCode} - ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          _currentLocation = LocationData.fromJson(data['data']);
          _error = '';
          notifyListeners();
        } else {
          _error = '服务器返回错误: ${data['message']}';
          notifyListeners();
        }
      } else {
        _error = 'HTTP错误: ${response.statusCode}';
        notifyListeners();
      }
    } catch (e) {
      print('❌ 获取位置失败: $e');
      _error = '错误: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}