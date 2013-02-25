require 'mongoid'

module Twictionary
    module Models
        class Tweet
            include Mongoid::Document
            field :user, type: String
            field :text, type: String
            field :date, type: DateTime
            field :tid, type: String

            index user: 1
            index({tid: 1}, {unique: true})
        end
    end
end