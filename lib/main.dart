import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:latlong2/latlong.dart';
import 'package:poc_gps_bateaux/ConfigProvider.dart';
import 'package:provider/provider.dart';

import 'SettingsRoute.dart';
import 'UserPositionProvider.dart';

void main() async {
  // await FMTCObjectBoxBackend().initialise();
  WidgetsFlutterBinding.ensureInitialized();
  UserPositionsBackgroundService.init();

  runApp(
    MultiProvider(
      providers: [
        // ChangeNotifierProvider<UserPositionProvider>(create: (_) => UserPositionProvider()),
        ChangeNotifierProvider<ConfigProvider>(create: (_) => ConfigProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  /*final tileProvider = FMTCTileProvider.allStores(
    allStoresStrategy: BrowseStoreStrategy.readUpdateCreate,
    loadingStrategy: BrowseLoadingStrategy.cacheFirst,
  );*/

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: MyHomePage(
        title: Platform.isAndroid ? 'Hello Android user' : 'Hello iOS user' /*, tileProvider: tileProvider*/,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title /*, required this.tileProvider*/});

  final String title;

  //final TileProvider tileProvider;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool shouldDisplayLastLocationOnly = false;
  bool shouldDisplayLinesBetweenLocations = false;

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<ConfigProvider>(context);
    // final userPositions = userPositionProvider.items;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (context) => SettingsRoute()));
            },
            icon: Icon(Icons.settings),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: UserPositionsBackgroundService.items,
        builder:
            (ctx, userPositions, _) => Stack(
              alignment: Alignment.topLeft,
              children: [
                FlutterMap(
                  options: MapOptions(initialCenter: LatLng(48.870769, 2.332324)),
                  children: [
                    TileLayer(
                      // urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      urlTemplate:
                          'https://tiles.stadiamaps.com/tiles/stamen_toner/{z}/{x}/{y}@2x.png?api_key=7c2dac10-ea74-48bd-aedc-cd8b320cae94',
                      userAgentPackageName: 'com.example.app',
                      //tileProvider: widget.tileProvider,
                    ),
                    if (config.shouldDisplayLinesBetweenLocations && userPositions.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: userPositions.map((e) => e.position).toList(),
                            strokeWidth: 4,
                            color: Colors.red,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers:
                          userPositions
                              .take(config.shouldDisplayLastLocationOnly ? 1 : userPositions.length)
                              .map(
                                (e) => Marker(
                                  point: e.position,
                                  child: Icon(Icons.place, color: Colors.red),
                                  rotate: false,
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
                if (userPositions.isNotEmpty)
                  Text(
                    "Last known position: (${userPositions.last.position.latitude}, ${userPositions.last.position.longitude})",
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ValueListenableBuilder(
        valueListenable: UserPositionsBackgroundService.isTracking,
        builder:
            (ctx, isTracking, _) => FloatingActionButton.extended(
              onPressed:
                  isTracking
                      ? UserPositionsBackgroundService.stopTracking
                      : UserPositionsBackgroundService.startRecordingLocations,
              label: isTracking ? Text('Stop recording') : Text('Start recording'),
              icon:
                  isTracking
                      ? const Icon(Icons.fiber_manual_record, color: Colors.red)
                      : const Icon(Icons.fiber_manual_record_outlined, color: Colors.grey),
            ),
      ),
    );
  }
}
