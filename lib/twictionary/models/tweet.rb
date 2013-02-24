require 'mongoid'

module Twictionary
    module Models
        class Tweet
            include Mongoid::Document
            field :user, type: String
            field :text, type: String
            field :date, type: DateTime

        end
    end
end