package com.omeda.arc;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.net.ConnectivityManager;
import android.net.NetworkInfo;

import java.util.Map;

import io.flutter.plugin.common.EventChannel;

public class NetworkChangeReceiver extends BroadcastReceiver
{
    private final EventChannel.EventSink _eventSink;

    public NetworkChangeReceiver(EventChannel.EventSink eventSink)
    {
        _eventSink = eventSink;
    }

    @Override
    public void onReceive(Context context, Intent intent)
    {
        boolean noConnectivity = intent.getBooleanExtra(ConnectivityManager.EXTRA_NO_CONNECTIVITY, false);

        if (noConnectivity) {
            _eventSink.success(Map.of("name", "NETWORK_UNAVAILABLE"));
        }
        else {
            //noinspection deprecation
            NetworkInfo networkInfo = intent.getParcelableExtra(ConnectivityManager.EXTRA_NETWORK_INFO);
            _eventSink.success(Map.of(
                    "name", "NETWORK_AVAILABLE",
                    "arguments", NetworkUtils.getNetworkInformation(context, networkInfo)
            ));
        }
    }
}
