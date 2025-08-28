import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'ConfigProvider.dart';
import 'UserPositionProvider.dart';

class SettingsRoute extends StatelessWidget {
  const SettingsRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final config = Provider.of<ConfigProvider>(context);
    final userPositionProvider = Provider.of<UserPositionProvider>(context);
    final userLocations = userPositionProvider.items;
    return Scaffold(
      appBar: AppBar(title: Text("Settings")),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Options", style: TextStyle(fontSize: 24)),
                    SwitchListTile(
                      title: Text("Should use background tasks for locations"),
                      value: config.enableBackgroundTasks,
                      onChanged: config.updateEnableBackgroundTasks,
                    ),
                    SwitchListTile(
                      title: Text("Only display last known position"),
                      value: config.shouldDisplayLastLocationOnly,
                      onChanged: config.updateShouldDisplayLastLocationOnly,
                    ),
                    SwitchListTile(
                      title: Text("Display lines between positions"),
                      value: config.shouldDisplayLinesBetweenLocations,
                      onChanged: userLocations.length <= 1 ? null : config.updateShouldDisplayLinesBetweenLocations,
                    ),
                    SizedBox(height: 24),
                    Text("User positions (${userLocations.length}):", style: TextStyle(fontSize: 24)),
                    SizedBox(height: 8),
                    if (userLocations.isEmpty) Text("No positions recorded yet"),
                    ...userLocations.map(
                      (e) => Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(Icons.add_location),
                          SizedBox(width: 12),
                          Text(
                            "(${e.position.latitude.toStringAsFixed(4)}, ${e.position.longitude.toStringAsFixed(4)})",
                          ),
                          SizedBox(width: 25),
                          Text(DateFormat('dd-MM-yyyy – kk:mm:ss').format(e.timestamp)),
                        ],
                      ),
                    ),
                    SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 16,
                children: [
                  ElevatedButton(
                    onPressed: userPositionProvider.clear,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text("Clear positions", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: userPositionProvider.retrieveUserPositionsFromLocalStorage,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh),
                        SizedBox(width: 8),
                        Text("Reload Local", style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
