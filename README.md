# Dummy Blog

HTTPのリクエストとレスポンスを、telnetで一文字ずつ確かめるための小さなブログです。

ブラウザやHTTPクライアントに任せると見えにくい、次の要素を観察できます。

- リクエスト行、リクエストヘッダー、リクエストボディー
- `200 OK`、`201 Created`、`400 Bad Request`、`404 Not Found`、`405 Method Not Allowed`
- `Content-Type`、`Content-Length`、`Location`
- `application/x-www-form-urlencoded` 形式のPOST

実装にはRubyとSinatraを使っています。仕組みを追いやすくするため、データベース、認証、セッション、Cookie、JavaScriptは使っていません。

## まず動かしてみる

Ruby 4.0.5とBundlerを用意し、このリポジトリで次のコマンドを実行します。

```console
bundle install
bundle exec puma -C config/puma.rb
```

ブラウザで <http://localhost:3000/articles> を開くと、記事一覧が表示されます。

テストは別のターミナルから実行できます。

```console
bundle exec rake test
```

## ソースコードの読みどころ

このアプリの中心は [`app.rb`](app.rb) です。上から順に読むと、次の流れを追えます。

1. `INITIAL_ARTICLES` に、起動時から表示する記事を定義する
2. `get` や `post` で、URLとHTTPメソッドに対応する処理を定義する
3. POSTのリクエストボディーを読み、フォームデータへ変換する
4. 入力を検証して、記事配列へ追加する
5. ステータス、レスポンスヘッダー、HTMLを返す

主なファイルは次のとおりです。

| ファイル | 役割 |
| --- | --- |
| [`app.rb`](app.rb) | ルーティング、入力検証、記事の保存、HTTPレスポンス |
| [`views/`](views/) | レスポンスとして返すHTMLのテンプレート |
| [`public/style.css`](public/style.css) | ブログの見た目を整えるCSS |
| [`test/app_test.rb`](test/app_test.rb) | ステータス、ヘッダー、本文を確認する自動テスト |
| [`config/puma.rb`](config/puma.rb) | WebサーバーPumaの設定 |
| [`config.ru`](config.ru) | PumaからSinatraアプリを起動する入口 |
| [`Procfile`](Procfile) | Herokuで実行するコマンド |

### URLと処理の対応

| メソッドとURL | 処理 | 成功時のステータス |
| --- | --- | --- |
| `GET /articles` | 記事一覧を表示する | `200 OK` |
| `GET /articles/new` | 投稿フォームを表示する | `200 OK` |
| `GET /articles/:id` | 指定した記事を表示する | `200 OK` |
| `POST /articles` | 新しい記事を作成する | `201 Created` |

存在しないURLは `404 Not Found`、利用できないHTTPメソッドは `405 Method Not Allowed` になります。タイトルまたは本文が空のPOSTは `400 Bad Request` です。

### メモリ上の記事データ

記事は `settings.articles` という配列に保存されます。複数のリクエストが同時に来ても配列が壊れないように、読み書きは `Mutex` で保護しています。

データベースには保存しないため、PumaやDynoの再起動、Dynoのスリープ、デプロイなどで投稿はすべて消えます。その後は、`INITIAL_ARTICLES` にある固定記事だけの状態から始まります。これはこの教材の意図した動作です。

### 入力を安全に扱う仕組み

- タイトルと本文はHTMLへ出力するときにエスケープし、入力されたタグを実行させない
- タイトルまたは本文が空なら記事を作成しない
- リクエストボディーを16 KiBまでに制限する
- POSTは `application/x-www-form-urlencoded` だけを受け付ける

CSRFトークンは使っていません。認証やCookieを使わない教材用サイトで、telnetから単純なPOSTを送れるようにするためです。

## telnetでGETする

ローカルでPumaを起動した状態で、別のターミナルから接続します。

```console
telnet localhost 3000
```

接続後、次の内容を入力します。最後にもう一度Enterを押して、空行を送るのを忘れないでください。

```http
GET /articles HTTP/1.1
Host: localhost
Connection: close

```

レスポンスでは、次の部分を探してみてください。

