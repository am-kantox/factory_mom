---
name: FactoryMom
owner: Kantox LTD
tags: [rails, rspec, testing, factory]
is it of any good?: [Yes](http://news.ycombinator.com/item?id=3067434)
travis: [![Build Status](https://travis-ci.org/am-kantox/factory_mom.svg?branch=master)](https://travis-ci.org/am-kantox/factory_mom)
---

# FactoryMom

`FactoryMom` is a `Factory` for `FactoryGirl` factories. Yeah, I like how the phrase sounds. Syllabics in action.

#### Usage

In an ideal world, one just writes

```ruby
FactoryMom.define do
end
```
instead of all cumbersome `FactoryGirl` factories. The factories are to be created,
basing on:

* Rails reflections;
* ActiveRecord RDBMS queries;
* AR classes introspection;
* Retry on creation fail.

In a real world, with all pink unicorns gone, one needs to tune everything. `FactoryMom`
accepts a `FactoryGirl` syntax for that. The explicitly specified traits **take precedence**
over automatically generated:

```ruby
FactoryMom.define do
  factory :moderator, parent: :user, class_name: :moderator do
    trait :with_karma do
      karma { 200 }
    end
    title { 'Moderator' }
  end
end
```

The code is generated and evaluated in the context. All the factories for all the
`ActiveRecord::Base` descendants become available.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'factory_mom'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install factory_mom

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/factory_mom. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
