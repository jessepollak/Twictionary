module Twictionary
    class Scraper
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
        end

        def scrape
            users = Twictionary::Models::User.all.to_a
            users[0..0].each do |user|
                p Twitter.user_timeline(user.screen_name, count: 200).count
            end
        end

        def scrape_lists
            @lists.each do |list|
                p list
                user, slug = list.downcase.split('/')
                users = Twitter.list_members(user, slug)
                save_users(users)
                p "users saved!"
            end
        end

        private

            def save_users(users)
                users.each do |user|
                    Twictionary::Models::User.create(
                        screen_name: user.screen_name,
                        name: user.name,
                        uid: user.id,
                        followers_count: user.followers_count
                    )
                end
            end
    end
end