```http
HTTP/1.1 200 OK
content-type: text/html;charset=utf-8
content-length: ...
```

ヘッダー名では大文字と小文字を区別しないため、環境によって `Content-Type` ではなく `content-type` のように表示されることがあります。

## telnetでPOSTする

POSTでは、ヘッダーの後にリクエストボディーを送ります。今回送るフォームデータは次の文字列です。

```text
title=Hello&body=HTTP
```

### Content-Lengthを計算する

`Content-Length`には文字数ではなく、リクエストボディーのバイト数を書きます。末尾に改行を加えない `printf %s` で計算できます。

```console
printf %s 'title=Hello&body=HTTP' | wc -c
```

結果は `21` です。日本語、空白、`&`などを送る場合は、先にURLエンコードし、エンコード後の文字列を同じ方法で数えます。

### POSTリクエストを送る

```console
telnet localhost 3000
```

接続後、次を入力します。ヘッダーとボディーの間には空行が1行あります。

```http
POST /articles HTTP/1.1
Host: localhost
Content-Type: application/x-www-form-urlencoded
Content-Length: 21
Connection: close

title=Hello&body=HTTP
```

成功すると、次のようなレスポンスが返ります。

```http
HTTP/1.1 201 Created
content-type: text/html;charset=utf-8
location: /articles/4
content-length: ...
```

`Location`は、作成した記事のURLを示しています。Pumaを再起動するまでは、`GET /articles/4`でも投稿した記事を確認できます。

## エラーレスポンスも試す

HTTPメソッドやURL、POSTデータを変えると、別のステータスを観察できます。

| 試すリクエスト | 確認できるレスポンス |
| --- | --- |
| `GET /articles/999` | `404 Not Found` |
| `DELETE /articles/1` | `405 Method Not Allowed`と`Allow`ヘッダー |
| `POST /articles`でタイトルを空にする | `400 Bad Request` |
| JSONを`POST /articles`へ送る | `400 Bad Request` |

リクエストを書き換える前に、`Content-Length`も実際のボディーに合わせて計算し直してください。

## Heroku上のサイトへtelnetで接続する

デプロイ済みのアプリでは、`APP_NAME.herokuapp.com`を実際のホスト名に置き換えます。

```console
telnet APP_NAME.herokuapp.com 80
```

```http
GET /articles HTTP/1.1
Host: APP_NAME.herokuapp.com
Connection: close

```

このアプリはHTTPSへの強制リダイレクトを設定していないため、80番ポートへ平文HTTPを送れます。

## 運用者向け: Herokuへデプロイする

[Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli)でログインし、`APP_NAME`を実際のアプリ名に置き換えて実行します。

```console
heroku git:remote --app APP_NAME
git push heroku main
heroku ps:scale web=1 --app APP_NAME
heroku ps --app APP_NAME
```

新しいアプリなら、先に `heroku create APP_NAME` を実行します。

Ecoプランを契約したアカウントでは、web Dynoを1つだけEcoで動かします。Heroku DashboardのResources画面でも、`web`が`Eco`、数量が`1`であることを確認してください。追加のDynoやAdd-onを作らなければ、アプリ側で発生する費用はEco Dynosプランの月額$5だけです。料金は変更される場合があるため、設定時にDashboardでも確認してください。

Pumaはworkerを作らないsingle modeで起動します。記事データを複数のRubyプロセスへ分散させないため、web Dynoの数量も必ず1にします。

## 運用者向け: 不要なHeroku Postgresを削除する

Postgresの削除後は、DB内のデータを復元できません。最初に対象アプリとAdd-on名を確認し、必要ならバックアップを取得します。

```console
heroku addons --app APP_NAME
heroku pg:backups:capture --app APP_NAME
heroku pg:backups:download --app APP_NAME
```

対象が正しいことを再確認してから削除します。`ADDON_NAME`には、`heroku addons`で表示された `heroku-postgresql-xxxxxxxx` のようなAdd-on名を指定します。

```console
heroku addons:destroy ADDON_NAME --app APP_NAME
heroku addons --app APP_NAME
```
