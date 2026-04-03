package com.omeda.arc;

import android.telephony.PhoneStateListener;

import java.util.Map;

import io.flutter.plugin.common.EventChannel;

public class PhoneStateListenerImpl extends PhoneStateListener
{
    private final EventChannel.EventSink _eventSink;

    public  PhoneStateListenerImpl(EventChannel.EventSink eventSink)
    {
        _eventSink = eventSink;
    }

    @Override
    public void onDataConnectionStateChanged(int state, int networkType)
    {
        _eventSink.success(Map.of(
                "name", "CELLULAR_STATE_CHANGED",
                "arguments", networkType
        ));
    }
}
