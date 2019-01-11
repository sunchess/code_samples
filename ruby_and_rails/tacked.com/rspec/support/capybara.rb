Capybara.register_driver :chrome do |app|
  ENV['DISPLAY'] ||= ":1"
  driver = Capybara::Selenium::Driver.new(app, browser: :chrome, switches: ['--test-type'])
  if ENV['DISPLAY'] == ":1"
    driver.browser.manage.window.maximize
  else
    driver.browser.manage.window.resize_to(1280, 1024)
  end
  client = Selenium::WebDriver::Remote::Http::Default.new
  client.timeout = 90 # instead of the default 60

  driver
end

Capybara.javascript_driver = :chrome
Capybara.default_max_wait_time = 5

