package com.omeda.arc;

import android.content.Context;
import android.content.IntentFilter;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.telephony.PhoneStateListener;
import android.telephony.TelephonyManager;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;

import java.util.Map;
import java.util.Objects;

import io.flutter.plugin.common.EventChannel;

public class NetworkEventStreamHandler implements EventChannel.StreamHandler
{
    private final ConnectivityManager _connectivityManager;
    private final Context _context;
    private final Handler _handler;

    private PhoneStateListenerImpl _phoneStateListener;

    private ConnectivityManager.NetworkCallback _networkCallback;
    private NetworkChangeReceiver _networkChangeReceiver;

    public NetworkEventStreamHandler(Context context)
    {
        _connectivityManager = (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        _context = context;
        _handler = new Handler(Looper.getMainLooper());
    }

    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                _networkCallback = new NetworkCallbackImplApi31(events, null);
                _connectivityManager.registerDefaultNetworkCallback(_networkCallback, _handler);
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                _networkCallback = new NetworkCallbackImpl(events, null);
                _connectivityManager.registerDefaultNetworkCallback(_networkCallback, _handler);
            }
            else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                _networkCallback = new NetworkCallbackImpl(events, _handler);
                _connectivityManager.registerDefaultNetworkCallback(_networkCallback);
            }
            else {
                _networkChangeReceiver = new NetworkChangeReceiver(events);
                IntentFilter filter = new IntentFilter(ConnectivityManager.CONNECTIVITY_ACTION);
                _context.registerReceiver(_networkChangeReceiver, filter);
            }
        }
        catch (RuntimeException ignored) { }
    }

    @Override
    public void onCancel(Object arguments) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            _connectivityManager.unregisterNetworkCallback(_networkCallback);
        }
        else {
            _context.unregisterReceiver(_networkChangeReceiver);
        }
    }

    private class NetworkCallbackImpl extends ConnectivityManager.NetworkCallback
    {
        protected final EventChannel.EventSink    _eventSink;
        protected final Handler                   _handler;

        public NetworkCallbackImpl(EventChannel.EventSink eventSink, Handler handler)
        {
            _eventSink = eventSink;
            _handler = handler;
        }

        protected void postEvent(Map<String, Object> map)
        {
            if (_handler != null) {
                _handler.post(() -> _eventSink.success(map));
            }
            else {
                _eventSink.success(map);
            }
        }

        @Override
        public void onCapabilitiesChanged(@NonNull Network network, @NonNull NetworkCapabilities networkCapabilities) {
            Map<String, Object> map = NetworkUtils.getNetworkCapabilitiesInformation(_context, networkCapabilities);

            if (Objects.equals(map.get(NetworkUtils.KEY_NETWORK_TYPE), NetworkUtils.NETWORK_TYPE_CELLULAR)) {
                TelephonyManager manager = (TelephonyManager) _context.getSystemService(Context.TELEPHONY_SERVICE);

                if (_phoneStateListener == null) {
                    _phoneStateListener = new PhoneStateListenerImpl(_eventSink);
                    //noinspection deprecation
                    manager.listen(_phoneStateListener, PhoneStateListener.LISTEN_DATA_CONNECTION_STATE);
                }
            }

            postEvent(Map.of(
                    "name", "CAPABILITIES_CHANGED",
                    "arguments", map
            ));
        }

        @Override
        public void onLost(@NonNull Network network) {
            if (_phoneStateListener != null) {
                TelephonyManager manager = (TelephonyManager) _context.getSystemService(Context.TELEPHONY_SERVICE);
                //noinspection deprecation
                manager.listen(_phoneStateListener, PhoneStateListener.LISTEN_NONE);
                _phoneStateListener = null;
            }

            postEvent(Map.of("name", "NETWORK_UNAVAILABLE"));
        }
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private class NetworkCallbackImplApi31 extends NetworkCallbackImpl
    {
        private TelephonyCallbackImpl _telephonyCallback;

        public NetworkCallbackImplApi31(EventChannel.EventSink eventSink, Handler handler)
        {
            super(eventSink, handler);
        }

        @Override
        public void onCapabilitiesChanged(@NonNull Network network, @NonNull NetworkCapabilities networkCapabilities) {
            Map<String, Object> map = NetworkUtils.getNetworkCapabilitiesInformation(_context, networkCapabilities);

            if (Objects.equals(map.get(NetworkUtils.KEY_NETWORK_TYPE), NetworkUtils.NETWORK_TYPE_CELLULAR)) {
                TelephonyManager manager = (TelephonyManager) _context.getSystemService(Context.TELEPHONY_SERVICE);

                if (_telephonyCallback == null) {
                    _telephonyCallback = new TelephonyCallbackImpl(_eventSink);
                    manager.registerTelephonyCallback(_context.getMainExecutor(), _telephonyCallback);
                }
            }

            postEvent(Map.of(
                    "name", "CAPABILITIES_CHANGED",
                    "arguments", map
            ));
        }

        @Override
        public void onLost(@NonNull Network network) {
            if (_telephonyCallback != null) {
                TelephonyManager manager = (TelephonyManager) _context.getSystemService(Context.TELEPHONY_SERVICE);
                manager.unregisterTelephonyCallback(_telephonyCallback);
                _telephonyCallback = null;
            }

            postEvent(Map.of("name", "NETWORK_UNAVAILABLE"));
        }
    }
}


