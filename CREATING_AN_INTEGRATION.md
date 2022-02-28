# Creating a new integration

You can run the following generator to create a new integration:

```bash
rails g integration #{vendor}/#{version}
```

This will create:
```bash
create  app/models/pager_tree/integrations/#{vendor}/#{version}.rb
create  app/views/pager_tree/integrations/#{vendor}/#{version}/_form_options.html.erb
create  app/views/pager_tree/integrations/#{vendor}/#{version}/_show_options.html.erb
create  test/models/pager_tree/integrations/#{vendor}/#{version}_test.rb
```

# Files

## Model
Handles logic for transforming an incoming HTTP request into a PagerTree::Integrations::Alert
```
app/models/pager_tree/integrations/#{vendor}/#{version}.rb
```
Example: `app/models/pager_tree/integrations/apex_ping/v3.rb`

- All methods should be prefixed with `adapter_`
- All options should be prefixed with `option_`
- Make sure to add validations for your options
- You can optionally add attached objects

You need to make sure to implement a couple of functions:
- `adapter_supports_incoming?`
- `adapter_supports_outgoing?`
- `adapter_incoming_action`
- `adapter_thirdparty_id`

## View
For views we use Tailwind CSS for styling. For the positioning of elements you should likely use grid or flex.

### _form_options.html.erb
Input options to the user during create and update (think API keys, options, ect.). *If there are none that need to be configured, please leave the file blank, but do make sure the file exists!*

`app/views/pager_tree/integrations/#{vendor}/#{version}/_form_options.html.erb` - example `app/views/pager_tree/integrations/apex_ping/v3/_form_options.html.erb`

#### String input option
```html
<div class="form-group">
  <%= form.label :option_account_sid %>
  <%= form.text_field :option_account_sid, class: "form-control" %>
  <p class="form-hint"><%== t(".option_account_sid_hint_html") %></p>
</div>
```

#### File Upload input option
```html
<div class="form-group">
  <%= form.label :option_welcome_media %>
  <%= form.file_field :option_welcome_media, accept: "audio/*", class: "file:mr-4 file:py-2 file:px-4 file:rounded-full file:border-0 file:text-sm file:font-semibold file:bg-gray-50 file:text-gray-700 hover:file:bg-gray-100" %>
  <p class="form-hint"><%== t(".option_welcome_media_hint_html") %></p>
</div>
```

#### Check Box input option
```html
<div class="form-group">
  <%= form.label :option_record %>
  <%= form.check_box :option_record, class: "form-checkbox" %>
  <p class="form-hint"><%== t(".option_record_hint_html") %></p>
</div>
```

#### Password input option
```html
<div class="form-group" data-controller="password-visibility">
  <%= form.label :option_api_key %>
  <%= form.password_field :option_api_key, value: form.object.option_api_key, class: "form-control", data: { password_visibility_target: "input"} %>
  <div class="flex justify-between">
    <p class="form-hint"><%== t(".option_api_key_hint_html") %></p>
    <%= render partial: "shared/password_visibility_button" %>
  </div>
</div>
```

#### Tag input option
```html
<div class="form-group" data-controller="tagify">
  <%= form.label :option_record_emails_list %>
  <%= form.text_field :option_record_emails_list, class: "form-control", data: { tagify_target: "input" } %>
  <p class="form-hint"><%== t(".option_record_emails_list_hint_html") %></p>
</div>
```

### _show_options.html.erb
Shows options on the integration page. You likely don't need to show everything that can be configured, rather only important ones. Make sure to `mask` anything that could be sensitive. *If there are none, please leave the file blank, but do make sure the file exists!*

`app/views/pager_tree/integrations/#{vendor}/#{version}/_show_options.html.erb` - example `app/views/pager_tree/integrations/apex_ping/v3/_show_options.html.erb`

#### String show option
```html
<div class="sm:col-span-1">
  <dt class="text-sm font-medium text-gray-500">
    <%= t("activerecord.attributes.pager_tree/integrations/live_call_routing/twilio/v3.option_account_sid") %>
  </dt>
  <dd class="mt-1 text-sm text-gray-900">
    <div class="flex items-center gap-2">
      <p class="text-sm truncate">
        <%= integration.option_account_sid %>
      </p>
    </div>
  </dd>
</div>
```

#### File Upload show option
```html
<div class="sm:col-span-1">
  <dt class="text-sm font-medium text-gray-500">
    <%= t("activerecord.attributes.pager_tree/integrations/live_call_routing/twilio/v3.option_music_media") %>
  </dt>
  <dd class="mt-1 text-sm text-gray-900">
    <div class="flex items-center gap-2">
      <p class="text-sm truncate">
        <% if integration.option_music_media.present? %>
          <%= link_to integration.option_music_media.blob.filename, integration.option_music_media %>
        <% else %>
          -
        <% end %>
      </p>
    </div>
  </dd>
</div>
```

#### Enabled Flag show option
```html
<div class="sm:col-span-1">
  <dt class="text-sm font-medium text-gray-500">
    <%= t("activerecord.attributes.pager_tree/integrations/live_call_routing/twilio/v3.option_force_input") %>
  </dt>
  <dd class="mt-1 text-sm text-gray-900">
    <%= render partial: "shared/components/badge_enabled", locals: { enabled: integration.option_force_input? } %>
  </dd>
</div>
```

#### Masked String show option
```html
<div class="sm:col-span-1">
  <dt class="text-sm font-medium text-gray-500">
    <%= t("activerecord.attributes.pager_tree/integrations/live_call_routing/twilio/v3.option_api_secret") %>
  </dt>
  <dd class="mt-1 text-sm text-gray-900">
    <div class="flex items-center gap-2">
      <p class="text-sm truncate">
        <%= mask integration.option_api_secret %>
      </p>
    </div>
  </dd>
</div>
```

### Translations
Don't forget to add `English (en)` translations for your integration. You need to update `config/locales/en.yml`. **Make sure you add high level vendor keys in alphabetical order, else your PR will be rejected.** (Child keys)

1. The form options under the key `en.pager_tree.integrations.#{vendor}.#{version}.form_options.option_#{option_name}_hint_html`
1. The Active Record attributes under the key `en.activerecord.attributes.pager_tree/integrations/integration.option_#{option_name}`

### Tests
Please make sure to add appropriate tests for your addition (model tests, and if applicable, controller tests). **These should be quality tests.**
