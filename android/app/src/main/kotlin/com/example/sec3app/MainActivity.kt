package com.example.sec3app

import android.content.pm.PackageManager
import android.content.pm.ApplicationInfo
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "permission_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getInstalledApps") {
                val apps = getInstalledApps()
                result.success(apps)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getInstalledApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        val appList = mutableListOf<Map<String, Any?>>()

        for (packageInfo in packages) {
            val permissions = mutableListOf<String>()
            try {
                val packagePermissions = pm.getPackageInfo(packageInfo.packageName, PackageManager.GET_PERMISSIONS).requestedPermissions
                if (packagePermissions != null) {
                    permissions.addAll(packagePermissions)
                }
            } catch (e: PackageManager.NameNotFoundException) {

            }

            val isSystemApp = (packageInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0

            val installer = try {
                pm.getInstallSourceInfo(packageInfo.packageName).installingPackageName ?: ""
            } catch (e: Exception) {
                ""
            }

            val appInfo = mapOf(
                "packageName" to packageInfo.packageName,
                "appName" to pm.getApplicationLabel(packageInfo).toString(),
                "isSystemApp" to isSystemApp,
                "permissions" to permissions,
                "installer" to installer
            )
            appList.add(appInfo)
        }
        return appList
    }
}
