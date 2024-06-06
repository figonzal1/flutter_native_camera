package com.example.flutter_native_camera.camera.permission

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener

class CameraPermission(private val activity: Activity) {

    companion object {

        /**
         * When the application's activity is [androidx.fragment.app.FragmentActivity], requestCode can only use the lower 16 bits.
         * @see androidx.fragment.app.FragmentActivity.validateRequestPermissionsRequestCode
         */
        const val REQUEST_CODE = 0x0786
    }

    private var ongoing = false
    private var listener: RequestPermissionsResultListener? = null

    fun getPermissionListener(): RequestPermissionsResultListener? {
        return listener
    }

    fun hasCameraPermission(): Int {

        val hasPermission = ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED

        Log.d("hasCameraPermission", hasPermission.toString())

        return when (hasPermission) {
            true -> 1
            else -> 0
        }
    }

    fun requestPermission(
        addPermissionListener: (RequestPermissionsResultListener) -> Unit,
        callback: ResultCallback
    ) {
        if (ongoing) {
            callback.onResult(
                "CameraPermissionsRequestOngoing",
                "Another request is ongoing and multiple requests cannot be handled at once."
            )
            return
        }

        if (hasCameraPermission() == 1) {
            // Permissions already exist. Call the callback with success.
            callback.onResult(null, null)
            return
        }


        if (listener == null) {

            listener = CameraPermissionListener { errorCode, errorDescription ->
                ongoing = false
                callback.onResult(errorCode, errorDescription)
            }

            addPermissionListener(listener as CameraPermissionListener)
        }

        ongoing = true
        ActivityCompat.requestPermissions(
            activity, arrayOf(Manifest.permission.CAMERA),
            REQUEST_CODE
        )
    }

    interface ResultCallback {
        fun onResult(errorCode: String?, errorDescription: String?)
    }
}