require 'ostruct'

class Ether::Contract

  attr_accessor :client, :contract

  CONFIRM_AGE = 10

  TOKEN_NAME      = Rails.application.secrets.token_name.freeze
  TOKEN_ADDRESS   = Rails.application.secrets.token_address.freeze
  DEFAULT_ACCOUNT = Rails.application.secrets.token_default_account.freeze
  PRIVATE_KEY     = Rails.application.secrets.token_private_key.freeze

  def initialize
    @client   = Ether::Client.new
    @contract = Ethereum::Contract.create(name: TOKEN_NAME, address: TOKEN_ADDRESS, abi: CONTRACTS_ABI::ERC20, client: @client.connection)
  end

  def balance(address)
    return 0 unless address

    begin
      contract.call.balance_of(address) / (10.0**contract.call.decimals)
    rescue Exception => e
      ImportantLogger.add "SE3: get_token_balance #{address} - #{e.message}, #{e.backtrace}"
      nil
    end
  end

  def make_transaction(to, amount, private_key)
    return nil if amount.zero?

    amount       = (amount * (10.0**contract.call.decimals)).to_i
    contract.key = Eth::Key.new(priv: client.decrypt(private_key))

    Rails.logger.info("Token transfer from: #{contract.key.address} to: #{to}, amount: #{amount}")
    contract.transact.transfer(to, amount)
  rescue Exception => e
    ImportantLogger.add "SE3: Contract make_transaction #{contract.key.address}, to: #{to}, amount: #{amount} - #{e.message}, #{e.backtrace}"
    e.message
  ensure
    contract.key = nil
  end

  def make_withdraw(to, amount)
    make_transaction(to, amount, PRIVATE_KEY)
  end

  def transactions
    client.transactions(TOKEN_ADDRESS)
  end

  def get_transfer(txid)
    return nil unless info = client.transaction_receipt(txid)

    Rails.logger.info("Get info: #{info}")

    from      = info['from'].downcase
    log       = info['logs'].last

    return nil unless log

    signature = '0x' + contract.events.find{|c| c.name == 'Transfer'}.signature

    return nil unless log['topics'].first == signature

    data         = '0x' + (log['topics'].last + log['data']).gsub('0x', '')
    event_abi    = contract.abi.find {|a| a['name'] == 'transfer'}
    inputs       = event_abi['inputs']
    event_inputs = inputs.map {|i| OpenStruct.new(i)}

    result = client.decoder.decode_arguments(event_inputs, data)

    {txid: txid, from: from, to: '0x' + result.first.downcase, amount: (result.last / (10.0**contract.call.decimals)), raw_amount: result.last, raw_info: info}
  end

  private

  def formatter
    client.formatter
  end

end
