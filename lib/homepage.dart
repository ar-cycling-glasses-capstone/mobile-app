// Copyright 2020 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

// import 'package:flutter_blue/flutter_blue.dart';
import 'package:platform_design/bluetooth/bluetooth-connect-serial.dart';
import 'package:platform_design/bluetooth/bluetooth-fns.dart';
import 'package:platform_design/components/altitude-widget.dart';
import 'package:platform_design/components/display-weather.dart';
import 'package:platform_design/components/weather-fetcher.dart';
import 'package:platform_design/components/hud-toggles.dart';
import 'package:platform_design/utils/api.dart';
import 'package:platform_design/utils/definitions.dart';

import 'components/timer-button.dart';
import 'dart:async';

var template = {
  "timer": false,
  "weather": null,
  "hud_toggles": null,
};

class OptionTab extends StatefulWidget {
  static const title = 'Home';
  static const androidIcon = Icon(Icons.home);
  static const iosIcon = Icon(CupertinoIcons.home);

  const OptionTab({super.key, this.androidDrawer});

  final Widget? androidDrawer;

  @override
  State<OptionTab> createState() => _OptionTabState();
}

class _OptionTabState extends State<OptionTab> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;

  String bluetoothAddress = "...";
  String bluetoothName = "...";

  BluetoothDevice? connectedDevice = null;
  BluetoothConnection? conn = null;

  SystemStatus status = SystemStatus.off;

  Map<String, dynamic> weather = {};
  double altitude = 0;
  String timer = 'stop';

  var hudToggles = {
    "weather": true,
    "biometrics": true,
    "blindspot": true,
    "bike_stats": true,
    "timer": true,
    "altitude": true,
  };

  bool isScanning = false;

  @override
  void initState() {
    super.initState();

    getConnectedDevice().then((device) {
      setState(() {
        connectedDevice = device;
        status = SystemStatus.connected;
      });

      // set connection
      BluetoothConnection.toAddress(connectedDevice?.address)
          .then((_connection) {
        setState(() {
          conn = _connection;
        });
        // Once established, send everything
        // print("Established conn, will send");
     
      });
    }).catchError((e) {
      connectedDevice = null;
      status = SystemStatus.off;
    });

    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });

    fetchAltitudeData().then((altitudeData) => _setAltitude(altitudeData));

    Future.doWhile(() async {
      // Wait if adapter not enabled
      if ((await FlutterBluetoothSerial.instance.isEnabled) ?? false) {
        return false;
      }
      await Future.delayed(Duration(milliseconds: 0xDD));
      return true;
    }).then((_) {
      // print(FlutterBluetoothSerial.instance.getBondedDevices());
      // Update the address field
      FlutterBluetoothSerial.instance.address.then((address) {
        setState(() {
          bluetoothAddress = address!;
        });
      });
    });

    FlutterBluetoothSerial.instance
        .getBondedDevices()
        .then((devices) => {devices.map((device) => print(device.address))});

    FlutterBluetoothSerial.instance.name.then((name) {
      setState(() {
        bluetoothName = name!;
      });
    });

    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;

        // // Discoverable mode is disabled when Bluetooth gets disabled
        // _discoverableTimeoutTimer = null;
        // _discoverableTimeoutSecondsLeft = 0;
      });
    });
  }

  @override
  void dispose() {
    FlutterBluetoothSerial.instance.setPairingRequestHandler(null);
    super.dispose();
  }

  void _refreshData() {
    getConnectedDevice().then((device) {
      setState(() {
        connectedDevice = device;
      });
    });
    return;
  }

  void handleWeatherUpdate(weatherData) {
    print("Update Weather");
    bluetoothSend(conn, jsonEncode({"weather": weatherData}));
    setState(() {
      weather = weatherData;
    });
  }

  void handleTimerUpdate(status) {
    print("Update Timer");
    setState(() {
      timer = status;
    });

    bluetoothSend(conn, jsonEncode({"timer": status}));
  }

  void handleHudToggle(hudData) {
    
  }

  void _setAltitude(double _altitude) {
    print("Set Altitude");
    setState(() {
      altitude = _altitude;
    });
    bluetoothSend(conn, jsonEncode({"altitude": altitude}));
  }

  void _onConnect(BluetoothDevice device, BluetoothConnection _conn) {
    setState(() {
      connectedDevice = device;
      conn = _conn;
    });
    bluetoothSend(conn, jsonEncode({ "hud_toggles": hudToggles, "timer": timer, "weather": weather, "altitude": altitude }));
  }

  void _updateToggle(String key, bool value) {
    setState(() {
      hudToggles[key] = value;
    });
    bluetoothSend(conn, jsonEncode({"hud_toggles": hudToggles}));
  }

  Widget _buildAndroid(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        title: const Text(OptionTab.title),
      ),
      drawer: widget.androidDrawer,
      body: Center(
        child: ListView(
          padding: const EdgeInsets.all(16),
          // mainAxisAlignment: MainAxisAlignment.start,
          // crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: 100,
              child: const Icon(Icons.bluetooth_connected, size: 64.0),
            ),
            Center(
              child: Text(
                connectedDevice != null
                    ? ('Connected to ${connectedDevice?.name}')
                    : ('Not Connected'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            SizedBox(height: 10), // Column Padding
            conn?.isConnected == true
                ? ElevatedButton.icon(
                    icon: const Icon(
                      // <-- Icon
                      Icons.device_hub_outlined,
                      size: 24.0,
                    ),
                    onPressed: () {
                      conn?.dispose();
                    },
                    label: const Text('Disconnect from Glasses'))
                : ElevatedButton.icon(
                    icon: const Icon(
                      // <-- Icon
                      Icons.device_hub_outlined,
                      size: 24.0,
                    ),
                    onPressed: () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => DiscoveryPage(
                                    onConnect: _onConnect,
                                  )));
                    },
                    label: const Text('Connect to Glasses')),
            // connectedDevice?.isConnected == true
            //     ? ElevatedButton.icon(
            //         icon: const Icon(
            //           // <-- Icon
            //           Icons.apps_outlined,
            //           size: 24.0,
            //         ),
            //         onPressed: () {
            //           Navigator.push<void>(
            //               context,
            //               MaterialPageRoute(
            //                   builder: (context) => ControlPanel()));
            //           return;
            //         },
            //         label: const Text('Control Glasses'))
            //     : SizedBox.shrink(),
            SizedBox(height: 32), // Column Padding
            HudToggles(
              hudToggles: hudToggles,
              onToggle: _updateToggle,
            ),
            SizedBox(height: 16),
            TimerButton(onTimerUpdate: handleTimerUpdate),
            SizedBox(height: 16), // Column Padding
            WeatherFetcher(setWeather: handleWeatherUpdate),
            weather.isNotEmpty
                ? DisplayWeather(
                    setWeather: handleWeatherUpdate,
                    weatherJson: jsonEncode(weather))
                : SizedBox.shrink(),
            SizedBox(height: 16),
            AltitudeWidget(
              altitude: altitude,
              onRefresh: _setAltitude,
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _refreshData();
        },
        child: Icon(
          Icons.refresh,
          color: Colors.white,
          size: 29,
        ),
        backgroundColor: Colors.black,
        tooltip: 'Capture Picture',
        elevation: 5,
        splashColor: Colors.grey,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation
          .centerFloat, /*RefreshIndicator(
        key: _androidRefreshKey,
        onRefresh: _refreshData,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: _itemsLength,
          itemBuilder: _listBuilder,
        ),
      ),*/
    );
  }

  @override
  Widget build(context) {
    return _buildAndroid(context);
  }
}

bool checkBluetoothStatus() {
  return true;
}
