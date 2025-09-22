Param(
  [Parameter(Mandatory=$true)] [string]$BeforeDir,
  [Parameter(Mandatory=$true)] [string]$AfterDir,
  [Parameter(Mandatory=$true)] [string]$OutReport
)

# 比較対象ファイル一覧
$files = @(
  'vpcs.json',
  'subnets.json',
  'route_tables.json',
  'internet_gateways.json',
  'dhcp_options.json',
  'elastic_ips.json',
  'managed_prefix_lists.json',
  'managed_prefix_list_entries.json',
  'nat_gateways.json',
  'vpc_peering_connections.json',
  'network_acls.json',
  'security_groups.json',
  'vpc_endpoints.json',
  'vpc_endpoint_service_configurations.json',
  'vpc_endpoint_service_permissions.json',
  'vpc_lattice_services.json',
  'vpc_lattice_service_networks.json',
  'vpc_lattice_service_network_vpc_associations.json',
  'vpn_gateways.json'
)

# リソースIDの抽出ロジック
$idSelectors = @{
  'vpcs.json'                                         = @{ Path='Vpcs'; Id='VpcId' }
  'subnets.json'                                      = @{ Path='Subnets'; Id='SubnetId' }
  'route_tables.json'                                 = @{ Path='RouteTables'; Id='RouteTableId' }
  'internet_gateways.json'                            = @{ Path='InternetGateways'; Id='InternetGatewayId' }
  'dhcp_options.json'                                 = @{ Path='DhcpOptions'; Id='DhcpOptionsId' }
  'elastic_ips.json'                                  = @{ Path='Addresses'; Id='AllocationId' }   # 無ければ後で PublicIp
  'managed_prefix_lists.json'                         = @{ Path='PrefixLists'; Id='PrefixListId' }
  'managed_prefix_list_entries.json'                  = @{ Path=''; Id='PrefixListId' }
  'nat_gateways.json'                                 = @{ Path='NatGateways'; Id='NatGatewayId' }
  'vpc_peering_connections.json'                      = @{ Path='VpcPeeringConnections'; Id='VpcPeeringConnectionId' }
  'network_acls.json'                                 = @{ Path='NetworkAcls'; Id='NetworkAclId' }
  'security_groups.json'                              = @{ Path='SecurityGroups'; Id='GroupId' }
  'vpc_endpoints.json'                                = @{ Path='VpcEndpoints'; Id='VpcEndpointId' }
  'vpc_endpoint_service_configurations.json'          = @{ Path='ServiceConfigurations'; Id='ServiceId' }
  'vpc_endpoint_service_permissions.json'             = @{ Path=''; Id='ServiceId' }
  'vpc_lattice_services.json'                         = @{ Path='Items'; Id='Id' }
  'vpc_lattice_service_networks.json'                 = @{ Path='Items'; Id='Id' }
  'vpc_lattice_service_network_vpc_associations.json' = @{ Path=''; Id='ServiceNetworkId' }
  'vpn_gateways.json'                                 = @{ Path='VpnGateways'; Id='VpnGatewayId' }
}

# ---------- ユーティリティ ----------
function Read-JsonSafe {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  try {
    $rawText = Get-Content -LiteralPath $Path -Encoding UTF8 -Raw
    if ([string]::IsNullOrWhiteSpace($rawText)) { return $null }
    return ($rawText | ConvertFrom-Json -ErrorAction Stop)
  } catch { return $null }
}

function As-Array { param($x)
  if ($null -eq $x) { return @() }
  if ($x -is [System.Collections.IEnumerable] -and -not ($x -is [string])) { return @($x) }
  return @($x)
}

# Route正規化のキー
function Rt-RouteKey($r) {
  $dst = $r.DestinationCidrBlock
  if (-not $dst) { $dst = $r.DestinationIpv6CidrBlock }
  if (-not $dst) { $dst = $r.DestinationPrefixListId }
  $t = $r.GatewayId
  if (-not $t) { $t = $r.NatGatewayId }
  if (-not $t) { $t = $r.TransitGatewayId }
  if (-not $t) { $t = $r.VpcPeeringConnectionId }
  if (-not $t) { $t = $r.NetworkInterfaceId }
  if (-not $t) { $t = $r.EgressOnlyInternetGatewayId }
  if (-not $t) { $t = $r.InstanceId }
  if (-not $t) { $t = $r.CarrierGatewayId }
  return "$dst|$t"
}
function Rt-AssocKey($a) {
  if ($a.Main -eq $true) { return "MAIN" }
  if ($a.SubnetId) { return "SUBNET:$($a.SubnetId)" }
  if ($a.RouteTableAssociationId) { return "ASSOC:$($a.RouteTableAssociationId)" }
  return "Z"
}

