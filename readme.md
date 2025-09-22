# AWS Infrastructure Inventory & Diff Tool

AWS環境のインフラストラクチャ情報を取得し、変更前後の差分を詳細に比較するためのPowerShellツールセットです。

## 概要

このツールセットは以下の2つのスクリプトで構成されています：

- **InventorySnapshot.ps1**: AWS環境の各種リソース情報を取得してJSONファイルに保存
- **InventoryDiff.ps1**: 2つのスナップショット間の詳細な差分を比較・レポート

## 対応リソース

以下のAWSリソースの情報を取得・比較できます：

- **VPC関連**: VPCs, Subnets, Route Tables, Internet Gateways
- **ネットワーク**: NAT Gateways, VPC Peering Connections, VPC Endpoints
- **セキュリティ**: Security Groups, Network ACLs
- **EC2関連**: EC2 Instances, Key Pairs, AMIs, EBS Volumes, EBS Snapshots
- **ECS関連**: ECS Clusters, Services, Task Definitions
- **ロードバランサー**: Application Load Balancers (ALB), Network Load Balancers (NLB), Classic Load Balancers (CLB), Target Groups, Listeners, Target Health
- **その他**: Elastic IPs, DHCP Options, Managed Prefix Lists, VPN Gateways
- **VPC Lattice**: Services, Service Networks, Associations

## 前提条件

- PowerShell 5.1以上
- AWS CLI設定済み
- 適切なAWS権限（各リソースの読み取り権限）

## セットアップ

### 1. AWS認証情報の設定

MFAを使用している場合は、セッショントークンを取得して環境変数に設定：

```powershell
# セッショントークンを取得
aws sts get-session-token --profile your-profile --serial-number arn:aws:iam::123456789012:mfa/your-mfa-device --token-code 123456

# 環境変数に設定
$env:AWS_ACCESS_KEY_ID='AKIA...'
$env:AWS_SECRET_ACCESS_KEY='...'
$env:AWS_SESSION_TOKEN='...'
```

## 使用方法

### Step 1: 変更前のスナップショット取得

CloudFormationやTerraform実行前に現在の状態を取得：

```powershell
.\InventorySnapshot.ps1 -OutDir .\snap -Label pre_20250922
```

### Step 2: インフラ変更の実行

CloudFormation、Terraform、または手動でのAWSリソース変更を実行

### Step 3: 変更後のスナップショット取得

変更完了後に新しい状態を取得：

```powershell
.\InventorySnapshot.ps1 -OutDir .\snap -Label post_20250922
```

### Step 4: 差分比較とレポート生成

2つのスナップショット間の詳細な差分を比較：

```powershell
.\InventoryDiff.ps1 -BeforeDir .\snap\pre_20250922 -AfterDir .\snap\post_20250922 -OutReport .\snap\diff-report_20250922.txt
```

## パラメータ詳細

### InventorySnapshot.ps1

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| OutDir | ✓ | スナップショットファイルの保存先ディレクトリ |
| Label | ✓ | スナップショットを識別するラベル（ディレクトリ名として使用） |

### InventoryDiff.ps1

| パラメータ | 必須 | 説明 |
|-----------|------|------|
| BeforeDir | ✓ | 変更前のスナップショットディレクトリ |
| AfterDir | ✓ | 変更後のスナップショットディレクトリ |
| OutReport | ✓ | 差分レポートの出力ファイルパス |

## 出力例

差分レポートには以下の情報が含まれます：

```
=== managed_prefix_lists.json ===
  Changed : pl-088f6a61, pl-0e9bca5093b8dd7b8
    pl-088f6a61 details:
      AddressFamily: 'IPv6' -> 'IPv4'
    pl-0e9bca5093b8dd7b8 details:
      State: 'create-complet' -> 'create-complete'

=== vpc_peering_connections.json ===
  Added   : pcx-05ed2da07314329b2
  Removed : pcx-05eda07314329b2
```

## ディレクトリ構造

```
project/
├── InventorySnapshot.ps1    # スナップショット取得スクリプト
├── InventoryDiff.ps1        # 差分比較スクリプト
├── readme.md               # このファイル
├── .gitignore              # Git除外設定
└── snap/                   # スナップショット保存ディレクトリ（Git管理外）
    ├── pre_20250922/       # 変更前スナップショット
    ├── post_20250922/      # 変更後スナップショット
    └── diff-report_*.txt   # 差分レポート
```

## 注意事項

- スナップショット取得には数分かかる場合があります
- 大量のリソースがある環境では、出力ファイルサイズが大きくなる可能性があります
- AWS APIの制限により、取得に失敗する場合は時間をおいて再実行してください
- `snap/`ディレクトリの内容はGit管理対象外です

## トラブルシューティング

### よくある問題

1. **権限エラー**: 必要なAWS権限が不足している場合
   - 各リソースの`Describe*`権限を確認してください

2. **セッション期限切れ**: MFAセッションが期限切れの場合
   - 新しいセッショントークンを取得して環境変数を再設定してください

3. **ファイルアクセスエラー**: 出力ディレクトリが存在しない場合
   - 出力ディレクトリは自動作成されますが、親ディレクトリは事前に作成してください

## ライセンス

このツールはMITライセンスの下で提供されています。