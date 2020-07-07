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

### ファイル出力内容のテスト

projects テーブルの内容を ctiverEcord や CSV クラスをつかって次のように実装しているメソッドがあります。

```
  def self.to_csv
    headers = %w[id name description]
    File.open(csv_name, 'w:UTF-8') do |file|
      file.write BOM

      csv = CSV.new(file, headers: headers, write_headers: true)
      Project.order(:id).in_batches.each_record do |row|
        csv << [row.id, row.name, row.description]
      end
    end
  end
```

このメソッドが生成するファイル内容をチェックするテストを２つ書きました。  
1 つは、 File を一括読み込みしてその内容をチェックするものです。  
もう一つは、File への書き込処理を mock にして メモリー上にファイル内容を保持するようにして、そお内容をチェックするものです。  

ファイルを実際に読み混んで内容をチェックするには次のようにします。
```
expect(File.read(Project.csv_name)).to eq expect_lines
```

ファイルへ書き込まず、メモリー上へ書き込むようにするには次のようにします。
```
      before do
        allow(File).to receive(:open)
          .with(Project.csv_name, 'w:UTF-8')
          .and_yield(buffer)
      end
```
ファイル名 "Project.csv_name" への書き込みは、ファイルでなく
let(:buffer) { StringIO.new } へ書き込まえることになります。  

buffer へ書き込まれた内容のチェックは,次のように行います。
```
      it 'contents of csv file' do
        subject
        expect(buffer.string).to eq expect_lines
      end
```
この方法では、時間がかかるファイル IO を回避できるし、生成されたファイルの後始末も不要になります。  


参考情報
- <https://github.com/samg/diffy>  
   Diffy - Easy Diffing With Ruby

- <https://www.altova.com/blog/how-to-compare-csv-files/>
  HOW TO COMPARE CSV FILES OR COMPARE A CSV FILE TO A DATABASE TABLE

## 時間の操作

to_csv() メソッドで生成する csv ファイル名には、実機日時が埋め込まれるようになっています。  
テスト実機の度に日時は変化します。そのようなものをテストするんは大変です。  
実行日時を任意の日時に設定したら、時間を止めてしまう応報があります。  
これを利用すると、出力ファイル名を一定にすることができます。

参考情報
- <https://www.ryotaku.com/entry/2019/08/27/000000>  
  現在日時をズラしたテストが実行できる「TimeHelpers（travel・travel_back・travel_to）」

- <https://himakuro.com/modify-timezone-to-jst-in-rails#i-4>  
  Railsのtime_zoneを変更する

## DB の id をリセットする

csv ファイルには、 record id が含まれています。  
通常は, レコードの id はテスト実機の度に変化してしまいます。  
テーブルの Primary Key をリセットすることができれば、テスト処理中に生成されるレコードの id を一定にすることができます。

==> DB を sqlite3 -> MySQL に変更した。 
すると, MySQL の場合 primary_key リセットがうまくできなかった。
primary_key リセットはあきらめて、テスト時の expected の値の id を DB 情報から取得する様に変更した。

参考情報
- <https://medium.com/@tiffanytang_30644/how-to-reset-your-activerecord-postgresql-and-sqlite-id-sequences-with-a-simple-ruby-gem-15b90c6fbdac>  
  How to Reset Your ActiveRecord PostgreSQL and SQLite ID Sequences with a Simple Ruby Gem

### Mysql について

参考情報
- <https://weblabo.oscasierra.net/mysql-select-into-outfile/>  
  MySQLのSELECT結果をCSVファイルで出力する方法

標準設定のままだと, SQL で CSV 出力させようとすると  
"he MySQL server is running with the –secure-file-priv option so it cannot execute this statement"  
のエラーになる。  
my.ini の編集が必要になる。  

### 

- <https://www.techscore.com/blog/2017/12/04/fast_and_low-load_processing_method_when_exporting_csv_from_db_with_rails/>  
  RailsでDBからCSVエクスポートする時に高速かつ低負荷な処理方法とは？

- <https://tech.recruit-mp.co.jp/server-side/post-19614/>  
  Railsアプリの処理を100倍以上に高速化して得られた知見


### CSV 出力のパフォーマンス

大容量データを SQL 出力する際の実装によるパフォーマンス比較をしていく。
ますは、大量データを作成する rkae task に作成をする。  
そして、そのデータを使って csv 出力の速度・メモリー量などを計測するテストを作る。  
(実際の DB では複数のテーブルが関連して N+1 問題が発声したりする。  
こっこでは、まずは 1 テーブルの出力において、実装の差がパフォーマンスに与える影響を示していく)

- 100万件データ作成をする rake task 

insert_all! をつかって 10000  レコードずつ SQL 発行している （百万件なら 100 回の SQL)

```bash
$time rake "make_big_db:projects[1000000]"
#-- created 1000000 recoreds.

real	1m5.553s
user	0m54.452s
sys	0m1.402s
```

```bash
$rails c
Loading development environment (Rails 6.0.3.2)
[1] pry(main)> Project.count
   (0.4ms)  SET NAMES utf8mb4,  @@SESSION.sql_mode = CONCAT(CONCAT(@@sql_mode, ',STRICT_ALL_TABLES'), ',NO_AUTO_VALUE_ON_ZERO'),  @@SESSION.sql_auto_is_null = 0, @@SESSION.wait_timeout = 2147483
   (22.0ms)  SELECT COUNT(*) FROM `projects`
=> 1000000
[2] pry(main)> Project.first
  Project Load (0.3ms)  SELECT `projects`.* FROM `projects` ORDER BY `projects`.`id` ASC LIMIT 1
=> #<Project:0x00007fd11877d5f8
 id: 1,
 name: "Project 1",
 description: "Test project 1",
 due_on: nil,
 created_at: Tue, 07 Jul 2020 17:36:20 JST +09:00,
 updated_at: Tue, 07 Jul 2020 17:36:20 JST +09:00>
```


参考情報
- <https://qiita.com/taiteam/items/1b1be0578d1dc6e00a17>  
  Rails6.0におけるbulk insert

