package com.example.flutter_native_camera.camera.permission

import android.content.pm.PackageManager
import android.util.Log
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener

internal class CameraPermissionListener(
    private val resultCallback: (String?, String?) -> Unit
) : RequestPermissionsResultListener {

    private var alreadyCalled: Boolean = false


    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {


        if (alreadyCalled || requestCode != CameraPermission.REQUEST_CODE) {
            return false
        }

        alreadyCalled = true

        // grantResults could be empty if the permissions request with the user is interrupted
        // https://developer.android.com/reference/android/app/Activity#onRequestPermissionsResult(int,%20java.lang.String[],%20int[])
        if (grantResults.isEmpty() || grantResults[0] != PackageManager.PERMISSION_GRANTED) {

            Log.d("CamPermissionListener", "Camera permission denied")
            resultCallback("CAMERA_ERROR", "Camera permission denied")
            /*
            resultCallback.onResult(
                "CAMERA_ERROR", "Camera permission denied"
            )*/
        } else {
            Log.d("CamPermissionListener", "Camera permission approved")
            resultCallback(null, null)
            //resultCallback.onResult(null, null)
        }

        return true
    }


}