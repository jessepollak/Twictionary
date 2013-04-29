require 'yaml'
require 'twitter'

require 'twictionary/models/tweet'
require 'twictionary/models/user'
require 'twictionary/scraper'


CONFIGS = YAML.load_file('settings.yml')


Mongoid.load!("mongoid.yml", CONFIGS['environment'].to_sym)

module Twictionary
    ACCESS_TOKENS = CONFIGS['twitter']['access_tokens']
    ACCESS_TOKEN_SECRETS = CONFIGS['twitter']['access_token_secrets']
end