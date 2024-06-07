package com.example.flutter_native_camera.camera.handler

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

class CameraEventHandler(binaryMessenger: BinaryMessenger) : EventChannel.StreamHandler {

    private var eventSink: EventChannel.EventSink? = null
    private val eventChannel = EventChannel(
        binaryMessenger, "cl.ryc/event"
    )

    init {
        eventChannel.setStreamHandler(this)
    }

    fun publishEvent(event: Map<String, Any>) {
        Handler(Looper.getMainLooper()).post {
            eventSink?.success(event)
        }
    }

    override fun onListen(arguments: Any?, eventsSink: EventChannel.EventSink?) {
        this.eventSink = eventsSink
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
    }
}