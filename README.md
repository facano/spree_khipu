SpreeKhipu

Introduction goes here.

Installation
------------

Add spree_khipu to your Gemfile:

```ruby
gem 'spree_khipu'
```

Bundle your dependencies and run the installation generator:

```shell
bundle
bundle exec rails g spree_khipu:install
```

Configuration
----------------
Add `config/khipu.yml` if you want to configure the protocol in URLs to send:
```ruby
development:
  protocol: 'http'
production:
  protocol: 'https'
```

If you use multistore configuration with the `spree-multi-domain` gem, customize the subject email using the tag `%current_store%`  in the desired location.

Testing
-------

First bundle your dependencies, then run `rake`. `rake` will default to building the dummy app if it does not exist, then it will run specs. The dummy app can be regenerated by using `rake test_app`.

```shell
bundle
bundle exec rake
```

When testing your applications integration with this extension you may use it's factories.
Simply add this require statement to your spec_helper:

```ruby
require 'spree_khipu/factories'
```


