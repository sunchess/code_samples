class Ether::Client

  attr_accessor :connection, :formatter, :decoder

  def initialize
    @connection = ::Ethereum::HttpClient.new(Rails.configuration.ipc_eth_path, nil, Rails.env.development?)
    #it's necessary because we're using INFURA network
    @connection.default_account = ::Ether::Contract::DEFAULT_ACCOUNT
    @decoder = Ethereum::Decoder.new
  end

  def formatter
    @formatter ||= Ethereum::Formatter.new
  end

  def block_number
    formatter.to_int(connection.eth_block_number["result"])
  end

  def transactions(address, size=500)
    end_block = block_number
    start_block = end_block - size;

    transactions = connection.batch do
      (start_block..end_block).map do |block_number|
        hex_block = "0x" + formatter.to_twos_complement(block_number)
        connection.eth_get_block_by_number(hex_block, true)
      end
    end.map{|b| b["result"]["transactions"]}.flatten

    select_transactions_by(address.downcase, transactions)
  end

  def transaction_info(txid)
    connection.eth_get_transaction_by_hash(txid)['result']
  end

  def transaction_receipt(txid)
    connection.eth_get_transaction_receipt(txid)['result']
  end

  def encrypt(string)
    crypter.encrypt_and_sign(string)
  end

  def decrypt(encrypted_data)
    crypter.decrypt_and_verify(encrypted_data)
  end

  def eth_block_number
    to_int(connection.eth_block_number["result"])
  end

  def to_int(eth_number)
    formatter.to_int(eth_number)
  end

  private

  def crypter
    ActiveSupport::MessageEncryptor.new(key)
  end

  #TODO: think we need to create other key for private keys encryption
  def key
    Rails.application.secrets.secret_key_base
  end

  def select_transactions_by(address, transactions)
    return [] unless transactions.any?
    transactions.select{|t| t["from"]&.downcase == address or t["to"]&.downcase == address}
  end
end
