require 'yaml'
require 'twitter'

require 'twictionary/models/tweet'
require 'twictionary/models/user'
require 'twictionary/scraper'


configs = YAML.load_file('settings.yml')

Twitter.configure do |config|
    config.consumer_key = configs['twitter']['consumer_key']
    config.consumer_secret = configs['twitter']['consumer_secret']
    config.oauth_token = configs['twitter']['access_token']
    config.oauth_token_secret = configs['twitter']['access_token_secret']
end
Mongoid.load!("mongoid.yml", configs['environment'].to_sym)

module Twictionary
end