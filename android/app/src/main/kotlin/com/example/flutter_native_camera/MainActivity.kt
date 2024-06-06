package com.example.flutter_native_camera

import com.example.flutter_native_camera.camera.flutterplugin.CameraPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        flutterEngine.plugins.add(CameraPlugin())
    }
}
