import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:poc_gps_bateaux/config_provider.dart';
import 'package:provider/provider.dart';

import 'settings_route.dart';
import 'user_position_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(dir.path);
  await FMTCObjectBoxBackend().initialise();
  await FMTCStore('mapStore').manage.create();
  //preloadTiles();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ConfigProvider>(create: (_) => ConfigProvider()),
        ChangeNotifierProxyProvider<ConfigProvider, UserPositionProvider>(
          create: (_) => UserPositionProvider(false),
          update: (_, config, __) => UserPositionProvider(config.enableBackgroundTasks),
        ),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final tileProvider = FMTCTileProvider.allStores(
    allStoresStrategy: BrowseStoreStrategy.readUpdateCreate,
    loadingStrategy: BrowseLoadingStrategy.cacheFirst,
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
      home: MyHomePage(title: Platform.isAndroid ? 'Hello Android user' : 'Hello iOS user', tileProvider: tileProvider),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.tileProvider});

  final String title;
  final TileProvider tileProvider;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool shouldDisplayLastLocationOnly = false;
  bool shouldDisplayLinesBetweenLocations = false;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserPositionProvider>(context, listen: false).initBackgroundService();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<ConfigProvider>(context);
    final userPositionProvider = Provider.of<UserPositionProvider>(context);
    final userPositions = userPositionProvider.items;
    final isTracking = userPositionProvider.isTracking;

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
      body: Stack(
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
                tileProvider: widget.tileProvider,
              ),
              if (config.shouldDisplayLinesBetweenLocations && userPositions.length > 1)
                PolylineLayer(
                  polylines: [
                    Polyline(points: userPositions.map((e) => e.position).toList(), strokeWidth: 4, color: Colors.red),
                  ],
                ),
              MarkerLayer(
                markers:
                    userPositions
                        .take(config.shouldDisplayLastLocationOnly ? 1 : userPositions.length)
                        .map(
                          (e) => Marker(point: e.position, child: Icon(Icons.place, color: Colors.red), rotate: false),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FutureBuilder(
        future: isTracking,
        builder:
            (ctx, data) =>
                data.hasData
                    ? FloatingActionButton.extended(
                      onPressed:
                          data.data! ? userPositionProvider.stopTracking : userPositionProvider.startRecordingLocations,
                      label:
                          data.data!
                              ? Text(
                                'Stop recording (${config.enableBackgroundTasks ? 'background - 15sec' : 'foreground - 15sec'})',
                              )
                              : Text(
                                'Start recording (${config.enableBackgroundTasks ? 'background - 15sec' : 'foreground - 15sec'})',
                              ),
                      icon:
                          data.data!
                              ? const Icon(Icons.fiber_manual_record, color: Colors.red)
                              : const Icon(Icons.fiber_manual_record_outlined, color: Colors.grey),
                    )
                    : SizedBox(),
      ),
    );
  }
}

Future<void> preloadTiles({LatLng? lastPosition}) async {
  final position = lastPosition ?? LatLng(48.870769, 2.332324);

  final region = CircleRegion(
    position,
    10, // rayon en kilomètres
  );

  final downloadableRegion = region.toDownloadable(
    minZoom: 10,
    maxZoom: 15,
    options: TileLayer(
      urlTemplate:
          'https://tiles.stadiamaps.com/tiles/stamen_toner/{z}/{x}/{y}@2x.png?api_key=7c2dac10-ea74-48bd-aedc-cd8b320cae94',
      userAgentPackageName: 'com.example.app',
    ),
  );

  final store = const FMTCStore('mapStore');
  final (:downloadProgress, :tileEvents) = store.download.startForeground(region: downloadableRegion);

  downloadProgress.listen((progress) {
    logger.i(
      '[MAP DOWNLOAD] Progress: ${progress.successfulTilesCount} / ${progress.attemptedTilesCount + progress.remainingTilesCount} (${progress.percentageProgress}% - ${progress.estRemainingDuration} remaining)',
    );
  });
}

var logger = Logger(
  printer: PrettyPrinter(
    errorMethodCount: 4,
    methodCount: 0,
    lineLength: 150,
    colors: true,
    printEmojis: true,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
);
