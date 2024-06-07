import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_native_camera/controller/camera_controller.dart';
import 'package:flutter_native_camera/utils/enum.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  //final BoxFit fit;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late CameraController cameraController;

  StreamSubscription? event;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    cameraController = CameraController(
        facing: CameraFacing.back, cameraResolution: const Size(1280, 720));
  }

  Future<void> startCamera() async {
    await cameraController.start();

    _startScanner();
  }

  void _startScanner() {
    /*cameraController.events?.onData((handleData) {
      var mapData = handleData as Map;

      var byteData = mapData['image'] as List<int>;

      Uint8List uint8list = Uint8List.fromList(byteData);

      //_image = Image.memory(uint8list);

      //logger.d("Main screen event received: ${mapData['image']}");


    });*/
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);

    //final scanWindow = widget.scanWindow;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            const Text("Cámara nativa"),
            MaterialButton(
              onPressed: startCamera,
              color: Theme.of(context).colorScheme.inversePrimary,
              child: const Text("Call nativo"),
            ),
            StreamBuilder(
              stream: cameraController.events,
              builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
                if (snapshot.hasData) {
                  var mapData = snapshot.data as Map;
                  var byteData = mapData['image'] as List<int>;

                  // Convertir la lista de enteros en un Uint8List
                  Uint8List uint8list = Uint8List.fromList(byteData);

                  // Usar Image.memory para mostrar la imagen
                  return Image.memory(uint8list);
                } else {
                  // Mostrar un indicador de carga mientras la imagen no está disponible
                  return CircularProgressIndicator();
                }
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildScanner(BoxFit fit, size, int? textureId) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (_, constraints) {
          return SizedBox.fromSize(
            size: constraints.biggest,
            child: FittedBox(
              fit: fit,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: Texture(textureId: textureId!),
              ),
            ),
          );
        },
      ),
    );
  }

  Rect _calculateScanWindowRelativeToTextureInPercentage(
    BoxFit fit,
    Rect scanWindow,
    Size textureSize,
    Size widgetSize,
  ) {
    double fittedTextureWidth;
    double fittedTextureHeight;

    switch (fit) {
      case BoxFit.contain:
        final widthRatio = widgetSize.width / textureSize.width;
        final heightRatio = widgetSize.height / textureSize.height;
        final scale = widthRatio < heightRatio ? widthRatio : heightRatio;
        fittedTextureWidth = textureSize.width * scale;
        fittedTextureHeight = textureSize.height * scale;
        break;

      case BoxFit.cover:
        final widthRatio = widgetSize.width / textureSize.width;
        final heightRatio = widgetSize.height / textureSize.height;
        final scale = widthRatio > heightRatio ? widthRatio : heightRatio;
        fittedTextureWidth = textureSize.width * scale;
        fittedTextureHeight = textureSize.height * scale;
        break;

      case BoxFit.fill:
        fittedTextureWidth = widgetSize.width;
        fittedTextureHeight = widgetSize.height;
        break;

      case BoxFit.fitHeight:
        final ratio = widgetSize.height / textureSize.height;
        fittedTextureWidth = textureSize.width * ratio;
        fittedTextureHeight = widgetSize.height;
        break;

      case BoxFit.fitWidth:
        final ratio = widgetSize.width / textureSize.width;
        fittedTextureWidth = widgetSize.width;
        fittedTextureHeight = textureSize.height * ratio;
        break;

      case BoxFit.none:
      case BoxFit.scaleDown:
        fittedTextureWidth = textureSize.width;
        fittedTextureHeight = textureSize.height;
        break;
    }

    final offsetX = (widgetSize.width - fittedTextureWidth) / 2;
    final offsetY = (widgetSize.height - fittedTextureHeight) / 2;

    final left = (scanWindow.left - offsetX) / fittedTextureWidth;
    final top = (scanWindow.top - offsetY) / fittedTextureHeight;
    final right = (scanWindow.right - offsetX) / fittedTextureWidth;
    final bottom = (scanWindow.bottom - offsetY) / fittedTextureHeight;

    return Rect.fromLTRB(left, top, right, bottom);
  }
}
