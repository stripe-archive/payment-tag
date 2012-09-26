# Stripe Payment Tag

The Payment Tag makes it even easier to integrate [Stripe](http://stripe.com) directly into your website.

It'll take care of building credit card inputs, validation, error handling, and sending the encrypted card number securely to Stripe.

## Usage

To use the Payment Tag, first <a href="https://github.com/stripe/payment-tag/zipball/v1.0.0">download the required JavaScript</a>. Then, include the library in your HTML's `<head>`. The CSS is optional&mdash;feel free to override it in your own pages. The Payment Tag also requires <a href="http://jquery.com/">jQuery</a>, which you'll need to include if you haven't already done so.

Then, just pop the `<payment>` tag in a form. You'll need to set the `data-key` attribute to your <em>publishable key</em>, which you can get from <a href="https://manage.stripe.com/#account/apikeys">your account settings</a>.

    <script src="https://ajax.googleapis.com/ajax/libs/jquery/1.7.2/jquery.js"></script>
    <script src="lib/tag.dev.js"></script>

    <form action="/customers" method="post">
      <payment key="your-publishable-key"></payment>
      <input type="submit" value="Submit">
    </form>

That's all there is to it. When the page loads, the `<payment>` tag will be turned into a bunch of inputs ready to receive credit card data. Remember to replace your test publishable key with your live publishable key before you deploy in production.

When the form is submitted, the user's credit card data will be sent over SSL to Stripe, the `<payment>` element will be replaced with a hidden input called `stripeToken`, and finally the form will be submitted to your servers. On your server, you can then use the `stripeToken` parameter to <a href="https://stripe.com/docs/tutorials/charges">charge the card</a>.
The enclosing form can, of course, contain other `<input>`s. You can embed it on any regular form on your site.

## Example

Try filling out [the example](http://stripe.github.com/payment-tag/test/index.html) with Stripe's test card number, `4242 4242 4242 4242`, any three digit CVC code, and a valid expiry date.

## Security

You should make sure all payment forms are served over **SSL**. Stripe makes sure that a customer's credit-card data never touches your server, greatly simplifying your security precautions.

## Styling

Default styles are included in `assets/styles.css`. When a field fails validation, a class of `invalid` will be added to its `<label>`.

## Events

There are a number of events the `<payment>` tag triggers during its lifetime. They're all name-spaced by `payment`, and you can bind to them (using jQuery) like this:

    $('payment').bind('success.payment', function () {
      // ...
    });

The available events are:

* *invalid* - a field is invalid
* *pending* - request to Stripe has been made
* *complete* - request to Stripe has completed
* *success* - request to Stripe was successful
* *error* - request to Stripe failed