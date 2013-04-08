::ActiveRecord::Base.class_eval do
  include Mongoblazer::ActiveRecord
end

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => ':memory:'
)

ActiveRecord::Schema.define(:version => 0) do
  create_table "not_enableds" do |t|
    t.string "name"
  end

  create_table "enableds" do |t|
    t.string "name"
  end

  create_table "with_enabled_relations" do |t|
    t.string "name"
  end

  create_table "related_enableds" do |t|
    t.string "name"
    t.integer "with_enabled_relation_id"
  end

  create_table "posts" do |t|
    t.integer "enabled_id"
    t.integer "user_id"
    t.string "title"
    t.text "body"
    t.string "status"
  end

  add_index "posts", "status", name: "index_posts_on_status"

  create_table "comments" do |t|
    t.integer "post_id"
    t.integer "user_id"
    t.string "text"
  end

  create_table "users" do |t|
    t.string "name"
  end

  create_table "tags" do |t|
    t.string "name"
  end

  create_table "posts_tags", id: false do |t|
    t.integer "post_id"
    t.integer "tag_id"
  end
end

class NotEnabled < ActiveRecord::Base
end

class Enabled < ActiveRecord::Base
  has_many :posts

  mongoblazer_includes posts: [{comments: :user}, :tags]

  after_save :mongoblaze!
end

class EnabledInParent < Enabled
end

class WithEnabledRelation < ActiveRecord::Base
  has_many :related_enableds

  mongoblazer_includes :related_enableds

  after_save :mongoblaze!
end

class RelatedEnabled < ActiveRecord::Base
  belongs_to :with_enabled_relation

  mongoblazer_includes :with_enabled_relation
end

class DefaultScoped < Enabled
  default_scope where(foo: "bar")
end

class Post < ActiveRecord::Base
  belongs_to              :user
  has_many                :comments
  has_and_belongs_to_many :tags

  default_scope where(status: 'published')
end

class Comment < ActiveRecord::Base
  belongs_to :post
  belongs_to :user
end

class User < ActiveRecord::Base
  has_many :posts
  has_many :comments
end

class Tag < ActiveRecord::Base
  has_and_belongs_to_many :posts
end
