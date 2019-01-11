class Ticker::Binance < Ticker::Base
  EXCHANGE_NAME = "Binance".freeze
  TICKERS_URL   = "http://api.binance.com/api/v1/exchangeInfo".freeze
  DELAY         = 3

  def initialize
    @logger = Logger.new(Rails.root + 'log/binance-ticker.log')
    super(EXCHANGE_NAME, TICKERS_URL)
  end

  def call
    begin
      tickers = JSON.parse(RestClient.get(tickers_url))["symbols"].map {|e| e["symbol"] }.select{ |e| e =~ /(BTC|USDT)$/ }

      tickers.each do |t|
        url = "http://api.binance.com/api/v1/klines"
        data = RestClient.get url, params: { symbol: t, interval: "15m", limit: 1 }
        response = JSON.parse(data)[0]

        puts "#{DateTime.now}: ticker is #{t}, candle is #{response.inspect}"

        high  = response[2]
        low   = response[3]
        close = response[4]

        s2 = t[/(USDT|BTC)$/]
        s1 = t.split(s2)[0]

        next unless close != 0
        pair = Pair.find_or_create_by(ticker: t, exchange_id: exchange.id)
        pair.update(last_price: close)
        pair.update(side1: s1, side2: s2) unless pair.side1 && pair.side2

        TradeSignal.where(pair_id: pair.id, status: :pending).where('entry >= ?', low).update(status: :active)
        TradeSignal.where(pair_id: pair.id, status: :active).where('stop >= ?', low).update(status: :stoploss)
        TradeSignal.where(pair_id: pair.id, status: :active).where('target <= ?', high).update(status: :takeprofit)

        sleep DELAY

      end
    rescue Exception => e
      @logger.error "Exception: #{e.message}, backtrace: #{e.backtrace}"
    end
  end

end
