module DynamicFormHelper
  # The objects passed in could potentially be frozen. Thus they need to be duplicated.

  def error_messages_for_dynamic_form(object_name, options={})
    object = instance_variable_get("@#{object_name}")
    unless object.is_a?(String)
      object = object.dup if object.frozen?

      if object.errors
        options.reverse_merge!(
          :header_tag => :p,
          :header_message => "There #{object.errors.count == 1 ? 'was' : 'were'} #{pluralize(object.errors.count, 'error')} that did not allow your information to be processed.",
          :message => nil,
          :id => 'errorExplanation',
          :class => 'errorExplanation',
          :order_important => true
        )

        unless object.errors.count.zero?
          errors = object.errors.instance_variable_get('@errors')

          if options[:order_important] && object.fields
            error_messages = ''
            object.fields.each do |field|
              errors[field.column_name].each {|msg| error_messages << content_tag(:li, msg) } if errors[field.column_name]
            end
          else
            error_messages = errors.values.flatten.map {|msg| content_tag(:li, msg) }
          end

          contents = ''
          contents << content_tag(options[:header_tag], options[:header_message]) unless options[:header_message].blank?
          contents << content_tag(:p, options[:message]) unless options[:message].blank?
          contents << content_tag(:ul, error_messages)

          content_tag(:div, contents, {:id => options[:id], :class => options[:class]})
        else
          ''
        end
      end
    end
  end

  def render_dynamic_form(form_resource, options={})
    form_resource = form_resource.dup if form_resource.frozen?
    form_resource.displaying_step = nil unless form_resource.attributes.has_key?('displaying_step')
    form_resource.last_step = nil unless form_resource.attributes.has_key?('last_step')

    options.reverse_merge!(
      :object_name => 'dynamic_form',
      :submit_text => 'Submit',
      :step_submit_text => 'Next',
      :required_indicator_position => 'left',
      :use_validation_classes => false,
      :inline_field_dependencies => true
    )

    rendered_form =  Array.new
    rendered_form << form_tag({:controller => controller.controller_name, :action => 'create'}, :id => "Form-#{options[:object_name]}", :class => ("Form-Step#{form_resource.displaying_step}" unless form_resource.displaying_step.nil?))
    rendered_form << hidden_field_tag('displaying_step', form_resource.displaying_step) unless form_resource.displaying_step.nil?
    rendered_form << hidden_field_tag('stylesheet', h(params[:stylesheet]), :id => nil) if controller.controller_name == 'iframes' && params[:stylesheet]
    rendered_form << render_dynamic_fields(form_resource, options)
    rendered_form << content_tag(:div, :id => "FormRow-Submit-#{options[:object_name]}", :class => 'FormField-Row FieldType-submit_button') do
      "\n" +
      "  " + __submit_tag(:submit_name => options[:object_name], :submit_text => (!form_resource.displaying_step.nil? && form_resource.displaying_step != form_resource.last_step ? options[:step_submit_text] : options[:submit_text]), :displaying_step => form_resource.displaying_step, :submit_hover => (options[:submit_hover] unless options[:submit_hover].nil?)) +
      "\n"
    end
    rendered_form << "</form>"
    rendered_form.join("\n")
  end

  def render_dynamic_fields(form_resource, options={})
    form_resource = form_resource.dup if form_resource.frozen?

    options.reverse_merge!(
      :object_name => 'dynamic_form',
      :required_indicator => '*',
      :required_indicator_position => 'left',
      :use_validation_classes => false,
      :inline_field_dependencies => true
    )
    @dynamic_options = options

    rendered_fields = Array.new

    form_resource.fields.each do |field|
      if field.is_a?(Hash)
        if field[:type] == :passthru
          rendered_fields << field[:html]
        end
      else
        input_name = options[:object_name].blank? ? field.column_name : "#{options[:object_name]}[#{field.column_name}]"

        field.displayed_label = field.label.dup rescue ''
        field.displayed_label << ':' if !field.displayed_label.empty? && !['?','.'].include?(field.displayed_label[-1,1])

        field.value = params[field.column_name] if field.value.nil? && !params[field.column_name].nil?

        error_indicator_class = form_resource.errors.invalid?(field.column_name) ? ' fieldWithErrors' : ''

        if field.display? != false || field.value.present?
          row_options = {:id => "FormRow-#{field.column_name}", :class => "FormField-Row FieldType-#{field.field_type}#{error_indicator_class}"}
          field_options = {}

          if options[:inline_field_dependencies] == true
            field_options['data-children'] = field.attributes['children']

            field.attributes['parents'].attributes.each do |key, value|
              row_options["data-dependency-#{key}"] = "#{value}"
            end if field.attributes['parents'] && !field.attributes['parents'].empty?

            if field.display? == 'dependent'
              row_options[:style] = "display:none;"
              field_options[:disabled] = true
            end
          end

          rendered_fields << content_tag(:div, row_options) do
            "\n" +
            self.send((field.display? == false ? :__hidden_field : "__#{field.field_type}"), field, input_name, field_options) +
            "\n" +
            "  " + content_tag(:div, '', :class => 'clear') +
            "\n"
          end
        end
      end
    end

    rendered_fields.join("\n")
  end

  def __check_box(field, input_name, field_options={})
    box = String.new
    box << __required_indicator_tag if field.required == true
    box << content_tag(:div, :class => "FormField-Checkbox") do
      ____check_box(field, input_name, field_options)
    end
    box << content_tag(:div, :class => "FormField-CheckboxLabel") do
      __label_tag(input_name, field.displayed_label)
    end
    return box
  end

  def ____check_box(field, input_name, field_options={})
    text = String.new
    text << check_box_tag(input_name, field.input_value, !field.value.blank?)
    return text
  end

  def __file(field, input_name, field_options={})
  end

  def __hidden_field(field, input_name, field_options={})
    text = String.new
    text << "  " + content_tag(:div, :class => "FormField-Hidden") do
      hidden_field_tag(input_name, h(field.value), {:id => nil})
    end
    return text
  end

  def __password(field, input_name, field_options={})
    text = String.new
    text << "  " + __standard_label(input_name, field.displayed_label, field.required == true)
    text << "\n"
    text << "  " + content_tag(:div, :class => "FormField-Password") do
      password_field_tag(input_name, h(field.value) || field.prompt, {:class => 'formInput'}.merge(field.html_options))
    end
    return text
  end

  def __multi_check_box(field, input_name, field_options={})
    selected_items = if field.value.blank?
      (!field.default_options.empty? ? field.default_options.collect{|option| option.value} : [])
    else
      field.value.attributes.values rescue []
    end

    question = String.new
    if @dynamic_options && @dynamic_options[:required_indicator_position] == 'right'
      question << content_tag(:span, field.displayed_label, :class => "label")
      question << __required_indicator_tag if field.required == true
    else
      question << __required_indicator_tag if field.required == true
      question << content_tag(:span, field.displayed_label, :class => "label")
    end

    options = String.new
    field.option_groups.each do |option_group|
      options << "\n    " + content_tag(:div, option_group.label, :class => 'CheckBox-GroupLabel') unless field.combine_option_groups
      option_group.options.each do |option|
        input_id = "#{sanitize_to_id(input_name)}_#{sanitize_to_id(option.value)}"

        options << "\n    " + content_tag(:div, :class => 'CheckBox-Option') do
          check_box_tag("#{input_name}[]", option.value, selected_items.include?(option.value), :id => input_id, :class => 'formCheck') +
          label_tag(input_id, option.attributes['display'], :class => 'labelCheck')
        end
      end
    end
    options << "\n  "

    text = String.new
    text << "  " + content_tag(:div, question, :class => 'FormField-CheckboxQuestion')
    text << "\n"
    text << "  " + content_tag(:div, options, :class => "FormField-Input")
    return text
  end

  def __multi_select(field, input_name, field_options={})
    # selected_items = !field.value.blank? ? field.value : (!field.default_options.empty? ? field.default_options.collect{|option| option.value} : nil)
    # select_items = Array.new
    # if field.combine_option_groups || field.option_groups.size <= 1
    #   field.option_groups.each do |group|
    #     select_items += group.options.map{|option| [option.attributes['display'], option.value]}
    #   end
    #   select_items.sort!{|a,b| (a[0] || '') <=> (b[0] || '')}.uniq if field.combine_option_groups
    #   select_items.unshift([(field.prompt.blank? ? '' : field.prompt), nil]) if (field.value.blank? && field.default_options.blank? && !field.prompt.blank?) || field.allow_blank
    #   options = options_for_select(select_items, selected_items)
    # else
    #   field.option_groups.each do |group|
    #     select_items << [[group.label], group.options.map{|option| [option.attributes['display'], option.value]}]
    #   end
    #   prompt = ((field.value.blank? && field.default_options.blank? && !field.prompt.blank?) || field.allow_blank) ? (field.prompt.blank? ? '' : field.prompt) : nil
    #   options = grouped_options_for_select(select_items, selected_items, prompt)
    # end
    # 
    # text = String.new
    # text << "  " + __standard_label(input_name, field.displayed_label, field.required == true)
    # text << "\n"
    # text << "  " + content_tag(:div, :class => "FormField-Input") do
    #   select_tag(input_name, options, {:class => 'formSelect', :multiple => (field.html_options.size && field.html_options.size > 1 ? true: false)}.merge(field.html_options.attributes))
    # end
    # 
    # return text
  end

  def __phone(field, input_name, field_options={})
    return __text_field(field, input_name, field_options) unless field.separate_inputs

    field.area = params["#{field.column_name}_area"].nil? ? field.value[0..2] : params["#{field.column_name}_area"] if field.area.nil? && (!field.value.nil? || !params["#{field.column_name}_area"].nil?)
    field.prefix = params["#{field.column_name}_prefix"].nil? ? field.value[3..5] : params["#{field.column_name}_prefix"] if field.prefix.nil? && (!field.value.nil? || !params["#{field.column_name}_prefix"].nil?)
    field.suffix = params["#{field.column_name}_suffix"].nil? ? field.value[6..9] : params["#{field.column_name}_suffix"] if field.suffix.nil? && (!field.value.nil? || !params["#{field.column_name}_suffix"].nil?)

    text = String.new
    text << "  " + __standard_label(input_name.sub(']','_area]'), field.displayed_label, field.required == true)
    text << "\n"
    text << "  " + content_tag(:div, :class => "FormField-Input") do
      ____phone(field, input_name, field_options)
    end

    return text
  end

  def ____phone(field, input_name, field_options={})
    return ____text_field(field, input_name, field_options) unless field.separate_inputs

    field.area = params["#{field.column_name}_area"].nil? ? field.value[0..2] : params["#{field.column_name}_area"] if field.area.nil? && (!field.value.nil? || !params["#{field.column_name}_area"].nil?)
    field.prefix = params["#{field.column_name}_prefix"].nil? ? field.value[3..5] : params["#{field.column_name}_prefix"] if field.prefix.nil? && (!field.value.nil? || !params["#{field.column_name}_prefix"].nil?)
    field.suffix = params["#{field.column_name}_suffix"].nil? ? field.value[6..9] : params["#{field.column_name}_suffix"] if field.suffix.nil? && (!field.value.nil? || !params["#{field.column_name}_suffix"].nil?)

    html_options = field.respond_to?(:html_options) ? field.html_options.attributes : {}
    html_options[:type] = field.html5_type if field.respond_to?('html5_type')

    text = String.new
    text << content_tag(:span, '(', :class => 'phoneDivider') if field.dividers == true
    text << text_field_tag(input_name.sub(']','_area]'), h(field.area || field.area_prompt), {:class => 'formPhone formPhone3', :maxlength => 3}.reverse_merge(html_options))
    text << content_tag(:span, ')', :class => 'phoneDivider') if field.dividers == true
    text << text_field_tag(input_name.sub(']','_prefix]'), h(field.prefix || field.prefix_prompt), {:class => 'formPhone formPhone3', :maxlength => 3}.reverse_merge(html_options))
    text << content_tag(:span, '-', :class => 'phoneDivider') if field.dividers == true

    suffix_html_options = {:class => 'formPhone formPhone4', :maxlength => 4}.reverse_merge(html_options)
    if @dynamic_options && @dynamic_options[:use_validation_classes] == true
      suffix_html_options[:class] << ' validate-required-phone' if field.required?
      suffix_html_options[:class] << ' validate-phone'
    end
    text << text_field_tag(input_name.sub(']','_suffix]'), h(field.suffix || field.suffix_prompt), suffix_html_options)

    return text
  end

  def __radio_button(field, input_name, field_options={})
    question = String.new
    if @dynamic_options && @dynamic_options[:required_indicator_position] == 'right'
      question << __label_tag(input_name, field.displayed_label, :for => nil)
      question << __required_indicator_tag if field.required == true
    else
      question << __required_indicator_tag if field.required == true
      question << __label_tag(input_name, field.displayed_label, :for => nil)
    end

    selected_item = field.value.blank? ? (field.default_option.nil? ? nil : field.default_option.item_value) : field.value

    if @dynamic_options && @dynamic_options[:use_validation_classes] == true && field.required?
      last_option = field.option_groups.last.options.last rescue nil
    end

    options = String.new
    field.option_groups.each do |group|
      group.options.each do |option|
        options << content_tag(:span, :class => 'spanRadio') do

          html_options = {:class => 'formRadio'}
          if @dynamic_options && @dynamic_options[:use_validation_classes] == true && field.required?
            html_options[:class] << ' validate-one-required' if option.attributes['display'] == last_option.attributes['display'] && option.value == last_option.value
          end

          radio_button_tag(input_name, option.value, selected_item == option.value, html_options) +
          __label_tag("#{input_name}_#{option.value.downcase}", option.attributes['display'], :class => 'labelRadio')
        end
      end
    end

    text = String.new
    text << "  " + content_tag(:div, question, :class => 'FormField-RadioQuestion')
    text << "\n"
    text << "  " + content_tag(:div, options, :class => 'FormField-Input')
    return text
  end

  def __select(field, input_name, field_options={})
    text = String.new
    text << "  " + __standard_label(input_name, field.displayed_label, field.required == true)
    text << "\n"
    text << "  " + content_tag(:div, :class => "FormField-Select") do
      ____select(field, input_name, field_options)
    end

    return text
  end

  def ____select(field, input_name, field_options={})
    selected_item = field.value.blank? ? ((field_options[:override][:default_option] if field_options[:override]) || (field.default_option.item_value unless field.default_option.nil?)) : field.value
    prompt = (field_options[:override][:prompt] if field_options[:override]) || (field.prompt if field.respond_to?(:prompt))

    select_items = Array.new
    if field.combine_option_groups || field.option_groups.size <= 1
      field.option_groups.each do |group|
        select_items += group.options.map{|option| [option.attributes['display'], option.value]}
      end
      select_items.sort!{|a,b| (a[0] || '') <=> (b[0] || '')}.uniq if field.combine_option_groups
      select_items.unshift([(prompt.blank? ? '' : prompt), nil]) if (field.value.blank? && field.default_option.blank? && !prompt.blank?) || (field.responds_to?(:allow_blank) && field.allow_blank)
      options = options_for_select(select_items, selected_item)
    else
      field.option_groups.each do |group|
        select_items << [[group.label], group.options.map{|option| [option.attributes['display'], option.value]}]
      end
      grouped_prompt = ((field.value.blank? && field.default_option.blank? && !prompt.blank?) || field.allow_blank) ? (prompt.blank? ? '' : prompt) : nil
      options = grouped_options_for_select(select_items, selected_item, grouped_prompt)
    end

    html_options = {:class => 'formSelect'}.merge!(field_options)

    unless prompt.blank?
      first_value = options.match(/^<option.*?>(.*?)</)
      if first_value && first_value[1] == prompt
        options.sub!(/^<(.*?)>/, '<\1 class="prompt">')
      end
      html_options[:onfocus] = "this.className='#{html_options[:class]}';"
      html_options[:onblur] = "if(this[this.selectedIndex].text=='#{prompt}'){this.className='#{html_options[:class]} prompt';}"
      html_options[:class] = "#{html_options[:class]} prompt" if selected_item.blank?
    end

    text = String.new
    text << select_tag(input_name, options, html_options)
    return text
  end

  def __text_area(field, input_name, field_options={})
    html_options = field.respond_to?(:html_options) ? field.html_options.attributes : {}
    html_options[:class] = 'formTextArea' if html_options[:class].nil?

    text = String.new
    text << "  " + __standard_label(input_name, field.displayed_label, field.required == true)
    text << "\n"
    text << "  " + content_tag(:div, :class => "FormField-TextArea") do
      text_area_tag(input_name, h(field.value || field.prompt), html_options)
    end
    return text
  end

  def __text_field(field, input_name, field_options={})
    text = String.new
    text << "  " + __standard_label(input_name, field.displayed_label, field.required == true)
    text << "\n"
    text << "  " + content_tag(:div, :class => "FormField-Input") do
      ____text_field(field, input_name, field_options) +
      (field.attributes['trailing_label'].nil? ? '' : __trailing_label(field.attributes['trailing_label']))
    end
    return text
  end

  def ____text_field(field, input_name, field_options={})
    prompt = field_options[:overriding_prompt] || (field.prompt if field.respond_to?(:prompt))
    value = field.value || prompt

    html_options = field.respond_to?(:html_options) ? field.html_options.attributes : {}
    html_options[:class] ||= 'formInput'
    html_options[:type] = field.html5_type if field.respond_to?('html5_type')

    if @dynamic_options && @dynamic_options[:use_validation_classes] == true
      html_options[:class] << ' required' if field.required?
      html_options[:class] << ' validate-email' if field.column_name == 'email'
    end

    unless prompt.blank?
      html_options[:onfocus] = "if(this.value=='#{prompt}'){this.value=''; this.className='#{html_options[:class]}';}"
      html_options[:onblur] = "if(this.value==''){this.value='#{prompt}'; this.className='#{html_options[:class]} prompt';}"
      html_options[:class] << ' prompt' if value == prompt
    end

    text = String.new
    text << text_field_tag(input_name, h(value), html_options)
    return text
  end

  def __trailing_label(value)
    content_tag(:span, value, :class => "trailing-label")
  end

  # -----------------------------------------------------------------------------------------------

  def __submit_tag(options={})
    btn = String.new
    btn << content_tag(:div, :class => "FormField-Submit Submit-#{options[:submit_text].gsub(/\W/, '').underscore}#{" SubmitStep#{options[:displaying_step]}" unless options[:displaying_step].nil?}", :id => "FormField-Submit-#{options[:submit_name]}") do
      ____submit_tag(options)
    end
    return btn
  end

  def ____submit_tag(options={})
    span_id = "submit-span-#{options[:submit_name]}"

    btn = String.new
    btn << submit_tag(options[:submit_text],
      :class => "FormField-SubmitButton",
      :onmouseover => (options[:submit_hover].nil? || options[:submit_hover] == true) ? "this.className='FormField-SubmitButton-on'; document.getElementById('#{span_id}').className='FormField-SubmitSpan-on';" : nil,
      :onmouseout => (options[:submit_hover].nil? || options[:submit_hover] == true) ? "this.className='FormField-SubmitButton'; document.getElementById('#{span_id}').className='FormField-SubmitSpan';" : nil
    )
    btn << content_tag(:span, '', :class => "FormField-SubmitSpan", :id => span_id)
    return btn
  end

  # -----------------------------------------------------------------------------------------------

  def __required_indicator_tag
    content_tag(:span, "#{!@dynamic_options.nil? ? @dynamic_options[:required_indicator] : '*'}", :class => 'required')
  end

  def __standard_label(input_name, label, required=false)
    text = String.new
    if @dynamic_options && @dynamic_options[:required_indicator_position] == 'right'
      text << __label_tag(input_name, label)
      text << __required_indicator_tag if required == true
    else
      text << __required_indicator_tag if required == true
      text << __label_tag(input_name, label)
    end
    return content_tag(:div, text, :class => "FormField-Label")
  end

  def __label_tag(name, text = nil, options = {})
    label_tag(name.downcase.gsub(/\./,''), text, options)
  end

end