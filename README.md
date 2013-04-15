# Mongoblazer

Flatten ActiveRecord related database data in (potentially huge) [Mongoid](http://mongoid.org) documents.

## Installation

Add this line to your application's Gemfile:

    gem 'mongoblazer'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mongoblazer

## Usage

```ruby
  class Post
    belongs_to :author, class_name: 'User'
    has_many :comments

	mongoblazer_includes              [:author, {comments: :user}]
    mongoblazer_additional_attributes [:path]

    after_save :mongoblaze!

    def path
      "/#{created_at.to_date.to_formatted_s(:db)}/#{slug}"
    end
  end
```

```ruby
  Post.last.mongoblazed
  # => <PostBlazer…
  
  Post.find_blazed(Post.select(:id).last).comments
  [<CommentBlazer..]
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
