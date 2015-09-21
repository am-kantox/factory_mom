$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'pry'
require 'factory_girl_rails'
require 'factory_mom'

ActiveRecord::Base.logger = Logger.new(STDOUT)

# FIXME to test FKs connection should be MySQL!
ActiveRecord::Base.establish_connection({
  adapter:  'sqlite3',
  database: './test.sqlite3'
})

Foreigner.load

ActiveRecord::Schema.define do
  if ENV['RECREATE_TABLES']
    drop_table :comments if table_exists? :comments
    drop_table :posts if table_exists? :posts
    drop_table :users if table_exists? :users
  end

  create_table :users do |t|
    t.integer :id, null: false
    t.integer :parent_id
    t.string  :type, default: 'User'
    t.string  :name, limit: 16, null: false
  end unless table_exists? :users
  create_table :posts do |t|
    t.integer :id, null: false
    t.integer :user_id, null: false
    t.string  :title
    t.string  :text, null: false
  end unless table_exists? :posts
  create_table :comments do |t|
    t.integer :id, null: false
    t.integer :author_id #, null: false
    t.integer :post_id, null: false
    t.string  :notice, limit: 16
    t.string  :text
  end unless table_exists? :comments

  add_index :posts, :text unless index_exists? :posts, :text
  add_index :comments, :text unless index_exists? :comments, :text

  # FIXME RAILS4 add_foreign_key :posts, :users, column: :user_id unless foreign_key_exists? :posts, column: :user_id
  add_foreign_key :posts, :users, column: :user_id rescue nil
  add_foreign_key :comments, :users, column: :author_id rescue nil
  add_foreign_key :comments, :posts, column: :post_id rescue nil
end

class User < ActiveRecord::Base
  has_many :posts, inverse_of: :author
end

class Writer < User
  belongs_to :moderator, class_name: 'User', foreign_key: 'parent_id'
end

class Post < ActiveRecord::Base
  belongs_to :author, class_name: 'User', foreign_key: 'user_id'
  has_many :comments
end

class Comment < ActiveRecord::Base
  belongs_to :post, foreign_key: 'post_id'
  belongs_to :author, class_name: 'Writer', foreign_key: 'author_id'
  has_one :poster, source: :author, through: :post
end

Comment.delete_all
Post.delete_all
User.delete_all

User.create({
  name: 'Carles'
})
Writer.create({
  name: 'Ulises',
  parent_id: User.find_by_name('Carles').id
})
Post.create({
  user_id: User.find_by_name('Carles').id,
  title: 'Post #1',
  text: 'Lorem ipsum'
})
Comment.create({
  author_id: User.find_by_name('Ulises').id,
  post_id: Post.find_by_title('Post #1').id,
  text: 'Lorem commentum'
})
# binding.pry
