package com.omeda.arc;

import android.os.Build;
import android.telephony.TelephonyCallback;

import androidx.annotation.RequiresApi;

import java.util.Map;

import io.flutter.plugin.common.EventChannel;

@RequiresApi(api = Build.VERSION_CODES.S)
public class TelephonyCallbackImpl extends TelephonyCallback
        implements TelephonyCallback.DataConnectionStateListener
{
    private final EventChannel.EventSink _eventSink;

    public TelephonyCallbackImpl(EventChannel.EventSink eventSink)
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
