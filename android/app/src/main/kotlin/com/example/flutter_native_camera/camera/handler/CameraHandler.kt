package com.example.flutter_native_camera.camera.handler

import android.app.Activity
import android.util.Log
import com.example.flutter_native_camera.camera.permission.CameraPermission
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener

class CameraHandler(
    private val activity: Activity,
    binaryMessenger: BinaryMessenger,
    private val permission: CameraPermission,
    private val addPermissionListener: (RequestPermissionsResultListener) -> Unit,

    ) : MethodCallHandler {

    private var methodChannel: MethodChannel? = null

    init {
        methodChannel = MethodChannel(binaryMessenger, "cl.ryc/permission")
        methodChannel!!.setMethodCallHandler(this);
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {


        when (call.method) {
            "checkPermission" -> {
                result.success(permission.hasCameraPermission())
            }

            "requestPermission" -> {
                permission.requestPermission(addPermissionListener = addPermissionListener,
                    object : CameraPermission.ResultCallback {
                        override fun onResult(errorCode: String?, errorDescription: String?) {

                            Log.d("REQUEST_PERMISSION", "Result $errorCode - $errorDescription")

                            when (errorCode) {
                                null -> result.success(true)
                                "CAMERA_ERROR" -> result.success(false)
                                else -> result.error(errorCode, errorDescription, null)
                            }
                        }
                    }
                )
            }

            else -> result.notImplemented()
        }
    }
}