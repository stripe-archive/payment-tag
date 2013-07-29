#= require_self
#= require ./view

$ = @jQuery or @Zepto

throw('jQuery/Zepto required') unless $

class @PaymentTag
  @replaceTags: (element = document.body) ->
    $('payment, .payment-tag', element).each (i, tag) =>
      new this(el: tag).render()

  defaults:
    tokenName: 'stripeToken'
    token: true
    cvc: true
    address: false
    name: false

  constructor: (options = {}) ->
    @$el = options.el or '<payment />'
    @$el = $(@$el)

    options.key     or= @$el.attr('key') or @$el.attr('data-key')
    options.cvc     ?= not (@$el.attr('nocvc')? or @$el.attr('data-nocvc')?)
    options.token   ?= not (@$el.attr('notoken')? or @$el.attr('data-notoken')?)
    options.address ?= @$el.attr('address')? or @$el.attr('data-address')?
    options.name    ?= @$el.attr('name')? or @$el.attr('data-name')?
    options.form    or= @$el.parents('form')
    @options        = $.extend({}, @defaults, options)

    @setKey(@options.key) if @options.key
    @setForm(@options.form)

    # Restrictions
    @$el.on('keypress', '.number input', @restrictNumber)
    @$el.on('keypress', 'input[data-numeric]', @restrictNumeric)

    # Formatting
    @$el.on('keypress', '.number input', @formatNumber)
    @$el.on('keydown', '.number input', @formatBackNumber)
    @$el.on('keyup', '.number input', @changeCardType)

  render: ->
    @$el.html(@constructor.view(this))

    @$name        = @$('.name input')
    @$number      = @$('.number input')
    @$cvc         = @$('.cvc input')
    @$expiryMonth = @$('.expiry input.expiryMonth')
    @$expiryYear  = @$('.expiry input.expiryYear')
    @$message     = @$('.message')

    @trigger('ready')
    this

  renderToken: (token) ->
    @$token = $('<input type="hidden">')
    @$token.attr('name', @options.tokenName)
    @$token.val(token)
    @$el.html(@$token)

  setForm: ($form) ->
    @$form = $($form)
    @$form.bind('submit.payment', @submit)

  setKey: (@key) ->
    Stripe.setPublishableKey(@key)

  validate: ->
    valid = true

    # Reset previous validation
    @$('input').removeClass('invalid')
    @$message.empty()

    # Validate all required inputs
    @$('input[required]').each (i, input) =>
      input = $(input)
      unless input.val()
        valid = false
        @handleError(code: 'required', input: input)

    # Validate card number
    unless Stripe.validateCardNumber(@$number.val())
      valid = false
      @handleError(code: 'invalid_number')

    # Validate card expiry
    expiry = @expiryVal()
    unless Stripe.validateExpiry(expiry.month, expiry.year)
      valid = false
      @handleError(code: 'expired_card')

    # Validate card CVC
    if @options.cvc and !Stripe.validateCVC(@$cvc.val())
      valid = false
      @handleError(code: 'invalid_cvc')

    # Select first invalid input
    unless valid
      @$('.invalid:input:first').select()

    valid

  createToken: (callback) ->
    complete = (status, response) =>
      if response.error
        callback(response.error)
      else
        callback(null, response)

    expiry = @expiryVal()

    values =
      number:    @$number.val(),
      cvc:       @$cvc.val() or null,
      exp_month: expiry.month,
      exp_year:  expiry.year

    if @options.name
      values.name = @$name.val()

    if @options.address
      $.extend(values, @addressVal())

    Stripe.createToken(values, complete)

  submit: (e) =>
    # Cancel default event
    e?.preventDefault()
    e?.stopImmediatePropagation()

    # Validate the form
    return unless @validate()

    # Prevent double submits
    return if @pending
    @pending = true

    # Disable form
    @disableInputs()
    @trigger('pending')
    @$el.addClass('pending')

    @createToken(@handleToken)

  # Private

  handleToken: (err, response) =>
    # Enable the form
    @enableInputs()
    @trigger('complete')
    @$el.removeClass('pending')
    @pending = false

    if err
      @handleError(err)

    else
      @trigger('success', response)
      @$el.addClass('success')

      # Add the hidden token
      if @options.token
        @renderToken(response.id)

      # Re-submit form
      @$form.unbind('submit.payment', @submit)
      @$form.submit()

  # Restrictions

  restrictNumber: (e) =>
    digit = String.fromCharCode(e.which)
    return unless /^\d+$/.test(digit)

    # If some text is selected
    return if @$number.prop('selectionStart')? and
      @$number.prop('selectionStart') isnt @$number.prop('selectionEnd')

    # If some text is selected in IE
    return if document.selection?.createRange?().text

    # Restrict number of digits
    value = @$number.val() + digit
    value = value.replace(/\D/g, '')

    if Stripe.cardType(value) is 'American Express'
      # Amex are 15 digits long
      value.length <= 15
    else
      # All other cards are 16 digits long
      value.length <= 16

  restrictNumeric: (e) =>
    # Key event is for a browser shortcut
    return true if e.metaKey

    # If keycode is a space
    return false if e.which is 32

    # If keycode is a special char (WebKit)
    return true if e.which is 0

    # If char is a special char (Firefox)
    return true if e.which < 33

    char = String.fromCharCode(e.which)

    # Char is a number or a space
    !!/[\d\s]/.test(char)

  # Formatting

  formatNumber: (e) =>
    # Only format if input is a number
    digit = String.fromCharCode(e.which)
    return unless /^\d+$/.test(digit)

    value  = @$number.val()
    type   = Stripe.cardType(value + digit)
    length = (value.replace(/\D/g, '') + digit).length

    if type is 'American Express'
      # Amex are 15 digits
      return if length >= 15
    else
      return if length >= 16

    # Return if focus isn't at the end of the text
    return if @$number.prop('selectionStart')? and
      @$number.prop('selectionStart') isnt value.length

    if type is 'American Express'
      # Amex cards are formatted differently
      re = /^(\d{4}|\d{4}\s\d{6})$/
    else
      re = /(?:^|\s)(\d{4})$/

    # If '4242' + 4
    if re.test(value)
      e.preventDefault()
      @$number.val(value + ' ' + digit)

    # If '424' + 2
    else if re.test(value + digit)
      e.preventDefault()
      @$number.val(value + digit + ' ')

  formatBackNumber: (e) =>
    value = @$number.val()

    return if e.meta

    # If we're backspacing, remove the trailing space
    if e.which is 8 and /\s\d?$/.test(value)
      e.preventDefault()
      @$number.val(value.replace(/\s\d?$/, ''))

  cardTypes:
    'Visa': 'visa'
    'American Express': 'amex'
    'MasterCard': 'mastercard'
    'Discover': 'discover'
    'Unknown': 'unknown'

  changeCardType: (e) =>
    type = Stripe.cardType(@$number.val())

    unless @$number.hasClass(type)
      @$number.removeClass(map) for name, map of @cardTypes
      @$number.addClass(@cardTypes[type])

  handleError: (err) ->
    @$message.text(err.message) if err.message

    switch err.code
      when 'required'
        @invalidInput(err.input)
      when 'card_declined'
        @invalidInput(@$number)
      when 'invalid_number', 'incorrect_number'
        @invalidInput(@$number)
      when 'invalid_expiry_month'
        @invalidInput(@$expiryMonth)
      when 'invalid_expiry_year', 'expired_card'
        @invalidInput(@$expiryYear)
      when 'invalid_cvc'
        @invalidInput(@$cvc)

    @trigger('error', err)
    console?.error('Stripe error:', err)

  invalidInput: (input) ->
    input.addClass('invalid')
    @trigger('invalid', [input.attr('name'), input])

  expiryVal: ->
    trim = (s) -> s.replace(/^\s+|\s+$/g, '')

    month = trim @$expiryMonth.val()
    year  = trim @$expiryYear.val()

    # Allow for year shortcut
    if year.length is 2
      prefix = (new Date).getFullYear()
      prefix = prefix.toString()[0..1]
      year   = prefix + year

    month: month
    year:  year

  addressVal: ->
    result = {}
    @$('.address input').each (i, elem) ->
      result[elem.name] = $(@).val()
    result

  enableInputs: ->
    $elements = @$el.add(@$form).find(':input')
    $elements.each ->
      $item = $(this)
      $elements.attr('disabled', $item.data('olddisabled') ? false)

  disableInputs: ->
    $elements = @$el.add(@$form).find(':input')
    $elements.each ->
      $item = $(this)
      $item.data('olddisabled', $item.attr('disabled'))
      $item.attr('disabled', true)

  trigger: (event, data...) ->
    @$el.trigger("#{event}.payment", data...)

  $: (sel) ->
    $(sel, @$el)

# So <payment> tags can be styled in IE
document.createElement('payment')

module?.exports = PaymentTag
global          = this

# Stripe.js loader

if global.Stripe
  $ -> PaymentTag.replaceTags?()

else
  # If Stripe.js isn't already present, then load it in
  script = document.createElement('script')

  script.onload = script.onreadystatechange = ->
    # Make sure we only invoke callback once,
    # when Stripe.js is ready
    return unless global.Stripe
    return if script.done
    script.done = true

    PaymentTag.replaceTags?()

  script.src = 'https://js.stripe.com/v1/'

  $ ->
    # Insert after the first script tag, as we know at least
    # one script tag is going to be present on the page
    sibling = document.getElementsByTagName('script')[0]
    sibling?.parentNode.insertBefore(script, sibling)