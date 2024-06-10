import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_native_camera/controller/camera_controller.dart';
import 'package:flutter_native_camera/utils/enum.dart';
import 'package:path_provider/path_provider.dart';

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

  StreamSubscription? imageSubscription;

  int? _textureId;
  double? width;
  double? height;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    cameraController = CameraController(
        facing: CameraFacing.back, cameraResolution: const Size(1280, 720));
  }

  Future<void> startCamera() async {
    Map<String, dynamic>? map = await cameraController.start();

    logger.d("MAP: $map");
    setState(() {
      if (map != null) {
        _textureId = map['textureId'];
        width = map['size'].width;
        height = map['size'].height;
      }
    });

    //_startScanner();
  }

  void _startScanner() {
    cameraController.liveness.listen((data) {
      logger.f("Data in flutter UI: $data");
    });
  }

  @override
  Widget build(BuildContext context) {
    //final scanWindow = widget.scanWindow;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            const Text("Cámara nativa"),
            MaterialButton(
              onPressed: startCamera,
              color: Theme.of(context).colorScheme.inversePrimary,
              child: const Text("Call nativo"),
            ),
            _textureId != null
                ? Expanded(
                    child: StreamBuilder(
                    stream: cameraController.liveness,
                    builder: (BuildContext context, AsyncSnapshot snapshot) {
                      logger.w("Stream builder data ${snapshot.data}");

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text('Cargando...');
                      } else if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else {
                        // Aquí es donde procesarías y renderizarías el nuevo frame.
                        // Por ejemplo, podrías convertir los bytes en una imagen y mostrarla en un widget Image.
                        // Este es solo un ejemplo y necesitarás adaptarlo a tus necesidades.

                        Uint8List bytes = Uint8List.fromList(snapshot.data);

                        _saveImage(bytes);
                        return Image(
                          image: MemoryImage(bytes),
                          fit: BoxFit.cover,
                        );
                      }
                    },
                  ))
                : const Text("Textura nula")
          ],
        ),
      ),
    );
  }

  Widget _valueListener() {
    return ValueListenableBuilder(
        valueListenable: cameraController.startArguments,
        builder: (context, value, child) {
          logger.e("VALUE LISTENER: ${value['size']}");

          if (value == null) {
            return Text("Error");
          }
          return _buildScanner(
              Size(value['size']['width'], value['size']['height']),
              BoxFit.contain,
              value['textureId']);
        });
  }

  Widget _buildScanner(Size size, BoxFit fit, int? textureId) {
    logger.f("Texture ID: $textureId");
    return ClipRect(
      child: FittedBox(
        fit: fit,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: Texture(textureId: textureId!),
        ),
      ),
    );
  }

  Future<void> _saveImage(Uint8List bytes) async {
    try {
      // Obtener la ruta al directorio temporal del dispositivo.
      final directory = await getTemporaryDirectory();
      final path = directory.path;

      // Crear un archivo en la ruta.
      final file = File('$path/image.jpg');

      // Escribir los bytes en el archivo.
      await file.writeAsBytes(bytes);

      print('Imagen guardada en $path');
    } catch (e) {
      print('Error al guardar la imagen: $e');
    }
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
