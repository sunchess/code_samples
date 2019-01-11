class Ticker::Base
  attr_reader :exchange_name, :tickers_url
  attr_reader :exchange

  def initialize(exchange_name, tickers_url)
    @exchange_name, @tickers_url = exchange_name, tickers_url
    @exchange = Exchange.find_by(name: @exchange_name)
  end

  def call
    raise 'This is a virtual method, you should init "call" method in your class'
  end
end
