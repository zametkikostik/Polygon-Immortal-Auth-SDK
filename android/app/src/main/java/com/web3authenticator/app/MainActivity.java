package com.polyvault.app;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.view.View;
import android.view.WindowManager;
import android.webkit.CookieManager;
import android.webkit.GeolocationPermissions;
import android.webkit.JavascriptInterface;
import android.webkit.PermissionRequest;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.appcompat.app.AppCompatActivity;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import java.io.File;

public class MainActivity extends AppCompatActivity {

    private WebView webView;
    private static final int FILE_CHOOSER_REQUEST = 1;
    private static final int CAMERA_PERMISSION_REQUEST = 2;
    private ValueCallback<Uri[]> fileUploadCallback;
    private static final String CAMERA_PERMISSION = Manifest.permission.CAMERA;
    private static final String AUDIO_PERMISSION = Manifest.permission.RECORD_AUDIO;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        
        // Устанавливаем полноэкранный режим
        getWindow().setFlags(
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
        );
        
        // Скрываем статус бар для полного погружения
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            getWindow().setStatusBarColor(android.graphics.Color.parseColor("#0a0a0f"));
        }
        
        webView = new WebView(this);
        setContentView(webView);
        
        setupWebView();
        loadLocalHtml();
        
        // Запрашиваем разрешения на камеру и микрофон
        requestPermissions();
    }

    @SuppressLint("SetJavaScriptEnabled")
    private void setupWebView() {
        WebSettings webSettings = webView.getSettings();
        
        // Включаем JavaScript
        webSettings.setJavaScriptEnabled(true);
        webSettings.setDomStorageEnabled(true);
        webSettings.setDatabaseEnabled(true);
        webSettings.setAllowFileAccess(true);
        webSettings.setAllowContentAccess(true);
        
        // Включаем localStorage
        webSettings.setDomStorageEnabled(true);
        webSettings.setJavaScriptCanOpenWindowsAutomatically(true);
        
        // Кэширование для офлайн работы
        webSettings.setCacheMode(WebSettings.LOAD_DEFAULT);
        
        // Zoom настройки
        webSettings.setSupportZoom(true);
        webSettings.setBuiltInZoomControls(true);
        webSettings.setDisplayZoomControls(false);
        
        // User Agent для лучшей совместимости
        webSettings.setUserAgentString(webSettings.getUserAgentString() + " PolyVault/1.0");
        
        // Медиа playback
        webSettings.setMediaPlaybackRequiresUserGesture(false);
        
        // Обработка ссылок внутри WebView
        webView.setWebViewClient(new WebViewClient());
        
        // Обработка разрешений и file chooser
        webView.setWebChromeClient(new WebChromeClient() {
            @Override
            public void onGeolocationPermissionsShowPrompt(
                String origin, 
                GeolocationPermissions.Callback callback
            ) {
                callback.invoke(origin, true, false);
            }
            
            @Override
            public void onPermissionRequest(PermissionRequest request) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    // Разрешаем камеру и аудио для WebRTC
                    request.grant(request.getResources());
                }
            }
            
            @Override
            public boolean onShowFileChooser(
                WebView webView,
                ValueCallback<Uri[]> filePathCallback,
                FileChooserParams fileChooserParams
            ) {
                fileUploadCallback = filePathCallback;
                openFilePicker();
                return true;
            }
        });
        
        // JavaScript интерфейс для взаимодействия с нативным кодом
        webView.addJavascriptInterface(new Object() {
            @JavascriptInterface
            public void showToast(String message) {
                runOnUiThread(() -> Toast.makeText(MainActivity.this, message, Toast.LENGTH_SHORT).show());
            }
            
            @JavascriptInterface
            public String getAppVersion() {
                return "1.0.0";
            }
            
            @JavascriptInterface
            public String getAppName() {
                return "PolyVault";
            }
        }, "AndroidInterface");
        
        // Очистка кэша при необходимости
        CookieManager.getInstance().setAcceptCookie(true);
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true);
        }
    }

    private void loadLocalHtml() {
        // Загружаем HTML файл из assets
        File htmlFile = new File(getFilesDir(), "index.html");
        
        // Копируем HTML файл в внутреннюю память если его нет
        if (!htmlFile.exists()) {
            try {
                java.io.InputStream inputStream = getAssets().open("index.html");
                java.io.OutputStream outputStream = new java.io.FileOutputStream(htmlFile);
                byte[] buffer = new byte[1024];
                int length;
                while ((length = inputStream.read(buffer)) > 0) {
                    outputStream.write(buffer, 0, length);
                }
                outputStream.flush();
                outputStream.close();
                inputStream.close();
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
        
        // Загружаем файл
        webView.loadUrl("file://" + htmlFile.getAbsolutePath());
    }

    private void openFilePicker() {
        Intent intent = new Intent(Intent.ACTION_GET_CONTENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        startActivityForResult(
            Intent.createChooser(intent, "Выберите файл"),
            FILE_CHOOSER_REQUEST
        );
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        
        if (requestCode == FILE_CHOOSER_REQUEST) {
            if (fileUploadCallback == null) return;
            
            Uri[] results = null;
            if (resultCode == Activity.RESULT_OK && data != null) {
                String dataString = data.getDataString();
                if (dataString != null) {
                    results = new Uri[]{Uri.parse(dataString)};
                }
            }
            
            fileUploadCallback.onReceiveValue(results);
            fileUploadCallback = null;
        }
    }

    private void requestPermissions() {
        if (ContextCompat.checkSelfPermission(this, CAMERA_PERMISSION)
                != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(
                this,
                new String[]{CAMERA_PERMISSION, AUDIO_PERMISSION},
                CAMERA_PERMISSION_REQUEST
            );
        }
    }

    @Override
    public void onRequestPermissionsResult(
        int requestCode,
        @NonNull String[] permissions,
        @NonNull int[] grantResults
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        
        if (requestCode == CAMERA_PERMISSION_REQUEST) {
            boolean cameraGranted = false;
            boolean audioGranted = false;
            
            for (int i = 0; i < permissions.length; i++) {
                if (permissions[i].equals(CAMERA_PERMISSION) && 
                    grantResults[i] == PackageManager.PERMISSION_GRANTED) {
                    cameraGranted = true;
                }
                if (permissions[i].equals(AUDIO_PERMISSION) && 
                    grantResults[i] == PackageManager.PERMISSION_GRANTED) {
                    audioGranted = true;
                }
            }
            
            if (cameraGranted) {
                Toast.makeText(this, "Камера разрешена", Toast.LENGTH_SHORT).show();
            } else {
                Toast.makeText(this, "Камера запрещена. Сканирование QR не будет работать.", Toast.LENGTH_LONG).show();
            }
        }
    }

    @Override
    public void onBackPressed() {
        if (webView.canGoBack()) {
            webView.goBack();
        } else {
            super.onBackPressed();
        }
    }

    @Override
    protected void onDestroy() {
        if (webView != null) {
            webView.destroy();
        }
        super.onDestroy();
    }
}
