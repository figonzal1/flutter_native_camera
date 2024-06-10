import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_camera/utils/enum.dart';
import 'package:logger/logger.dart';

var logger = Logger();

class CameraController {
  //Resolución de cámara
  final Size? cameraResolution;

  // Configuración de cámara
  final CameraFacing facing;

  bool isStarting = false;

  //Nombre del canal debe conincidir con CameraHandler.kt
  static const MethodChannel _methodChannel =
      MethodChannel("cl.ryc/permission");

  static const EventChannel _eventChannel = EventChannel("cl.ryc/event");

  /// Sets the face liveness stream
  final StreamController _livenessController = StreamController.broadcast();
  Stream<dynamic> get liveness => _livenessController.stream;
  StreamSubscription? _events;

  /// A notifier that provides several arguments about the FaceLivenessDetection
  final ValueNotifier startArguments = ValueNotifier(null);

  CameraController({this.cameraResolution, this.facing = CameraFacing.back});

  ///Metodo para iniciar camara
  Future<Map<String, dynamic>?> start() async {
    Map<String, dynamic>? startResult = {};

    if (isStarting) {
      logger.d("Called start() while starting.");
      return null;
    }

    _events ??= _eventChannel.receiveBroadcastStream().listen((data) {
      logger.i("Data: $data");
      var image = data['image'];

      _livenessController.add(image);
    });

    isStarting = true;

    final CameraState state;
    try {
      state = CameraState
          .values[await _methodChannel.invokeMethod("checkPermission") as int];

      switch (state) {
        case CameraState.undetermined:
          bool result = false;

          try {
            result = await _methodChannel.invokeMethod("requestPermission");

            if (!result) {
              isStarting = false;
              logger.e("Request permission failed");
            } else {
              logger.i("Request permission granted");

              startResult = await _startCamera();
            }

            break;
          } catch (error) {
            isStarting = false;
          }

        case CameraState.denied:
          isStarting = false;
          logger.e("Request permission denied");

          break;

        case CameraState.authorized:
          logger.i("Request permission authorized");
          startResult = await _startCamera();

          break;
      }
    } on PlatformException catch (error) {
      isStarting = false;
      logger.f("Camera permission exception: $error");
    }

    return startResult;
  }

  Future<Map<String, dynamic>?> _startCamera() async {
    //Init camera
    final Map<String, dynamic> arguments = {};
    arguments['cameraResolution'] = <int>[
      cameraResolution!.width.toInt(),
      cameraResolution!.height.toInt()
    ];

    var result = await _methodChannel.invokeMapMethod<String, dynamic>(
      'startCamera',
      arguments,
    );

    logger.i("Resultado start camera $result");
    return startArguments.value = result;
  }

  void dispose() {
    _events?.cancel();
    _livenessController.close();
  }
}
