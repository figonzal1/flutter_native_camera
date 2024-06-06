package com.example.flutter_native_camera.camera.flutterplugin

import com.example.flutter_native_camera.camera.handler.CameraHandler
import com.example.flutter_native_camera.camera.permission.CameraPermission
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

class CameraPlugin : FlutterPlugin, ActivityAware {

    private var activityPluginBinding: ActivityPluginBinding? = null
    private var flutterPluginBinding: FlutterPluginBinding? = null
    private var cameraHandler: CameraHandler? = null


    // FLUTTER PLUGIN
    override fun onAttachedToEngine(binding: FlutterPluginBinding) {
        this.flutterPluginBinding = binding
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        this.flutterPluginBinding = null
    }

    // ACTIVITY AWARE
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {

        val binaryMessenger = this.flutterPluginBinding?.binaryMessenger
        val permission = CameraPermission(binding.activity)

        cameraHandler = binaryMessenger?.let {
            CameraHandler(
                binding.activity,
                it,
                permission,
                binding::addRequestPermissionsResultListener
            )
        }


        this.activityPluginBinding = binding
    }

    override fun onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }

    override fun onDetachedFromActivity() {
        cameraHandler = null;
    }

}
