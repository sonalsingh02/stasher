# Stasher

This gem is a heavy modification of [Logstasher](https://github.com/shadabahmed/logstasher), which was 
inspired from [LogRage](https://github.com/roidrage/lograge).  It adds the same request logging for logstash as
Logstasher, but also includes a modified Ruby Logger instance to allow you to send all of your logging to logstash.

## About stasher

This gem This gem logs to a separate log file named `logstash_<environment>.log`.  It provides two facilities:
 * Request and response logging (ala Logstasher and LogRage)
 * Redirection of the Rails logger, with request-scoped parameters

Before **stasher** :

```
Started GET "/login" for 10.109.10.135 at 2013-04-30 08:59:01 -0400
Processing by SessionsController#new as HTML
  Rendered sessions/new.html.haml within layouts/application (4.3ms)
  Rendered shared/_javascript.html.haml (0.6ms)
  Rendered shared/_flashes.html.haml (0.2ms)
  Rendered shared/_header.html.haml (52.9ms)
  Rendered shared/_title.html.haml (0.2ms)
  Rendered shared/_footer.html.haml (0.2ms)
  Banner Load  SELECT `banners`.* FROM `banners` WHERE `banner`.`active` = 1 ORDER BY created_at DESC
Found 3 banners to display on the login page
Completed 200 OK in 532ms (Views: 62.4ms | ActiveRecord: 0.0ms | ND API: 0.0ms)
```

After **stasher**:

```
{"@source":"rails://localhost/my-app","@tags":["request"],"@fields":{"method":"GET","path":"/login","format":"html","controller":"sessions"
,"action":"login","ip":"127.0.0.1",params:{},"uuid":"e81ecd178ed3b591099f4d489760dfb6","user":"shadab_ahmed@abc.com",
"site":"internal"},"@timestamp":"2013-04-30T13:00:46.354500+00:00"}
{"@source":"rails://localhost/my-app","@tags":["sql"],"@fields":{"name":"Banner Load","sql":"SELECT `banners`.* FROM `banners` WHERE `banner`.`active` = 1 ORDER BY created_at DESC","uuid":"e81ecd178ed3b591099f4d489760dfb6"},"@timestamp":"2013-04-30T13:00:46.362300+00:00"}
{"@source":"rails://localhost/my-app","@tags":["log","debug"],"@fields":{"severity":"DEBUG","uuid":"e81ecd178ed3b591099f4d489760dfb6"},"@message":"Found 3 banners to display on the login page","@timestamp":"2013-04-30T13:00:46.353400+00:00"}
{"@source":"rails://localhost/my-app","@tags":["response"],"@fields":{"method":"GET","path":"/login","format":"html","controller":"sessions"
,"action":"login","status":200,"duration":28.34,"view":25.96,"db":0.88,"ip":"127.0.0.1","uuid":"e81ecd178ed3b591099f4d489760dfb6","user":"shadab_ahmed@abc.com",
"site":"internal"},"@timestamp":"2013-04-30T13:00:46.354500+00:00"}
```

By default, the older format rails request logs are disabled, though you can enable them.

All events logged within a Rack request will include the request's UUID, allowing you to follow individual requests through the logs.

## Installation

In your Gemfile:

    gem 'stasher'

### Configure your `<environment>.rb` e.g. `development.rb`

    # Enable the logstasher logs for the current environment and set the log level
    config.stasher.enabled = true
    config.stasher.log_level = :debug

    # This line is optional if you do not want to suppress app logs in your <environment>.log
    config.stasher.suppress_app_log = false

    # This line causes the Rails logger to be redirected to logstash as well
    config.stasher.redirect_logger = true

    # To prevent logging of SQL into logstash, remove :active_record from this line
    config.stasher.attach_to = [ :action_controller, :active_record ]

## Adding custom fields to the log

Since some fields are very specific to your application for e.g. *user_name*, so it is left 
up to you to add them. Here's how to add those fields to the logs:

    # Create a file - config/initializers/stasher.rb

    if Stasher.enabled
      Stasher.add_custom_fields do |fields|
        # This block is run in application_controller context, 
        # so you have access to all controller methods
        fields[:user] = current_user && current_user.mail
        fields[:site] = request.path =~ /^\/api/ ? 'api' : 'user'        
      end
    end

## Versions
All versions require Rails 3.2.x and higher and Ruby 1.9.2+. This code has not been tested on Rails 4 and Ruby 2.0

## Development
 - Run tests - `rake`
 - Generate test coverage report - `rake coverage`. Coverage report path - coverage/index.html

## License

Released under MIT license.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
