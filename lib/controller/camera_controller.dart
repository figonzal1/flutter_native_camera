import 'dart:async';

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

  StreamSubscription? events;

  CameraController({this.cameraResolution, this.facing = CameraFacing.back});

  ///Metodo para iniciar camara
  Future<Map<String, dynamic>?> start() async {
    Map<String, dynamic>? startResult = {};

    if (isStarting) {
      logger.d("Called start() while starting.");
      return null;
    }

    events ??= _eventChannel.receiveBroadcastStream().listen((data) {});

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

    return result;
  }
}
