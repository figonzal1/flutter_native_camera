import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  static ValueNotifier<Uint8List?> imageNotifier =
      ValueNotifier<Uint8List?>(null);

  int? _textureId;
  double? width;
  double? height;

  Queue<List<int>> queue = Queue<List<int>>();

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

    _startScanner();
  }

  void _startScanner() {
    cameraController.liveness.listen((data) async {
      logger.i("DATA UI:  $data");
      imageNotifier.value = data;
      /*queue.add(data);

      if (queue.isNotEmpty) {
        _saveImage(queue.removeFirst());
      }*/
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
            ValueListenableBuilder<Uint8List?>(
              valueListenable: imageNotifier,
              builder: (context, imageData, child) {
                return imageData == null
                    ? const Text('No image data')
                    : Image.memory(imageData, gaplessPlayback: true);
              },
            ),
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
          return _buildScanner(Size(value['size'].width, value['size'].height),
              BoxFit.contain, value['textureId']);
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

  void _saveImage(List<int> bytes) async {
    try {
      // Obtener la ruta al directorio temporal del dispositivo.
      final directory = await getTemporaryDirectory();
      final path = directory.path;

      // Crear un archivo en la ruta.
      final file = File('$path/${DateTime.now()}.jpg');

      // Escribir los bytes en el archivo.
      await file.writeAsBytes(bytes);

      print('Imagen guardada en $path');
    } catch (e) {
      print('Error al guardar la imagen: $e');
    }
  }
}
