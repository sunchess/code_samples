class Ticker::Bitfinex < Ticker::Base
  EXCHANGE_NAME = "Bitfinex".freeze
  TICKERS_URL   = "https://api.bitfinex.com/v1/symbols".freeze
  DELAY         = 10

  def initialize
    @logger = Logger.new(Rails.root + 'log/bitfinex-ticker.log')
    super(EXCHANGE_NAME, TICKERS_URL)
  end

  def call
    begin
      tickers = JSON.parse(RestClient.get(tickers_url)).select {|e| e =~ /btc|usd$/ }

      tickers.each do |t|
        data = RestClient.get("https://api.bitfinex.com/v2/candles/trade:15m:t#{t.upcase}/last")
        response = JSON.parse(data)

        puts "#{DateTime.now}: candle is #{response.inspect}"

        close, high, low  = response[2], response[3], response[4]

        s1 = t[0..2]
        s2 = t[3..-1]

        next unless close != 0
        pair = Pair.find_or_create_by(ticker: t, exchange_id: exchange.id)
        pair.update(last_price: close)
        pair.update(side1: s1, side2: s2) unless pair.side1 && pair.side2

        #long
        ts = TradeSignal.where(direction: :long, pair_id: pair.id)
        ts.where(status: :pending).where('entry >= ?', low).update(status: :active)
        ts.where(status: :active ).where( 'stop >= ?',  low).update(status: :stoploss)
        ts.where(status: :active ).where('target <= ?',high).update(status: :takeprofit)

        #short
        ts = TradeSignal.where(direction: :short, pair_id: pair.id)
        ts.where(status: :pending).where('entry <= ?', high).update(status: :active)
        ts.where(status: :active ).where( 'stop <= ?',  high).update(status: :stoploss)
        ts.where(status: :active ).where( 'target >= ?', low).update(status: :takeprofit)

        sleep DELAY

      end

    rescue Exception => e
      @logger.error "Exception: #{e.message}, backtrace: #{e.backtrace}"
    end
  end
end
