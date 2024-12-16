import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:stripe_sub_flutter/homepage.dart';

void main() {
  Stripe.publishableKey =
      "pk_test_51QVWQ8IcY2LL5iPDixQuibfMKrhxdAYZYsrUTnXu4KHLjaNn1yUeustueJGWmB24KUBl3hmbrfaUevJZpwp8IcM1006LJ9XKPI";
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Homepage(),
    );
  }
}
