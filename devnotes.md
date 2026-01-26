# 開発忘備録

覚えておきたい開発時の事柄

## 配布用ファイル

[GitHub Actions CI/CD ワークフロー](https://packaging.python.org/ja/latest/guides/publishing-package-distribution-releases-using-github-actions-ci-cd-workflows/)を使わない場合には、自前で**配布用ファイル**を登録する。

### 配布用ファイルの作成

前提: Python仮想環境は適用済みであること。

~~~shell
cd derenotes
. venv/bin/activate

pip install setuptools build
python -m build
~~~

作成される配布用ファイル

- dist/packagename-\*.whl
- dist/packagename-\*.tar.gz

> `Cython` を使ったビルドにおいて、依存関係の解決に `setup.py` がまだ必要だった。

### 配布用ファイルの動作確認

配布用ファイルからインストール可能か確認する。

~~~shell
cd derenotes
. venv/bin/activate

pip install -e .
~~~

### githubへの登録

前提:　リポジトリ作成済みであること。リリース用のタグが付けてあること。

（省略）

---

## VSCodeのソース管理（github拡張）

VSCodeビルトインのソース管理と `git` コマンドとを対比しながら手順を示す。

## 前提条件

**githubアカウント**を取得済みであること。
ローカルに設定済みであること。

~~~shell
git config --global user.name [username]
git config --global user.email [useremail]
~~~

## githubアカウントの登録

~~~mermaid
---
title: VSCode
---

flowchart LR

id1["アカウント"]
id2["拡張機能アカウントの<br>ユーザー設定の管理..."]
id3["GitHub"]
id4["新しいアカウント<br>の使用"]

id1 --> id2 --> id3 --> id4
~~~

>　`git` コマンドはない。

### ローカルポジトリの作成

~~~mermaid
---
title: VSCode
---

flowchart LR

id1["ソース管理"]
id2["リポジトリを初期化する"]

id1 --> id2
~~~

~~~shell
mkdir [packagefolda]
cd [packagefolda]
git init
~~~

### ローカルリポジトリへのコミット

~~~mermaid
---
title: VSCode
---

flowchart LR

id1["ソース管理"]
id2["変更"]
id3["変更"]
id4["[プラスマーク]<br>（変更をステージ）"]

id5["ソース管理"]
id6["変更"]
id7["ステージされている変更"]
id8["✔コミット"]

id1 --> id2 --> id3 -- 対象を選択  --> id4

id5 --> id6 --> id7 -- メッセージを<br>入力 --> id8
~~~

> ソース管理のデフォルトブランチは、**main**です。
スパークルアイコンをクリックすることで、メッセージを自動生成することができる。

~~~shell
git add [filename]
git commit -m "コミットのコメント"
~~~

### ローカルレポジトリのブランチ変更

ローカルレポジトリのブランチ: **main**  (ソース管理のデフォルト)
ローカルレポジトリの変更先ブランチ: [newbranch]

~~~mermaid
---
title: VSCode
---

flowchart LR

id1["ソース管理"]
id2["リポジトリ"]
id3["[にプラスマーク]"<br>（main*,ブランチまたはタグのチェックアウト）]
id4["新しいブランチ<br>の作成..."]

id1 --> id2 --> id3 -- ブランチ名<br>を入力する --> id4
~~~

~~~shell
git branch [newbranch]
git switch [newbranch]
~~~

### リモートリポジトリの作成

VSCodeソース管理ではGitHubリポジトリ作成を開始できますが、gitコマンドでは無理の様です。
どちらにしても、GitHubリポジトリ作成自体はGitHubでの作業が必要です（多分）。

~~~mermaid
---
title: VSCode
---

flowchart LR

id1["ソース管理"]
id2["リポジトリ"]
id3["[雲にプラスマーク]<br>（GitHub に発行する）"]
id4["Publish to GitHub<br> private repository"]
id5["Publish to GitHub<br> public repository"]
id6["GitHub<br>で作業"]

id1 --> id2 --> id3 -- リポジトリ名<br>を入力する --> id4 & id5 --> id6
~~~

~~~shell
: リモートリポジトリを作成しておくこと

git remote add origin git@github.com:[username]/[repositoryname].git
~~~

> 以降は、リモートリポジトリのことを**origin**と指定する。

### リモートリポジトリへプッシュ

リモートリポジトリのブランチ: **origin** **master**
ローカルレポジトリのブランチ: **main** (ソース管理のデフォルト)

~~~mermaid
---
title: VSCode
---

flowchart LR

id1["ソース管理"]
~~~

~~~shell
git push origin master
~~~

### リモートリポジトリからプル

リモートリポジトリのブランチ: origin master
ローカルレポジトリのブランチ: main (ソース管理のデフォルト)

~~~mermaid
---
title: VSCode
---

flowchart LR

id1["ソース管理"]
id2["リポジトリ"]

id1 --> id2
~~~

~~~shell
git pull origin master
~~~

### タグ付け

リリースとか `GitHub actions` で参照することがあるので、付けといた方が良い。
