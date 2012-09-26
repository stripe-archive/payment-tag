zombie = require 'zombie'
path   = require 'path'
vows   = require 'vows'
assert = require 'assert'

browser = (callback) ->
  zombie.visit "file://#{__dirname}/index.html", (err, browser) =>
    throw err if err

    browser.window.console.error = ->

    browser.window.Stripe.createToken = (values, callback) ->
      callback(200, id: 'token123')

    browser.payment = browser.window.jQuery('payment')

    (callback or @callback).call(this, null, browser)
  undefined

browserContext = (test) ->
  context = {}
  context.topic = browser
  context['browser'] = test
  context

vows.describe('PaymentTag').addBatch(
  'should be present': browserContext (browser) ->
    assert browser.window.PaymentTag?

  'should add inputs to payment': browserContext (browser) ->
    assert.equal browser.payment.find('input').length, 4

  'should add token input to payment on submit': browserContext (browser) ->
    browser.payment.find('.number input').val('4242424242424242')
    browser.payment.find('input.expiryMonth').val('05')
    browser.payment.find('input.expiryYear').val('2040')
    browser.payment.find('.cvc input').val('123')

    form = browser.payment.parents('form')
    form.submit()
    assert.equal form.find('input[name=stripeToken]').val(), 'token123'

  'should call Stripe.createToken with correct arguments':
    topic: ->
      browser (err, browser) =>
        browser.window.Stripe.createToken = (values, _) =>
          @callback(null, values)

        browser.payment.find('.number input').val('4242424242424242')
        browser.payment.find('input.expiryMonth').val('05')
        browser.payment.find('input.expiryYear').val('18')
        browser.payment.find('.cvc input').val('123')

        form = browser.payment.parents('form')
        form.submit()

    'number': (values) ->
      assert.equal values.number, '4242424242424242'

    'expiry': (values) ->
      assert.equal values.exp_month, '05'
      assert.equal values.exp_year, '2018'

    'cvc': (values) ->
      assert.equal values.cvc, '123'

  'should disable inputs on submit': browserContext (browser) ->
    browser.window.Stripe.createToken = ->

    browser.payment.find('.number input').val('4242424242424242')
    browser.payment.find('input.expiryMonth').val('05')
    browser.payment.find('input.expiryYear').val('2040')
    browser.payment.find('.cvc input').val('123')

    form = browser.payment.parents('form')
    form.submit()
    assert.equal form.find(':input:disabled').length, 5

  'should validate CC number':
    topic: browser

    'presence': (browser) ->
      browser.payment.find('.number input').val('4242424242424243')

      form = browser.payment.parents('form')
      form.submit()
      assert browser.payment.find('.number input').hasClass('invalid')

    'luhn': (browser) ->
      browser.payment.find('.number input').val('4242424242424243')

      form = browser.payment.parents('form')
      form.submit()
      assert browser.payment.find('.number input').hasClass('invalid')

    'valid': (browser) ->
      browser.payment.find('.number input').val('4242424242424242')

      form = browser.payment.parents('form')
      form.submit()
      assert not browser.payment.find('.number').hasClass('invalid')

  'should validate expiry':
    topic: browser

    'presence': (browser) ->
      browser.payment.find('.number input').val('ddd')

      form = browser.payment.parents('form')
      form.submit()
      assert browser.payment.find('.number input').hasClass('invalid')

    'numbers': (browser) ->
      browser.payment.find('input.expiryMonth').val('ddd')

      form = browser.payment.parents('form')
      form.submit()
      assert browser.payment.find('.number input').hasClass('invalid')

    'expiry': (browser) ->
      browser.payment.find('input.expiryMonth').val('05')
      browser.payment.find('input.expiryYear').val('2001')

      form = browser.payment.parents('form')
      form.submit()
      assert browser.payment.find('.expiry input.expiryYear').hasClass('invalid')

    'valid': (browser) ->
      browser.payment.find('input.expiryMonth').val('05')
      browser.payment.find('input.expiryYear').val('2040')

      form = browser.payment.parents('form')
      form.submit()
      assert not browser.payment.find('.expiry').hasClass('invalid')

  'should validate cvc':
    topic: browser

    'presence': (browser) ->
      browser.payment.find('.cvc input').val('')

      form = browser.payment.parents('form')
      form.submit()
      assert browser.payment.find('.cvc input').hasClass('invalid')

    'length': (browser) ->
      browser.payment.find('.cvc input').val('919812')

      form = browser.payment.parents('form')
      form.submit()
      assert browser.payment.find('.cvc input').hasClass('invalid')

    'valid': (browser) ->
      browser.payment.find('.cvc input').val('123')

      form = browser.payment.parents('form')
      form.submit()
      assert not browser.payment.find('.cvc input').hasClass('invalid')

).run()