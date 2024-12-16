import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;

class Payment extends StatefulWidget {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();

  Payment({super.key});

  @override
  State<StatefulWidget> createState() => _PaymentState();
}

class _PaymentState extends State<Payment> {
 var data;

  Future<void> showPaymentSheet() async {
    try {
      var rep = await Stripe.instance.presentPaymentSheet();
      print(rep);
    } on StripeException catch (error) {
      print(error);

      showDialog(
          context: context,
          builder: (c) => const AlertDialog(
                content: Text("Cancelled"),
              ));
    } catch (error, s) {
      if (kDebugMode) {
        print(s);
      }
      print(error.toString());
    }
  }

  Future<void> handlePayment(String fullName, String email) async {
  try {
    // Call backend to create customer
    var responseFromBackend = await http.post(
      Uri.parse("http://10.0.2.2:4242/create-customer"),
      body: {"name": fullName, "email": email},
      headers: {"Content-Type": "application/x-www-form-urlencoded"}
    );

    Map<String, dynamic> data = jsonDecode(responseFromBackend.body);

    // Initialize payment sheet
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        customFlow: false,
        allowsDelayedPaymentMethods: true,
        setupIntentClientSecret: data["clientSecret"],
        customerId: data["customer"],
        customerEphemeralKeySecret: data["ephemeralKey"],
        merchantDisplayName: 'Minkey',
        style: ThemeMode.dark,
        googlePay: const PaymentSheetGooglePay(
          merchantCountryCode: 'FR',
          currencyCode: 'EUR',
          testEnv: true,
        ),
      ),
    );

    // Présentation de la feuille de paiement
    await Stripe.instance.presentPaymentSheet();

    final paymentIntent = await Stripe.instance.retrieveSetupIntent(data["clientSecret"]);
    final paymentMethodId = paymentIntent.paymentMethodId;

    var responseFromBackendSub = await http.post(
      Uri.parse("http://10.0.2.2:4242/create-subscribtion"),
      body: {"customerId": data["customer"], "paymentMethodId": paymentMethodId},
      headers: {"Content-Type": "application/x-www-form-urlencoded"}
    );

     Map<String, dynamic> dataSub = jsonDecode(responseFromBackendSub.body);
    if (dataSub["subscriptionId"] != null) {
          // Gérer le succès du paiement
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Souscription réussi !')),
      );

    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Souscription erreur !')),
      );
    }


  } on StripeException catch (error) {
    // Gérer les erreurs Stripe spécifiques
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur Stripe : ${error.error.message}')),
    );
  } catch (error) {
    // Gérer les autres erreurs
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur : $error')),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Formulaire d\'inscription'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: widget._formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Inscription au service',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: widget._fullNameController,
                decoration: InputDecoration(
                  labelText: 'Nom complet',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer votre nom complet';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: widget._emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer votre email';
                  }
                  if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                    return 'Veuillez entrer un email valide';
                  }
                  return null;
                },
              ),
              SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    if (widget._formKey.currentState?.validate() ?? false) {
                      final fullName = widget._fullNameController.text;
                      final email = widget._emailController.text;
                      // Actions après validation du formulaire
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text('Nom: $fullName\nEmail: $email')),
                      );
                      handlePayment(fullName, email);
                    }
                  },
                  child: Text('Paiement'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
