# README

ここでは rsila6 + rspec 環境で DB 内容を csv 出力するメソッドを作成する。  
そして、このメソッドの rspec をどの様に書いていくかを試して行きます。

## rails6 + rspec 環境の構築

rails6 + rspec 環境の作成については以下を参照すること。

- <https://blog.jnito.com/entry/2019/10/25/053521>  
  Everyday RailsのサンプルアプリをRails 6で動かす際に必要なテストコードの変更点

- <https://matthewhoelter.com/2019/09/12/setting-up-and-testing-rails-6.0-with-rspec-factorybot-and-devise.html>  
  Setup and test Rails 6.0 with RSpec, FactoryBot, and Devise

- <https://qiita.com/sk4/items/9547a8b082e741c88589>  
  新規Railsプロジェクト作成手順(Rails 6)

- <https://qiita.com/Ushinji/items/522ed01c9c14b680222c>  
  RailsアプリへのRspecとFactory_botの導入手順

完全な操作履歴ではないが、次のような手順でおこなうことができる。

ruby と rails のインストール。
```bash
$rbenv local 2.7.1
ruby 2.7.1p83 (2020-03-31 revision a0c7c23c9c) [x86_64-darwin19]

$gem install rails
$rails -v
Rails 6.0.3.2

$gem install bundler
$bundle -v
Bundler version 2.1.4
```

rspec の導入
```bash
$bundle install
$rails new rail6-with_rspec -B --skip-test
```

Gemfile 修正
```ruby
group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console                                                                   
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'rspec-rails', '~> 4.0.0.beta2'
  gem 'factory_bot_rails'
  gem 'webdrivers'
  gem 'shoulda-matchers'
end
```

rails の起動
```bash
$bundle install
$rails g rspec:install
$bundle exec rails db:create
$bundle exec rails db:migrate
$bundle exec rails s
```
product モデルに to_csv_by_sql() と to_csv() メソッドを作った。  
to_csv_by_sql() は SQL 文で csv 出力してしまうものです。  
to_csv() は ActiveRecord::Relation を in_batch で回して CSV ファイルに書き込んでいくというものです。  

メモリ上の変数や ActoveRecord で取得した レコード内容は eq などで値をチェックして行くことができます。  
外部ファイル出力結果をどうやって rspec でテストするかをここで示します。  


参考情報
- <https://github.com/samg/diffy>  
   Diffy - Easy Diffing With Ruby

- <https://www.altova.com/blog/how-to-compare-csv-files/>
  HOW TO COMPARE CSV FILES OR COMPARE A CSV FILE TO A DATABASE TABLE


## 時間の操作

参考情報
- <https://www.ryotaku.com/entry/2019/08/27/000000>  
  現在日時をズラしたテストが実行できる「TimeHelpers（travel・travel_back・travel_to）」

- <https://himakuro.com/modify-timezone-to-jst-in-rails#i-4>  
  Railsのtime_zoneを変更する

## DB の id をリセットする

- <https://medium.com/@tiffanytang_30644/how-to-reset-your-activerecord-postgresql-and-sqlite-id-sequences-with-a-simple-ruby-gem-15b90c6fbdac>  
  How to Reset Your ActiveRecord PostgreSQL and SQLite ID Sequences with a Simple Ruby Gem

