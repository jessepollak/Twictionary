require 'pry'
module Twictionary
    class Scraper
        MAX_ATTEMPTS = 5

        def initialize
            @lists = [
                'Scobleizer/most-influential-in-tech',
                'Scobleizer/tech-news-people',
                'Scobleizer/tech-news-brands',
                'mashable/tech',
                'Scobleizer/tech-company-executives',
                'Scobleizer/tech-pundits',
                'courtenaybird/digital-and-social-media',
                'Scobleizer/programmers',
                'Scobleizer/tech-companies',
                'Scobleizer/tech-event-organizers',
                'angellist/angels'
            ]
            @queue = []
            @token_number = 0

            generate_twitter_client
        end

        def scrape
            users = Twictionary::Models::User.where(scraped: false).to_a
            count = 0
            users.each do |user|
                p "#{count}/#{users.length}"
                p user.name
                grab_timeline(user)
                count += 1
            end
        end

        def scrape_lists
            @lists.each do |list|
                num_attempts = 0
                user, slug = list.downcase.split('/')
                p user, slug
                begin
                    num_attempts += 1
                    users = @twitter.list_members(user, slug)
                rescue Twitter::Error::TooManyRequests => error
                    p "RATE LIMIT HIT: #{error.rate_limit.reset_in}"
                    raise if num_attempts > MAX_ATTEMPTS

                    if @queue.length == 3
                        # NOTE: Your process could go to sleep for up to 15 minutes but if you
                        # retry any sooner, it will almost certainly fail with the same exception.
                        sleep error.rate_limit.reset_in
                        @queue.shift
                        reset_client
                        all_tokens_used = false
                        retry
                    else
                        @queue.unshift({
                            token_number: @token_number,
                            wait_time: error.rate_limit.reset_in
                        }).sort! {|a,b| a[:wait_time] <= b[:wait_time] }
                        next_token
                        retry
                    end
            end
                save_users(users)
            end
        end

        private

            def next_token
                p "SWITCHING TOKENS!"
                if @queue.length == 3
                    @token_number = @queue[0][:token_number]
                else
                    @token_number = (@token_number + 1) %3
                end

                generate_twitter_client
            end

            def generate_twitter_client
                @twitter = Twitter::Client.new(
                    consumer_key: CONFIGS['twitter']['consumer_keys'][@token_number],
                    consumer_secret:  CONFIGS['twitter']['consumer_secrets'][@token_number],
                    oauth_token:  CONFIGS['twitter']['access_tokens'][@token_number],
                    oauth_token_secret:  CONFIGS['twitter']['access_token_secrets'][@token_number],
                )
            end

            def save_users(users)
                users.each do |user|
                    unless Twictionary::Models::User.where(screen_name: user.screen_name).exists?
                        Twictionary::Models::User.create(
                            screen_name: user.screen_name,
                            name: user.name,
                            uid: user.id,
                            followers_count: user.followers_count
                        )
                    end
                end
            end

            def save_tweets(tweets, user)
                tweets = tweets.collect do |t|
                    {
                        user: user.uid,
                        text: t.text,
                        date: t.created_at,
                        tid: t.id.to_s
                    }
                end
                Twictionary::Models::Tweet.collection.insert(tweets)
                user.scraped = true
                user.save
            end

            def grab_timeline(user)
                options = {
                    count: 200
                }

                tweets_to_save = []
                count = 0

                loop do
                    num_attempts = 0

                    begin
                        num_attempts += 1
                        tweets = @twitter.user_timeline(user.screen_name, options)
                    rescue Twitter::Error::TooManyRequests => error
                        p "RATE LIMIT HIT: #{error.rate_limit.reset_in}"

                        if @queue.length == 3
                            # NOTE: Your process could go to sleep for up to 15 minutes but if you
                            # retry any sooner, it will almost certainly fail with the same exception.
                            sleep(error.rate_limit.reset_in + 10)
                            @queue.shift
                            generate_twitter_client
                            retry
                        else
                            @queue.unshift({
                                token_number: @token_number,
                                wait_time: error.rate_limit.reset_in
                            }).sort! {|a,b| a[:wait_time] <=> b[:wait_time] }
                            next_token
                            retry
                        end
                    rescue Twitter::Error::ClientError
                        raise if num_attempts > MAX_ATTEMPTS
                        retry
                    end

                    tweets_to_save.concat tweets

                    count += tweets.length
                    p count
                    break if count >= 3200 || tweets.length < 200

                    options[:max_id] = tweets[-1].id - 1
                end


                save_tweets(tweets_to_save, user)
            end

    end
end