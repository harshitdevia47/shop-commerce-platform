# Razorpay Checkout (from Razorpay's Android integration guide)
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** {*;}
-optimizations !method/inlining/
-keepclasseswithmembers class * {
  public void onPayment*(...);
}

# Firebase Messaging / Play services keep their own consumer rules; nothing extra needed.
# Missing optional classes referenced by dependencies (Play Core deferred components).
-dontwarn com.google.android.play.core.**
