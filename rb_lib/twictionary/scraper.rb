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
            @queue = [
                {
                    token_number: 1,
                    wait_time: 0
                },
                {
                    token_number: 2,
                    wait_time: 0
                },
                {
                    token_number: 3,
                    wait_time: 0
                },
                {
                    token_number: 4,
                    wait_time: 0
                }
            ]
            @token_number = 0
            @MAX_QUEUE_SIZE = CONFIGS['twitter']['consumer_keys'].length
            @num_tries = 0

            generate_twitter_client
        end

        def test
            binding.pry
            p @twitter
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

                    if @queue.length == @MAX_QUEUE_SIZE
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

            def next_token(error)
                @num_tries += 1
                p "SWITCHING TOKENS!"

                @queue.push({ token_number: @token_number, wait_time: error.rate_limit.reset_in })

                if @num_tries == 5
                    @queue.sort! {|a,b| a[:wait_time] <=> b[:wait_time]}
                    p @queue
                    sleep(@queue[0][:wait_time] + 10)
                    @num_tries = 0
                end

                @token_number = @queue.shift()[:token_number]
                # if @queue.length == @MAX_QUEUE_SIZE
                #     @token_number = @queue[0][:token_number]
                # else
                #     @token_number = ((0...@MAX_QUEUE_SIZE).to_a - @queue.collect {|el| el[:token_number] }).sample
                # end

                #         p "RATE LIMIT HIT: #{error.rate_limit.reset_in}"
                #         p @queue

                #         if @queue.length == @MAX_QUEUE_SIZE
                #             # NOTE: Your process could go to sleep for up to 15 minutes but if you
                #             # retry any sooner, it will almost certainly fail with the same exception.
                #             sleep(error.rate_limit.reset_in + 10)
                #             @queue.delete_if {|el| el[:token_number] == @token_number}
                #             generate_twitter_client
                #             retry
                #         else
                #             @queue.push({
                #                 token_number: @token_number,
                #                 wait_time: error.rate_limit.reset_at
                #             }).sort! {|a,b| a[:wait_time] <=> b[:wait_time]}
                #             next_token
                #             retry
                #         end

                # p @token_number
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
                        @num_tries = 0
                    rescue Twitter::Error::TooManyRequests => error
                        # p "Start again in #{error.rate_limit.reset_in}"
                        # sleep(error.rate_limit.reset_in + 10)
                        next_token(error)
                        retry
                    rescue Twitter::Error::Unauthorized
                        user.delete
                        next
                    rescue
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