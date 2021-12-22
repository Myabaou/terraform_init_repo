# Terraform 関連

## 前提条件
- `.terraform` 配下にモジュールがDLされるので`.gitignore_global`設定でignore推奨
- aws cliのバージョンが古いとうまくいかない。（幾つのバージョン以上からかは不明

## tfstate ファイル格納用S3バケット作成
- `_PROJECT`に何も指定していない場合、値が`AWS_PROFILE`と同じ値になる。
- S3バケットを削除する場合は空にしてから削除する必要があるが、空にするにはマネージメントコンソールから実施する必要がある。(CLIだとなぜかうまくいかない）
- 再作成は削除してからだいぶ経過しないと作成できない。


- init/plan

```sh
_AWS_PROFILE=aws_account_profile
PROJECT=sample_pj
make s3-tfstate-init AWS_PROFILE=${_AWS_PROFILE} _PROJECT=${PROJECT}
```

- apply(tfstateファイル格納用S3バケット作成)
```sh
make s3-tfstate-create
```

- 削除
すでにS3バケットにファイルが存在する場合は失敗する。（誤削除を防止するためあえてそのようにしている。）
```sh
make s3-tfstate-destroy
```


## 各環境用作成

- 個別（プロジェクト指定版）
```sh
_AWS_PROFILE=aws_account_profile
PROJECT=sample_pj
make tf-init AWS_PROFILE=${_AWS_PROFILE} _ENV=dev _PROJECT=${PROJECT}
```



- 全ての環境一括
```sh
_AWS_PROFILE=aws_account_profile
PROJECT=sample
for i in prd stg dev common
do
  make tf-init AWS_PROFILE=${_AWS_PROFILE} _ENV=${i} _PROJECT=${PROJECT}
done
```


- 本番　STG 開発　共通以外の環境で作成したい場合

```sh
_AWS_PROFILE=aws_account_profile
PROJECT=sample_pj
make tf-init AWS_PROFILE=${_AWS_PROFILE} _ENV=example _PROJECT=${PROJECT}
```
`environments`配下に`example`というディレクトリが生成される。

```s
environments
└── example
         ├── Makefile
         ├── backend.tf
         ├── main.tf
         ├── readme.md
         └── variables.tf
```