# ---------- 正規化 (ファイル別の特例あり) ----------
function To-CanonicalJson {
  param([object]$obj, [string]$currentFile = '')

  function Normalize([object]$o, [string]$path='') {
    if ($null -eq $o) { return $null }

    # PSCustomObject を最優先で辞書化
    if ($o -is [pscustomobject]) {
      $ht = @{}
      foreach ($p in ($o.PSObject.Properties.Name | Sort-Object)) {
        $val = $o.$p

        # route_tables.json: Routes/Associations を順序無視でキーソート
        if ($currentFile -match 'route_tables\.json$') {
          if ($p -eq 'Routes' -and $val) {
            $arr = @(As-Array $val | Sort-Object { Rt-RouteKey $_ })
            $ht[$p] = @( $arr | ForEach-Object { Normalize $_ "$path.$p" } )
            continue
          }
          if ($p -eq 'Associations' -and $val) {
            $arr = @(As-Array $val | Sort-Object { Rt-AssocKey $_ })
            $ht[$p] = @( $arr | ForEach-Object { Normalize $_ "$path.$p" } )
            continue
          }
        }

        $ht[$p] = Normalize $val "$path.$p"
      }
      return $ht
    }

    # IDictionary
    if ($o -is [System.Collections.IDictionary]) {
      $ht = @{}
      foreach ($k in ($o.Keys | Sort-Object)) {
        $ht[$k] = Normalize $o[$k] "$path.$k"
      }
      return $ht
    }

    # 配列（基本は順序維持。上で特定配列はソート済み）
    if ($o -is [System.Collections.IEnumerable] -and -not ($o -is [string])) {
      return @($o | ForEach-Object { Normalize $_ $path })
    }

    # スカラー
    return $o
  }

  $norm = Normalize $obj
  return ($norm | ConvertTo-Json -Depth 100 -Compress)
}

# ---------- アイテム読み込み（route_tables の重複統合を含む） ----------
function Load-Items {
  param([string]$path, [string]$containerPath, [string]$idKey)

  $raw = Read-JsonSafe $path
  if ($null -eq $raw) { return @{} }

  $items = if ($containerPath) { $raw.$containerPath } else { $raw }

  # route_tables.json: 同一 RouteTableId を統合（Routes/Associations を結合）
  if ($path.ToLower().EndsWith('route_tables.json')) {
    $merged = @{}
    foreach ($rt in (As-Array $items)) {
      $id = $rt.RouteTableId
      if (-not $id) { continue }
      if (-not $merged.ContainsKey($id)) {
        # 深いコピー（簡易）
        $merged[$id] = [pscustomobject]@{
          Associations = @(As-Array $rt.Associations)
          PropagatingVgws = @(As-Array $rt.PropagatingVgws)
          RouteTableId = $rt.RouteTableId
          Routes = @(As-Array $rt.Routes)
          Tags = @(As-Array $rt.Tags)
          VpcId = $rt.VpcId
          OwnerId = $rt.OwnerId
        }
      } else {
        $merged[$id].Routes       += (As-Array $rt.Routes)
        $merged[$id].Associations += (As-Array $rt.Associations)
        # 他フィールドは先勝ちで保持（必要ならマージポリシーを拡張）
      }
    }
    return $merged
  }

  # vpc_endpoint_service_permissions.json / managed_prefix_list_entries.json / lattice SN-VPC associations の特例
  if ($path.ToLower().EndsWith('vpc_endpoint_service_permissions.json')) {
    $map = @{}
    foreach ($svc in (As-Array $items)) {
      $id = $svc.ServiceId
      if ($id) { $map[$id] = $svc }
    }
    return $map
  }
  if ($path.ToLower().EndsWith('managed_prefix_list_entries.json')) {
    $map = @{}
    foreach ($pl in (As-Array $items)) {
      $id = $pl.PrefixListId
      if ($id) { $map[$id] = $pl }
    }
    return $map
  }
  if ($path.ToLower().EndsWith('vpc_lattice_service_network_vpc_associations.json')) {
    $map = @{}
    foreach ($sn in (As-Array $items)) {
      foreach ($x in (As-Array $sn.Items)) {
        $id = $x.AssociationId
        if ($id) { $map[$id] = $x }
      }
    }
    return $map
  }

  # 通常：指定IDでマップ
  $map2 = @{}
  foreach ($it in (As-Array $items)) {
    $id = $null
    if ($idKey) { $id = $it.$idKey }
    if (-not $id -and $path.ToLower().EndsWith('elastic_ips.json')) {
      $id = $it.PublicIp
    }
    if ($id) { $map2[$id] = $it }
  }
  return $map2
}

# ---------- 比較 ----------
$report = New-Object System.Collections.Generic.List[string]

foreach ($f in $files) {
  $sel = $idSelectors[$f]
  $beforePath = Join-Path $BeforeDir $f
  $afterPath  = Join-Path $AfterDir  $f

  $before = Load-Items -path $beforePath -containerPath $sel.Path -idKey $sel.Id
  $after  = Load-Items -path $afterPath  -containerPath $sel.Path -idKey $sel.Id

  $beforeIds = $before.Keys
  $afterIds  = $after.Keys

  $added   = $afterIds | Where-Object { $_ -notin $beforeIds }
  $removed = $beforeIds | Where-Object { $_ -notin $afterIds }
  $common  = $beforeIds | Where-Object { $_ -in $afterIds }

  $changed = @()
  foreach ($id in $common) {
    $b = To-CanonicalJson -obj $before[$id] -currentFile $f
    $a = To-CanonicalJson -obj $after[$id]  -currentFile $f
    if ($b -ne $a) { $changed += $id }
  }

  $report.Add("=== $f ===")
  if ($added)   { $report.Add("  Added   : " + ($added -join ', ')) }
  if ($removed) { $report.Add("  Removed : " + ($removed -join ', ')) }
  if ($changed) { $report.Add("  Changed : " + ($changed -join ', ')) }
  if (-not $added -and -not $removed -and -not $changed) { $report.Add("  No differences") }
  $report.Add("")
}

$report | Out-File -FilePath $OutReport -Encoding utf8
Write-Host "Diff report written: $OutReport"
