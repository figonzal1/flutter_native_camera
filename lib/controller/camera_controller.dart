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

  static const MethodChannel _methodChannel = MethodChannel(
      "cl.ryc/permission"); //Nombre del canal debe conincidir con CameraHandler.kt

  CameraController({this.cameraResolution, this.facing = CameraFacing.back});

  ///Metodo para iniciar camara
  Future<void> start() async {
    if (isStarting) {
      logger.d("Called start() while starting.");
      return;
    }

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

              startCamera();
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
          startCamera();

          break;
      }
    } on PlatformException catch (error) {
      isStarting = false;
      logger.f("Camera permission exception: $error");
    }
  }

  Future<void> startCamera() async {
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
  }
}
