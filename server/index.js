const express = require("express");
const stripe = require("stripe")("sk_test_51QVWQ8IcY2LL5iPD7ROuiG6nBwAGVRKWydIpyruuCLEq22yEE1PbwWK3ta9be5Y5eZwdVnXwbCRh8iKpgC5HxACa00q3o8JSXC");

const cors = require("cors");


const app = express();
app.use(express.static('public'));
app.use(express.urlencoded({ extended: true }));
app.use(express.json());
app.use(cors());

const YOUR_DOMAIN = 'http://10.0.2.2:4242';

app.post("/create-customer", async (req, res) => {
  let { name, email } = req.body;


  const customer = await stripe.customers.create({
    name: name,
    email: email,
  });

  const ephemeralKey = await stripe.ephemeralKeys.create(
    { customer: customer.id },
    { apiVersion: '2024-11-20.acacia' }
  );


  const setupIntent = await stripe.setupIntents.create({
    customer: customer.id,
    automatic_payment_methods: {
      enabled: true,
    }
  });



  res.json({
    clientSecret: setupIntent.client_secret,
    ephemeralKey: ephemeralKey.secret,
    customer: customer.id,
  });
})


app.post("/create-subscribtion", async (req, res) => {

  const { customerId, paymentMethodId } = req.body;

    // Récupérer le premier prix de l'abonnement
    const prices = await stripe.prices.list({
      limit: 1,
      active: true
    });

    await stripe.paymentMethods.attach(paymentMethodId, { customer: customerId });

    // Définir le moyen de paiement par défaut pour les factures
    await stripe.customers.update(customerId, {
      invoice_settings: {
        default_payment_method: paymentMethodId,
      },
    });

  const subscription = await stripe.subscriptions.create({
    customer: customerId,
    items: [{ price: prices.data[0].id }],
    payment_behavior: 'default_incomplete',
    expand: ['latest_invoice.payment_intent'],
    payment_settings: {
      save_default_payment_method: 'on_subscription'
    },
  });

  const invoiceId = subscription.latest_invoice.id;
  const paidInvoice = await stripe.invoices.pay(invoiceId);


  res.send({
    subscriptionId: subscription.id,
    clientSecret: subscription.latest_invoice.payment_intent.client_secret,
  });
})


app.post(
  '/webhook',
  express.raw({ type: 'application/json' }),
  async (request, response) => {
    let event = request.body;
    // Replace this endpoint secret with your endpoint's unique secret
    // If you are testing with the CLI, find the secret by running 'stripe listen'
    // If you are using an endpoint defined with the API or dashboard, look in your webhook settings
    // at https://dashboard.stripe.com/webhooks
    const endpointSecret = 'whsec_12345';
    // Only verify the event if you have an endpoint secret defined.
    // Otherwise use the basic event deserialized with JSON.parse
    if (endpointSecret) {
      // Get the signature sent by Stripe
      const signature = request.headers['stripe-signature'];
      try {
        event = stripe.webhooks.constructEvent(
          request.body,
          signature,
          endpointSecret
        );
      } catch (err) {
        console.log(`⚠️  Webhook signature verification failed.`, err.message);
        return response.sendStatus(400);
      }
    }
    let subscription;
    let status;
    // Handle the event
    switch (event.type) {
      case 'payment_intent.succeeded':
        const paymentIntent = event.data.object;

        // Rechercher et mettre à jour l'abonnement associé
        if (paymentIntent.metadata.intent_type === 'subscription_setup') {
          try {
            // Rechercher l'abonnement avec ce PaymentIntent
            const subscriptions = await stripe.subscriptions.list({
              customer: paymentIntent.customer,
              metadata: {
                payment_intent_id: paymentIntent.id
              }
            });

            if (subscriptions.data.length > 0) {
              const subscription = subscriptions.data[0];

              // Mettre à jour l'abonnement si nécessaire
              await stripe.subscriptions.update(subscription.id, {
                default_payment_method: paymentIntent.payment_method
              });

              console.log('Subscription updated with payment method');
            }
          } catch (error) {
            console.error('Error updating subscription:', error);
          }
        }
      case 'customer.subscription.created':
        // L'abonnement a été créé
        console.log('Nouvel abonnement créé');
        break;

      case 'invoice.payment_succeeded':
        // Premier paiement réussi
        const invoice = event.data.object;
        console.log('Paiement initial réussi');
        break;

      case 'customer.subscription.updated':
        // Changements dans l'abonnement
        console.log('Mise à jour de l\'abonnement');
        break;

      case 'invoice.payment_failed':
        // Échec de paiement
        console.log('Échec du paiement');
        // Logique de gestion des échecs de paiement
        break;
      case 'customer.subscription.updated':
        console.log('Mise à jour de l\'abonnement pour :', event.data.object);
        break;
      case 'customer.subscription.trial_will_end':
        subscription = event.data.object;
        status = subscription.status;
        console.log(`Subscription status is ${status}.`);
        // Then define and call a method to handle the subscription trial ending.
        // handleSubscriptionTrialEnding(subscription);
        break;
      case 'customer.subscription.deleted':
        subscription = event.data.object;
        status = subscription.status;
        console.log(`Subscription status is ${status}.`);
        // Then define and call a method to handle the subscription deleted.
        // handleSubscriptionDeleted(subscriptionDeleted);
        break;
      case 'customer.subscription.created':
        subscription = event.data.object;
        status = subscription.status;
        console.log(`Subscription status is ${status}.`);
        // Then define and call a method to handle the subscription created.
        // handleSubscriptionCreated(subscription);
        break;
      case 'customer.subscription.updated':
        subscription = event.data.object;
        status = subscription.status;
        console.log(`Subscription status is ${status}.`);
        // Then define and call a method to handle the subscription update.
        // handleSubscriptionUpdated(subscription);
        break;
      case 'entitlements.active_entitlement_summary.updated':
        subscription = event.data.object;
        console.log(`Active entitlement summary updated for ${subscription}.`);
        // Then define and call a method to handle active entitlement summary updated
        // handleEntitlementUpdated(subscription);
        break;
      default:
        // Unexpected event type
        console.log(`Unhandled event type ${event.type}.`);
    }
    // Return a 200 response to acknowledge receipt of the event
    response.send();
  }
);

app.listen(4242, '0.0.0.0', () => console.log('Running on port 4242'));