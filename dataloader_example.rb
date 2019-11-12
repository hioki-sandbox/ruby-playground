require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'
  gem 'dataloader'
  gem 'sqlite3'
  gem 'activerecord', require: 'active_record'
end

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

# Define and execute Migration
Class.new(ActiveRecord::Migration[5.2]) do
  def self.up
    create_table :foos do |t|
    end

    create_table :bars do |t|
      t.bigint :foo_id
    end
  end
end.migrate(:up)

# Define Models
class Foo < ActiveRecord::Base
  has_many :bars
end
class Bar < ActiveRecord::Base
  belongs_to :foo
end

# Create records
5.times do
  foo = Foo.create
  Bar.create(foo_id: foo.id)
end

# Define Dataloaders
foo_loader = Dataloader.new do |ids|
  Foo.find(*ids)
end

bar_loader = Dataloader.new do |foo_ids|
  result = {}
  Bar.where(foo_id: foo_ids).each do |bar|
    result[bar.id] = bar
  end
  foo_ids.each do |foo_id|
    result[foo_id] ||= nil
  end
  result
end

ActiveRecord::Base.logger = Logger.new(STDOUT)

puts 'A' * 80

foo_p1 = foo_loader.load(1)
foo_p2 = foo_loader.load(2)
foo_p3 = foo_loader.load_many([3, 4])

puts 'B' * 80

foo1 = foo_p1.sync
foo2 = foo_p2.sync
foo3, foo4 = foo_p3.sync

puts 'C' * 80

bar_p1 = bar_loader.load_many([foo1, foo2, foo3, foo4].map(&:id))

puts 'D' * 80

bar1, bar2 = bar_p1.sync

puts 'E' * 80

p bar1, bar2

# $ ruby dataloader_example.rb
# ==  : migrating ===============================================================
# -- create_table(:foos)
#    -> 0.0010s
# -- create_table(:bars)
#    -> 0.0002s
# ==  : migrated (0.0013s) ======================================================
#
# AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
# BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB
# D, [2019-11-13T05:38:34.285368 #71331] DEBUG -- :   Bar Load (0.1ms)  SELECT "bars".* FROM "bars" WHERE 1=0
# D, [2019-11-13T05:38:34.286507 #71331] DEBUG -- :   Foo Load (0.1ms)  SELECT "foos".* FROM "foos" WHERE "foos"."id" IN (?, ?, ?, ?)  [["id", 1], ["id", 2], ["id", 3], ["id", 4]]
# CCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCC
# DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD
# D, [2019-11-13T05:38:34.287451 #71331] DEBUG -- :   Bar Load (0.1ms)  SELECT "bars".* FROM "bars" WHERE "bars"."foo_id" IN (?, ?, ?, ?)  [["foo_id", 1], ["foo_id", 2], ["foo_id", 3], ["foo_id", 4]]
# EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
# #<Bar id: 1, foo_id: 1>
# #<Bar id: 2, foo_id: 2>
