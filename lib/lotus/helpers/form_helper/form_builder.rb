require 'lotus/helpers/form_helper/html_node'
require 'lotus/helpers/html_helper/html_builder'
require 'lotus/utils/string'

module Lotus
  module Helpers
    module FormHelper
      # FIXME Don't inherit from OpenStruct
      # TODO unify values with params
      require 'ostruct'
      class Values < OpenStruct
        GET_SEPARATOR = '.'.freeze

        def get(key)
          key, *keys = key.to_s.split(GET_SEPARATOR)
          result     = self[key]

          Array(keys).each do |k|
            break if result.nil?

            result = if result.respond_to?(k)
              result.public_send(k)
            else
              nil
            end
          end

          result
        end

        def update?
          to_h.keys.count > 0
        end
      end

      # Form builder
      #
      # @since x.x.x
      #
      # @see Lotus::Helpers::HtmlHelper::HtmlBuilder
      class FormBuilder < ::Lotus::Helpers::HtmlHelper::HtmlBuilder
        # Set of HTTP methods that are understood by web browsers
        #
        # @since x.x.x
        # @api private
        BROWSER_METHODS = ['GET', 'POST'].freeze

        # Checked attribute value
        #
        # @since x.x.x
        # @api private
        #
        # @see Lotus::Helpers::FormHelper::FormBuilder#radio_button
        CHECKED = 'checked'.freeze

        # Selected attribute value for option
        #
        # @since x.x.x
        # @api private
        #
        # @see Lotus::Helpers::FormHelper::FormBuilder#select
        SELECTED = 'selected'.freeze

        # Separator for accept attribute of file input
        #
        # @since x.x.x
        # @api private
        #
        # @see Lotus::Helpers::FormHelper::FormBuilder#file_input
        ACCEPT_SEPARATOR = ','.freeze

        # Replacement for input id interpolation
        #
        # @since x.x.x
        # @api private
        #
        # @see Lotus::Helpers::FormHelper::FormBuilder#_input_id
        INPUT_ID_REPLACEMENT = '-\k<token>'.freeze

        # Replacement for input value interpolation
        #
        # @since x.x.x
        # @api private
        #
        # @see Lotus::Helpers::FormHelper::FormBuilder#_value
        INPUT_VALUE_REPLACEMENT = '.\k<token>'.freeze

        # ENCTYPE_MULTIPART = 'multipart/form-data'.freeze

        self.html_node = ::Lotus::Helpers::FormHelper::HtmlNode

        # Instantiate a form builder
        #
        # @param name [Symbol] the toplevel name of the form, it's used to generate
        #   input names, ids, and to lookup params to fill values.
        # @param params [Lotus::Action::Params] the params of the request
        # @param values [Hash] A set of values
        # @param attributes [Hash] HTML attributes to pass to the form tag
        # @param blk [Proc] A block that describes the contents of the form
        #
        # @return [Lotus::Helpers::FormHelper::FormBuilder] the form builder
        #
        # @since x.x.x
        def initialize(name, params, values, attributes = {}, &blk)
          super()

          @name       = name
          @params     = params
          @values     = values
          @attributes = attributes
          @blk        = blk
        end

        # Resolves all the nodes and generates the markup
        #
        # @return [Lotus::Utils::Escape::SafeString] the output
        #
        # @since x.x.x
        # @api private
        #
        # @see Lotus::Helpers::HtmlHelper::HtmlBuilder#to_s
        # @see http://www.rubydoc.info/gems/lotus-utils/Lotus/Utils/Escape/SafeString
        def to_s
          if toplevel?
            _method_override!
            form(@blk, @attributes)
          end

          super
        end

        # Nested fields
        #
        # The inputs generated by the wrapped block will be prefixed with the given name
        # It supports infinite levels of nesting.
        #
        # @param name [Symbol] the nested name, it's used to generate input
        #   names, ids, and to lookup params to fill values.
        #
        # @since x.x.x
        #
        # @example Basic usage
        #   <%=
        #     form_for :delivery, routes.deliveries_path do
        #       text_field :customer_name
        #
        #       fields_for :address do
        #         text_field :street
        #       end
        #
        #       submit 'Create'
        #     end
        #   %>
        #
        #   Output:
        #     # <form action="/deliveries" id="delivery-form" method="POST">
        #     #   <input type="text" name="delivery[customer_name]" id="delivery-customer-name" value="">
        #     #   <input type="text" name="delivery[address][street]" id="delivery-address-street" value="">
        #     #
        #     #   <button type="submit">Create</button>
        #     # </form>
        #
        # @example Multiple levels of nesting
        #   <%=
        #     form_for :delivery, routes.deliveries_path do
        #       text_field :customer_name
        #
        #       fields_for :address do
        #         text_field :street
        #
        #         fields_for :location do
        #           text_field :city
        #           text_field :country
        #         end
        #       end
        #
        #       submit 'Create'
        #     end
        #   %>
        #
        #   Output:
        #     # <form action="/deliveries" id="delivery-form" method="POST">
        #     #   <input type="text" name="delivery[customer_name]" id="delivery-customer-name" value="">
        #     #   <input type="text" name="delivery[address][street]" id="delivery-address-street" value="">
        #     #   <input type="text" name="delivery[address][location][city]" id="delivery-address-location-city" value="">
        #     #   <input type="text" name="delivery[address][location][country]" id="delivery-address-location-country" value="">
        #     #
        #     #   <button type="submit">Create</button>
        #     # </form>
        def fields_for(name)
          current_name = @name
          @name        = _input_name(name)
          yield
        ensure
          @name = current_name
        end

        # Label tag
        #
        # The first param <tt>content</tt> can be a <tt>Symbol</tt> that represents
        # the target field (Eg. <tt>:extended_title</tt>), or a <tt>String</tt>
        # which is used as it is.
        #
        # @param content [Symbol,String] the field name or a content string
        # @param attributes [Hash] HTML attributes to pass to the label tag
        #
        # @since x.x.x
        #
        # @example Basic usage
        #   <%=
        #     # ...
        #     label :extended_title
        #   %>
        #
        #  # Output:
        #  #  <label for="book-extended-title">Extended Title</label>
        #
        # @example Custom content
        #   <%=
        #     # ...
        #     label 'Title', for: :extended_title
        #   %>
        #
        #  # Output:
        #  #  <label for="book-extended-title">Title</label>
        #
        # @example Nested fields usage
        #   <%=
        #     # ...
        #     fields_for :address do
        #       label :city
        #       text_field :city
        #     end
        #   %>
        #
        #  # Output:
        #  #  <label for="delivery-address-city">City</label>
        #  #  <input type="text" name="delivery[address][city] id="delivery-address-city" value="">
        def label(content, attributes = {})
          attributes = { for: _for(content, attributes.delete(:for)) }.merge(attributes)
          content    = Utils::String.new(content).titleize

          super(content, attributes)
        end

        # Color input
        #
        # @param name [Symbol] the input name
        # @param attributes [Hash] HTML attributes to pass to the input tag
        #
        # @since x.x.x
        #
        # @example Basic usage
        #   <%=
        #     # ...
        #     color_field :background
        #   %>
        #
        #   # Output:
        #   #  <input type="color" name="user[background]" id="user-background" value="">
        def color_field(name, attributes = {})
          input _attributes(:color, name, attributes)
        end

        # Date input
        #
        # @param name [Symbol] the input name
        # @param attributes [Hash] HTML attributes to pass to the input tag
        #
        # @since x.x.x
        #
        # @example Basic usage
        #   <%=
        #     # ...
        #     date_field :birth_date
        #   %>
        #
        #   # Output:
        #   #  <input type="date" name="user[birth_date]" id="user-birth-date" value="">
        def date_field(name, attributes = {})
          input _attributes(:date, name, attributes)
        end

        # Datetime input
        #
        # @param name [Symbol] the input name
        # @param attributes [Hash] HTML attributes to pass to the input tag
        #
        # @since x.x.x
        #
        # @example Basic usage
        #   <%=
        #     # ...
        #     datetime_field :delivered_at
        #   %>
        #
        #   # Output:
        #   #  <input type="datetime" name="delivery[delivered_at]" id="delivery-delivered-at" value="">
        def datetime_field(name, attributes = {})
          input _attributes(:datetime, name, attributes)
        end

        # Datetime Local input
        #
        # @param name [Symbol] the input name
        # @param attributes [Hash] HTML attributes to pass to the input tag
        #
        # @since x.x.x
        #
        # @example Basic usage
        #   <%=
        #     # ...
        #     datetime_local_field :delivered_at
        #   %>
        #
        #   # Output:
        #   #  <input type="datetime-local" name="delivery[delivered_at]" id="delivery-delivered-at" value="">
        def datetime_local_field(name, attributes = {})
          input _attributes(:'datetime-local', name, attributes)
        end

        # Email input
        #
        # @param name [Symbol] the input name
        # @param attributes [Hash] HTML attributes to pass to the input tag
        #
        # @since x.x.x
        #
        # @example Basic usage
        #   <%=
        #     # ...
        #     email_field :email
        #   %>
        #
        #   # Output:
        #   #  <input type="email" name="user[email]" id="user-email" value="">
        def email_field(name, attributes = {})
          input _attributes(:email, name, attributes)
        end

        # Hidden input
        #
        # @param name [Symbol] the input name
        # @param attributes [Hash] HTML attributes to pass to the input tag
        #
        # @since x.x.x
        #
        # @example Basic usage
        #   <%=
        #     # ...
        #     hidden_field :customer_id
        #   %>
        #
        #   # Output:
        #   #  <input type="hidden" name="delivery[customer_id]" id="delivery-customer-id" value="">
        def hidden_field(name, attributes = {})
          input _attributes(:hidden, name, attributes)
        end

        # File input
        #
        # PLEASE REMEMBER TO ADD <tt>enctype: 'multipart/form-data'</tt> ATTRIBUTE TO THE FORM
        #
        # @param name [Symbol] the input name
        # @param attributes [Hash] HTML attributes to pass to the input tag
        # @option attributes [String,Array] :accept Optional set of accepted MIME Types
        #
        # @since x.x.x
        #
        # @example Basic usage
        #   <%=
        #     # ...
        #     file_field :avatar
        #   %>
        #
        #   # Output:
        #   #  <input type="file" name="user[avatar]" id="user-avatar">
        #
        # @example Accepted mime types
        #   <%=
        #     # ...
        #     file_field :resume, accept: 'application/pdf,application/ms-word'
        #   %>
        #
        #   # Output:
        #   #  <input type="file" name="user[resume]" id="user-resume" accept="application/pdf,application/ms-word">
        #
        # @example Accepted mime types (as array)
        #   <%=
        #     # ...
        #     file_field :resume, accept: ['application/pdf', 'application/ms-word']
        #   %>
        #
        #   # Output:
        #   #  <input type="file" name="user[resume]" id="user-resume" accept="application/pdf,application/ms-word">
        def file_field(name, attributes = {})
          attributes[:accept] = Array(attributes[:accept]).join(ACCEPT_SEPARATOR) if attributes.key?(:accept)
          attributes = { type: :file, name: _input_name(name), id: _input_id(name) }.merge(attributes)

          input(attributes)
        end

        # Text input
        #
        # @param name [Symbol] the input name
        # @param attributes [Hash] HTML attributes to pass to the input tag
        #
        # @since x.x.x
        #
        # @example Basic usage
        #   <%=
        #     # ...
        #     text_field :first_name
        #   %>
        #
        #   # Output:
        #   #  <input type="text" name="user[first_name]" id="user-first-name" value="">
        def text_field(name, attributes = {})
          input _attributes(:text, name, attributes)
        end
        alias_method :input_text, :text_field

        # Radio input
        #
        # If request params have a value that corresponds to the given value,
        # it automatically sets the <tt>checked</tt> attribute.
        # This Lotus::Controller integration happens without any developer intervention.
        #
        # @param name [Symbol] the input name
        # @param value [String] the input value
        # @param attributes [Hash] HTML attributes to pass to the input tag
        #
        # @since x.x.x
        #
        # @example Basic usage
        #   <%=
        #     # ...
        #     radio_button :category, 'Fiction'
        #     radio_button :category, 'Non-Fiction'
        #   %>
        #
        #   # Output:
        #   #  <input type="radio" name="book[category]" value="Fiction">
        #   #  <input type="radio" name="book[category]" value="Non-Fiction">
        #
        # @example Automatic checked value
        #   # Given the following params:
        #   #
        #   # book: {
        #   #   category: 'Non-Fiction'
        #   # }
        #
        #   <%=
        #     # ...
        #     radio_button :category, 'Fiction'
        #     radio_button :category, 'Non-Fiction'
        #   %>
        #
        #   # Output:
        #   #  <input type="radio" name="book[category]" value="Fiction">
        #   #  <input type="radio" name="book[category]" value="Non-Fiction" checked="checked">
        def radio_button(name, value, attributes = {})
          attributes = { type: :radio, name: _input_name(name), value: value }.merge(attributes)
          attributes[:checked] = CHECKED if _value(name) == value
          input(attributes)
        end

        # Select input
        #
        # @param name [Symbol] the input name
        # @param values [Hash] a Hash to generate <tt><option></tt> tags.
        #   Keys correspond to <tt>value</tt> and values correspond to the content.
        # @param attributes [Hash] HTML attributes to pass to the input tag
        #
        # If request params have a value that corresponds to one of the given values,
        # it automatically sets the <tt>selected</tt> attribute on the <tt><option></tt> tag.
        # This Lotus::Controller integration happens without any developer intervention.
        #
        # @since x.x.x
        #
        # @example Basic usage
        #   <%=
        #     # ...
        #     values = Hash['it' => 'Italy', 'us' => 'United States']
        #     select :stores, values
        #   %>
        #
        #   # Output:
        #   #  <select name="book[store]" id="book-store">
        #   #    <option value="it">Italy</option>
        #   #    <option value="us">United States</option>
        #   #  </select>
        #
        # @example Automatic selected option
        #   # Given the following params:
        #   #
        #   # book: {
        #   #   store: 'it'
        #   # }
        #
        #   <%=
        #     # ...
        #     values = Hash['it' => 'Italy', 'us' => 'United States']
        #     select :stores, values
        #   %>
        #
        #   # Output:
        #   #  <select name="book[store]" id="book-store">
        #   #    <option value="it" selected="selected">Italy</option>
        #   #    <option value="us">United States</option>
        #   #  </select>
        def select(name, values, attributes = {})
          options    = attributes.delete(:options) || {}
          attributes = { name: _input_name(name), id: _input_id(name) }.merge(attributes)

          super(attributes) do
            values.each do |value, content|
              if _value(name) == value
                option(content, {value: value, selected: SELECTED}.merge(options))
              else
                option(content, {value: value}.merge(options))
              end
            end
          end
        end

        # Submit button
        #
        # @param content [String] The content
        # @param attributes [Hash] HTML attributes to pass to the button tag
        #
        # @since x.x.x
        #
        # @example Basic usage
        #   <%=
        #     # ...
        #     submit 'Create'
        #   %>
        #
        #   # Output:
        #   #  <button type="submit">Create</button>
        def submit(content, attributes = {})
          attributes = { type: :submit }.merge(attributes)
          button(content, attributes)
        end

        protected
        def update?
          @values.update?
        end

        # A set of options to pass to the sub form helpers.
        #
        # @api private
        # @since x.x.x
        def options
          Hash[form_name: @name, params: @params, values: @values, verb: @verb]
        end

        private
        # Check the current builder is top-level
        #
        # @api private
        # @since x.x.x
        def toplevel?
          @attributes.any?
        end

        # Prepare for method override
        #
        # @api private
        # @since x.x.x
        def _method_override!
          verb = (@attributes.fetch(:method) { DEFAULT_METHOD }).to_s.upcase

          if BROWSER_METHODS.include?(verb)
            @attributes[:method] = verb
          else
            @attributes[:method] = DEFAULT_METHOD
            @verb                = verb
          end
        end

        # Return a set of default HTML attributes
        #
        # @api private
        # @since x.x.x
        def _attributes(type, name, attributes)
          { type: type, name: _input_name(name), id: _input_id(name), value: _value(name) }.merge(attributes)
        end

        # Input <tt>name</tt> HTML attribute
        #
        # @api private
        # @since x.x.x
        def _input_name(name)
          "#{ @name }[#{ name }]"
        end

        # Input <tt>id</tt> HTML attribute
        #
        # @api private
        # @since x.x.x
        def _input_id(name)
          name = _input_name(name).gsub(/\[(?<token>[[[:word:]]\-]*)\]/, INPUT_ID_REPLACEMENT)
          Utils::String.new(name).dasherize
        end

        # Input <tt>value</tt> HTML attribute
        #
        # @api private
        # @since x.x.x
        def _value(name)
          name = _input_name(name).gsub(/\[(?<token>[[:word:]]*)\]/, INPUT_VALUE_REPLACEMENT)
          @values.get(name) || @params.get(name)
        end

        # Input <tt>for</tt> HTML attribute
        #
        # @api private
        # @since x.x.x
        def _for(content, name)
          _input_id(name || content)
        end
      end
    end
  end
end

