module DynamicFormHelper

  def error_messages_for_dynamic_form(object_name, options={})
    object = instance_variable_get("@#{object_name}")
    if object.errors
      options.reverse_merge!(
        :header_tag => :p,
        :header_message => "There #{object.errors.count == 1 ? 'was' : 'were'} #{pluralize(object.errors.count, 'error')} that did not allow your information to be processed.",
        :message => nil,
        :id => 'errorExplanation',
        :class => 'errorExplanation'
      )

      unless object.errors.count.zero?
        error_messages = object.errors.instance_variable_get('@errors').values.flatten.map {|msg| content_tag(:li, msg) }

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

  def render_dynamic_form(form_resource, options={})
    options.reverse_merge!  :object_name => 'dynamic_form',
                            :submit_text => 'Submit'

    rendered_form = Array.new

    rendered_form << form_tag({:controller => params[:controller], :action => 'create'}, :id => "Form-#{options[:object_name]}")

    rendered_form << hidden_field_tag('stylesheet', h(params[:stylesheet]), :id => nil) if params[:controller] == 'iframes' && params[:stylesheet]

    rendered_form << render_dynamic_fields(form_resource, options)

    rendered_form << content_tag(:div, :id => "FormRow-Submit-#{options[:object_name]}", :class => 'FormField-Row FieldType-submit_button') do
      "\n" +
      "  " + __submit_tag(:submit_name => options[:object_name], :submit_text => options[:submit_text]) +
      "\n"
    end

    rendered_form << "</form>"

    rendered_form.join("\n")
  end

  def render_dynamic_fields(form_resource, options={})
    options.reverse_merge!  :required_indicator => '*',
                            :object_name => 'dynamic_form'
    @dynamic_options = options

    rendered_fields = Array.new

    form_resource.fields.each do |field|
      input_name = options[:object_name].blank? ? field.column_name : "#{options[:object_name]}[#{field.column_name}]"

      field.displayed_label = field.label
      field.displayed_label << ':' if !field.displayed_label.empty? && !['?','.'].include?(field.displayed_label[-1,1])

      field.value = params[field.column_name] if field.value.nil? && !params[field.column_name].nil?

      error_indicator_class = form_resource.errors.invalid?(field.column_name) ? ' fieldWithErrors' : ''

      rendered_fields << content_tag(:div, :id => "FormRow-#{field.column_name}", :class => "FormField-Row FieldType-#{field.field_type}#{error_indicator_class}") do
        "\n" +
        self.send("__#{field.field_type}", field, input_name) +
        "\n" +
        "  " + content_tag(:div, '', :class => 'clear') +
        "\n"
      end
    end

    rendered_fields.join("\n")
  end

  def __check_box(field, input_name)
    box = String.new
    box << __required_indicator_tag if field.required == true
    box << content_tag(:div, :class => "FormField-Checkbox") do
      check_box_tag(input_name, :checked => !field.value.blank?)
    end
    box << content_tag(:div, :class => "FormField-CheckboxLabel") do
      __label_tag(input_name, field.displayed_label)
    end
    return box
  end

  def __file(field, input_name)
  end

  def __hidden_field(field, input_name)
    text = String.new
    text << "  " + content_tag(:div, :class => "FormField-Hidden") do
      hidden_field_tag(input_name, h(field.value), {:id => nil})
    end
    return text
  end

  def __password(field, input_name)
    text = String.new
    text << "  " + __standard_label(input_name, field.displayed_label, field.required == true)
    text << "\n"
    text << "  " + content_tag(:div, :class => "FormField-Password") do
      password_field_tag(input_name, h(field.value) || field.prompt, {:class => 'formInput'}.merge(field.html_options))
    end
    return text
  end

  def __multi_check_box(field, input_name)
    # selected_items = !field.value.blank? ? field.value.to_a : (!field.default_options.empty? ? field.default_options.collect{|option| option.value} : [])
    # 
    # text = String.new
    # 
    # question = String.new
    # question << __required_indicator_tag if field.required == true
    # question << field.displayed_label
    # 
    # options = String.new
    # field.option_groups.each do |option_group|
    #   options << "\n    " + content_tag(:div, option_group.label, :class => 'CheckBox-GroupLabel') unless field.combine_option_groups
    #   option_group.options.each do |option|
    #     options << "\n    " + content_tag(:div, :class => 'CheckBox-Option') do
    #       # check_box(input_name, option.value, :checked => selected_items.include?(option.value), :class => 'formCheck') +
    #       check_box_tag("#{input_name}[]", option.value, selected_items.include?(option.value), :id => "#{sanitize_to_id(input_name)}_#{option.value}", :class => 'formCheck') +
    #       label_tag("#{input_name}_#{option.value}", option.attributes['display'], :class => 'labelCheck')
    #     end
    #   end
    # end
    # options << "\n  "
    # 
    # text << "  " + content_tag(:div, question, :class => 'FormField-CheckQuestion')
    # text << "\n"
    # text << "  " + content_tag(:div, options, :class => "FormField-Input")
    # return text
  end

  def __multi_select(field, input_name)
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

  def __phone(field, input_name)
    return __text_field(field, input_name) unless field.separate_inputs

    field.area = params["#{field.column_name}_area"].nil? ? field.value[0..2] : params["#{field.column_name}_area"] if field.area.nil? && (!field.value.nil? || !params["#{field.column_name}_area"].nil?)
    field.prefix = params["#{field.column_name}_prefix"].nil? ? field.value[3..5] : params["#{field.column_name}_prefix"] if field.prefix.nil? && (!field.value.nil? || !params["#{field.column_name}_prefix"].nil?)
    field.suffix = params["#{field.column_name}_suffix"].nil? ? field.value[6..9] : params["#{field.column_name}_suffix"] if field.suffix.nil? && (!field.value.nil? || !params["#{field.column_name}_suffix"].nil?)

    text = String.new
    text << "  " + __standard_label(input_name.sub(']','_area]'), field.displayed_label, field.required == true)
    text << "\n"
    text << "  " + content_tag(:div, :class => "FormField-Input") do
      (field.dividers == true ? content_tag(:span, '(', :class => 'phoneDivider') : '') +
      text_field_tag(input_name.sub(']','_area]'), h(field.area || field.area_prompt), {:class => 'formPhone formPhone3', :maxlength => 3}) + 
      (field.dividers == true ? content_tag(:span, ')', :class => 'phoneDivider') : '') +
      text_field_tag(input_name.sub(']','_prefix]'), h(field.prefix || field.prefix_prompt), {:class => 'formPhone formPhone3', :maxlength => 3}) + 
      (field.dividers == true ? content_tag(:span, '-', :class => 'phoneDivider') : '') +
      text_field_tag(input_name.sub(']','_suffix]'), h(field.suffix || field.suffix_prompt), {:class => 'formPhone formPhone4', :maxlength => 4})
    end

    return text
  end

  def __radio_button(field, input_name)
    question = String.new
    question << __required_indicator_tag if field.required == true
    question << field.displayed_label
    
    selected_items = !field.value.blank? ? field.value.to_a : (!field.default_options.empty? ? field.default_options.collect{|option| option.value} : [])
    
    options = String.new
    field.option_groups.each do |group|
      group.options.each do |option|
        options << radio_button_tag(input_name, option.value, selected_items.include?(option.value), :class => 'formRadio')
        options << __label_tag("#{input_name}_#{option.value.downcase}", option.attributes['display'], :class => 'labelRadio')
      end
    end

    text = String.new
    text << "  " + content_tag(:div, question, :class => 'FormField-RadioQuestion')
    text << "\n"
    text << "  " + content_tag(:div, options, :class => 'FormField-Input')
    return text
  end

  def __select(field, input_name)
    selected_items = !field.value.blank? ? field.value : (!field.default_options.empty? ? field.default_options.collect{|option| option.value} : nil)
    select_items = Array.new
    if field.combine_option_groups || field.option_groups.size <= 1
      field.option_groups.each do |group|
        select_items += group.options.map{|option| [option.attributes['display'], option.value]}
      end
      select_items.sort!{|a,b| (a[0] || '') <=> (b[0] || '')}.uniq if field.combine_option_groups
      select_items.unshift([(field.prompt.blank? ? '' : field.prompt), nil]) if (field.value.blank? && field.default_options.blank? && !field.prompt.blank?) || field.allow_blank
      options = options_for_select(select_items, selected_items)
    else
      field.option_groups.each do |group|
        select_items << [[group.label], group.options.map{|option| [option.attributes['display'], option.value]}]
      end
      prompt = ((field.value.blank? && field.default_options.blank? && !field.prompt.blank?) || field.allow_blank) ? (field.prompt.blank? ? '' : field.prompt) : nil
      options = grouped_options_for_select(select_items, selected_items, prompt)
    end

    text = String.new
    text << "  " + __standard_label(input_name, field.displayed_label, field.required == true)
    text << "\n"
    text << "  " + content_tag(:div, :class => "FormField-Select") do
      select_tag(input_name, options, {:class => 'formSelect', :multiple => (field.html_options.size && field.html_options.size > 1 ? true: false)}.merge(field.html_options.attributes))
    end

    return text
  end

  def __text_area(field, input_name)
    text = String.new
    text << "  " + __standard_label(input_name, field.displayed_label, field.required == true)
    text << "\n"
    text << "  " + content_tag(:div, :class => "FormField-TextArea") do
      text_area_tag(input_name, h(field.value || field.prompt), field.html_options)
    end
    return text
  end

  def __text_field(field, input_name)
    text = String.new
    text << "  " + __standard_label(input_name, field.displayed_label, field.required == true)
    text << "\n"
    text << "  " + content_tag(:div, :class => "FormField-Input") do
      text_field_tag(input_name, h(field.value || field.prompt), {:class => 'formInput'}.merge(field.html_options.attributes))
    end
    return text
  end

  # -----------------------------------------------------------------------------------------------

  def __submit_tag(options={})
    btn = String.new
    span_id = "submit-span-#{options[:submit_name]}"
    btn << content_tag(:div, :class => "FormField-Submit", :id => "FormField-Submit-#{options[:submit_name]}") do
      submit_tag(options[:submit_text],
        :class => 'FormField-SubmitButton',
        :onmouseover => "this.className='FormField-SubmitButton-on'; document.getElementById('#{span_id}').className='FormField-SubmitSpan-on';",
        :onmouseout => "this.className='FormField-SubmitButton'; document.getElementById('#{span_id}').className='FormField-SubmitSpan';"
      ) + 
      content_tag(:span, '', :class => "FormField-SubmitSpan", :id => span_id)
    end
    return btn
  end

  # -----------------------------------------------------------------------------------------------

  def __required_indicator_tag
    content_tag(:span, "#{@dynamic_options[:required_indicator]}", :class => 'required')
  end

  def __standard_label(input_name, label, required=false)
    text = String.new
    text << __required_indicator_tag if required == true
    text << __label_tag(input_name, label)
    return content_tag(:div, text, :class => "FormField-Label")
  end

  def __label_tag(name, text = nil, options = {})
    label_tag(name.downcase.gsub(/\./,''), text, options)
  end

end