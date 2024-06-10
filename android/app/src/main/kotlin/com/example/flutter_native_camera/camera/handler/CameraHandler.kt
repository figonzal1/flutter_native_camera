package com.example.flutter_native_camera.camera.handler

import android.app.Activity
import android.content.Context
import android.graphics.ImageFormat
import android.hardware.display.DisplayManager
import android.hardware.display.DisplayManager.DisplayListener
import android.os.Build
import android.util.Log
import android.util.Size
import android.view.Surface
import android.view.WindowManager
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.core.resolutionselector.ResolutionSelector
import androidx.camera.core.resolutionselector.ResolutionStrategy
import androidx.camera.core.resolutionselector.ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.example.flutter_native_camera.camera.permission.CameraPermission
import com.example.flutter_native_camera.camera.utils.toByteArrayYUV420
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener
import io.flutter.view.TextureRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.nio.ByteBuffer
import java.util.concurrent.Executor

class CameraHandler(
    private val activity: Activity,
    binaryMessenger: BinaryMessenger,
    private val permission: CameraPermission,
    private val addPermissionListener: (RequestPermissionsResultListener) -> Unit,
    private val cameraEventHandler: CameraEventHandler,
    private val textureRegistry: TextureRegistry

) : MethodCallHandler {

    private var methodChannel: MethodChannel? = null

    private var cameraProvider: ProcessCameraProvider? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var preview: Preview? = null
    private var analysis: ImageAnalysis? = null
    private var camera: Camera? = null
    private var displayListener: DisplayListener? = null

    private val coroutineScope = CoroutineScope(Dispatchers.Default)


    init {
        methodChannel = MethodChannel(binaryMessenger, "cl.ryc/permission")
        methodChannel!!.setMethodCallHandler(this);
    }


    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {


        when (call.method) {
            "checkPermission" -> result.success(permission.hasCameraPermission())

            "requestPermission" -> permission.requestPermission(addPermissionListener = addPermissionListener,
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

            "startCamera" -> start(call, result)

            else -> result.notImplemented()
        }
    }

    private fun start(
        call: MethodCall,
        result: MethodChannel.Result
    ) {
        val cameraResolutionValues: List<Int>? =
            call.argument<List<Int>>("cameraResolution")

        Log.d(
            "START_CAMERA",
            "Camera resolution: ${cameraResolutionValues?.get(0)} - ${cameraResolutionValues?.get(1)}"
        )

        val cameraResolution: Size? =
            if (cameraResolutionValues != null) {
                Size(
                    cameraResolutionValues[0],
                    cameraResolutionValues[1]
                )
            } else {
                null
            }

        val cameraProviderFuture = ProcessCameraProvider.getInstance(activity)
        val executor = ContextCompat.getMainExecutor(activity)

        cameraProviderFuture.addListener({
            cameraProvider = cameraProviderFuture.get()

            cameraProvider?.unbindAll()
            textureEntry = textureRegistry.createSurfaceTexture()

            previewBuilder(executor)
            analysisBuilder(cameraResolution, executor)

            try {
                camera = cameraProvider?.bindToLifecycle(
                    activity as LifecycleOwner,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    preview,
                    analysis
                )
            } catch (e: Exception) {
                Log.e("START_CAMERA", "Use case binding failed", e)
                return@addListener
            }

            val resolution = analysis!!.resolutionInfo!!.resolution
            val width = resolution.width.toDouble()
            val height = resolution.height.toDouble()
            val portrait = (camera?.cameraInfo?.sensorRotationDegrees ?: 0) % 180 == 0

            result.success(
                mapOf(
                    "textureId" to textureEntry!!.id(),
                    "size" to mapOf(
                        "width" to if (portrait) width else height,
                        "height" to if (portrait) height else width,
                    )
                ),
            )

        }, executor)
    }

    private fun analysisBuilder(
        cameraResolution: Size?,
        executor: Executor
    ) {
        val analysisBuilder = ImageAnalysis.Builder()
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)

        val displayManager =
            activity.applicationContext.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager

        if (cameraResolution != null) {
            val selector = ResolutionSelector.Builder().setResolutionStrategy(
                ResolutionStrategy(
                    getResolution(cameraResolution),
                    FALLBACK_RULE_CLOSEST_LOWER_THEN_HIGHER
                )
            )
            analysisBuilder.setResolutionSelector(selector.build())

            if (displayListener == null) {
                displayListener = object : DisplayListener {
                    override fun onDisplayAdded(displayId: Int) {}

                    override fun onDisplayRemoved(displayId: Int) {}

                    override fun onDisplayChanged(displayId: Int) {
                        analysisBuilder.setResolutionSelector(selector.build())
                    }
                }

                displayManager.registerDisplayListener(
                    displayListener, null,
                )
            }
        }

        analysis = analysisBuilder.build()
            .also {
                it.setAnalyzer(executor, captureOutput)
            }
    }

    private fun previewBuilder(executor: Executor) {
        val surfaceProvider = Preview.SurfaceProvider { request ->

            val texture = textureEntry?.surfaceTexture()
            texture?.setDefaultBufferSize(
                request.resolution.width, request.resolution.height
            )

            val surface = Surface(texture)
            request.provideSurface(surface, executor) {}
        }

        // Build the preview to be shown on the Flutter texture
        val previewBuilder = Preview.Builder()
        preview = previewBuilder.build().also { it.setSurfaceProvider(surfaceProvider) }
    }

    private fun getResolution(cameraResolution: Size): Size {
        val rotation = if (Build.VERSION.SDK_INT >= 30) {
            activity.display!!.rotation
        } else {
            val windowManager =
                activity.applicationContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager

            windowManager.defaultDisplay.rotation
        }

        val widthMaxRes = cameraResolution.width
        val heightMaxRes = cameraResolution.height

        val targetResolution =
            if (rotation == Surface.ROTATION_0 || rotation == Surface.ROTATION_180) {
                Size(widthMaxRes, heightMaxRes) // Portrait mode
            } else {
                Size(heightMaxRes, widthMaxRes) // Landscape mode
            }
        return targetResolution
    }

    private fun ByteBuffer.toByteArray(): ByteArray {
        rewind()    // Rewind the buffer to zero
        val data = ByteArray(remaining())
        get(data)   // Copy the buffer into a byte array
        return data // Return the byte array
    }

    private val captureOutput = ImageAnalysis.Analyzer { imageProxy -> // YUV_420_888 format
        coroutineScope.launch {

            //val buffer = imageProxy.planes[0].buffer
            //val data = buffer.toByteArray()
            val data = imageProxy.toByteArrayYUV420()

            if (data != null) {
                val mapEvent = mapOf(
                    "image" to data
                )

                cameraEventHandler.publishEvent(mapEvent)
            }
            imageProxy.close()


            /*if (imageProxy.format == ImageFormat.YUV_420_888) {

                //val rotation = imageProxy.imageInfo.rotationDegrees

                val imageByteArray = imageProxy.toByteArrayYUV420()
                if (imageByteArray != null) {

                    val mapEvent = mapOf(
                        "image" to imageByteArray
                    )

                    Log.d("CAPTURE_OUTPUT", imageByteArray.toList().toString())
                    cameraEventHandler.publishEvent(mapEvent)

                    /*if (isReadyToSetup()) {
                        val rectCamera = Rect(0, 0, imageProxy.height, imageProxy.width)
                        val rectMask = convertScanWindowArrayToRect(scanWindow, imageProxy)
                        setUpLivenessSDK(rectCamera, rectMask)
                        isStarted = true
                    } else if (isReadyToProcess()) {
                        // TODO: Add your ML processing here
                    }*/
                }
                imageProxy.close()
            }*/
        }
    }

    fun dispose(activityPluginBinding: ActivityPluginBinding) {
        methodChannel?.setMethodCallHandler(null)
        methodChannel = null

        val listener: RequestPermissionsResultListener? = permission.getPermissionListener()

        if (listener != null) {
            activityPluginBinding.removeRequestPermissionsResultListener(listener)
        }

    }
}