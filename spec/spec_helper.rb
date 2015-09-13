$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'pry'
require 'factory_mom'

# FIXME to test FKs connection should be MySQL!
ActiveRecord::Base.establish_connection({
  adapter:  'sqlite3',
  database: './test.sqlite3'
})

Foreigner.load

ActiveRecord::Schema.define do
  create_table :users do |t|
    t.integer :id, null: false
    t.integer :parent_id
    t.string  :type, null: false
    t.string  :name, null: false
  end unless table_exists? :users
  create_table :posts do |t|
    t.integer :id, null: false
    t.integer :user_id
    t.string  :text, null: false
  end unless table_exists? :posts
  add_index :posts, :text unless index_exists? :posts, :text
  # FIXME RAILS4 add_foreign_key :posts, :users, column: :user_id unless foreign_key_exists? :posts, column: :user_id
  add_foreign_key :posts, :users, column: :user_id rescue nil
end

class User < ActiveRecord::Base
  has_many :posts
end

class Admin < User
  has_many :user, :foreign_key => 'parent_id'
end

class Post < ActiveRecord::Base
  has_one :user
end

User.delete_all
Post.delete_all

User.create({
  name: 'Aleksei'
})
Admin.create({
  name: 'Carles'
})
Post.create({
  user_id: User.find_by_name('Aleksei'),
  text: 'Lorem ipsum'
})
