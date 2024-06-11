package com.example.flutter_native_camera.camera.handler

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import java.util.LinkedList
import java.util.Queue

class CameraEventHandler(binaryMessenger: BinaryMessenger) : EventChannel.StreamHandler {

    companion object {
        const val MAX_QUEUE_SIZE = 5
    }

    private var eventSink: EventChannel.EventSink? = null
    private val eventChannel = EventChannel(
        binaryMessenger, "cl.ryc/event"
    )

    private val eventQueue: Queue<Map<String, Any>> = LinkedList()


    init {
        eventChannel.setStreamHandler(this)
    }

    fun publishEvent(event: Map<String, Any>) {

        synchronized(eventQueue) {

            if (eventQueue.size >= MAX_QUEUE_SIZE) {
                eventQueue.poll()
            }
            eventQueue.offer(event)
        }
        sendNextEvent()

        /*Handler(Looper.getMainLooper()).post {
            eventSink?.success(event)
        }*/
    }

    private fun sendNextEvent() {
        val event = synchronized(eventQueue) { eventQueue.poll() }
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