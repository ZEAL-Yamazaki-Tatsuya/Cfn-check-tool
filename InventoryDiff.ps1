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
  'vpn_gateways.json',
  'ec2_instances.json',
  'ec2_key_pairs.json',
  'ec2_images.json',
  'ec2_volumes.json',
  'ec2_snapshots.json',
  'ecs_clusters.json',
  'ecs_services.json',
  'ecs_task_definitions.json',
  'load_balancers.json',
  'target_groups.json',
  'load_balancer_listeners.json',
  'target_health.json',
  'classic_load_balancers.json',
  'iam_users.json',
  'iam_user_policies.json',
  'iam_groups.json',
  'iam_group_policies.json',
  'iam_roles.json',
  'iam_role_policies.json',
  'iam_managed_policies.json',
  'iam_policy_versions.json',
  'iam_instance_profiles.json',
  'iam_saml_providers.json',
  'iam_saml_provider_details.json',
  'iam_oidc_providers.json',
  'iam_oidc_provider_details.json'
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
  'ec2_instances.json'                                = @{ Path='Reservations'; Id='InstanceId' }
  'ec2_key_pairs.json'                                = @{ Path='KeyPairs'; Id='KeyName' }
  'ec2_images.json'                                   = @{ Path='Images'; Id='ImageId' }
  'ec2_volumes.json'                                  = @{ Path='Volumes'; Id='VolumeId' }
  'ec2_snapshots.json'                                = @{ Path='Snapshots'; Id='SnapshotId' }
  'ecs_clusters.json'                                 = @{ Path='clusters'; Id='clusterArn' }
  'ecs_services.json'                                 = @{ Path=''; Id='serviceArn' }
  'ecs_task_definitions.json'                         = @{ Path=''; Id='taskDefinitionArn' }
  'load_balancers.json'                               = @{ Path='LoadBalancers'; Id='LoadBalancerArn' }
  'target_groups.json'                                = @{ Path='TargetGroups'; Id='TargetGroupArn' }
  'load_balancer_listeners.json'                      = @{ Path=''; Id='ListenerArn' }
  'target_health.json'                                = @{ Path=''; Id='TargetGroupArn' }
  'classic_load_balancers.json'                       = @{ Path='LoadBalancerDescriptions'; Id='LoadBalancerName' }
  'iam_users.json'                                    = @{ Path='Users'; Id='UserName' }
  'iam_user_policies.json'                            = @{ Path=''; Id='UserName' }
  'iam_groups.json'                                   = @{ Path='Groups'; Id='GroupName' }
  'iam_group_policies.json'                           = @{ Path=''; Id='GroupName' }
  'iam_roles.json'                                    = @{ Path='Roles'; Id='RoleName' }
  'iam_role_policies.json'                            = @{ Path=''; Id='RoleName' }
  'iam_managed_policies.json'                         = @{ Path='Policies'; Id='Arn' }
  'iam_policy_versions.json'                          = @{ Path=''; Id='PolicyArn' }
  'iam_instance_profiles.json'                        = @{ Path='InstanceProfiles'; Id='InstanceProfileName' }
  'iam_saml_providers.json'                           = @{ Path='SAMLProviderList'; Id='Arn' }
  'iam_saml_provider_details.json'                    = @{ Path=''; Id='Arn' }
  'iam_oidc_providers.json'                           = @{ Path='OpenIDConnectProviderList'; Id='Arn' }
  'iam_oidc_provider_details.json'                    = @{ Path=''; Id='Arn' }
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

# ---------- 詳細差分比較 ----------
function Compare-ObjectDetails {
  param([object]$before, [object]$after, [string]$path = '')
  
  function Compare-Properties([object]$b, [object]$a, [string]$currentPath) {
    $diffs = @()
    
    if ($null -eq $b -and $null -eq $a) { return $diffs }
    if ($null -eq $b) { 
      $diffs += "    ${currentPath}: [ADDED] $a"
      return $diffs 
    }
    if ($null -eq $a) { 
      $diffs += "    ${currentPath}: [REMOVED] $b"
      return $diffs 
    }
    
    # PSCustomObject の場合
    if ($b -is [pscustomobject] -and $a -is [pscustomobject]) {
      $bProps = $b.PSObject.Properties.Name | Sort-Object
      $aProps = $a.PSObject.Properties.Name | Sort-Object
      $allProps = ($bProps + $aProps) | Sort-Object -Unique
      
      foreach ($prop in $allProps) {
        $newPath = if ($currentPath) { "$currentPath.$prop" } else { $prop }
        $bVal = if ($prop -in $bProps) { $b.$prop } else { $null }
        $aVal = if ($prop -in $aProps) { $a.$prop } else { $null }
        $diffs += Compare-Properties $bVal $aVal $newPath
      }
      return $diffs
    }
    
    # 配列の場合（簡略化：サイズ変更のみ検知）
    if ($b -is [System.Collections.IEnumerable] -and -not ($b -is [string]) -and
        $a -is [System.Collections.IEnumerable] -and -not ($a -is [string])) {
      $bArray = @($b)
      $aArray = @($a)
      
      if ($bArray.Count -ne $aArray.Count) {
        $diffs += "    ${currentPath}: [ARRAY SIZE] $($bArray.Count) -> $($aArray.Count)"
      } elseif ($bArray.Count -gt 0) {
        # 配列の内容が変更された場合の簡易表示
        try {
          $bJson = ($bArray | ConvertTo-Json -Compress -Depth 2)
          $aJson = ($aArray | ConvertTo-Json -Compress -Depth 2)
          if ($bJson -ne $aJson) {
            $diffs += "    ${currentPath}: [ARRAY CONTENT CHANGED]"
          }
        } catch {
          $diffs += "    ${currentPath}: [ARRAY CONTENT CHANGED - COMPARISON ERROR]"
        }
      }
      return $diffs
    }
    
    # スカラー値の比較
    if ($b -ne $a) {
      $diffs += "    ${currentPath}: '$b' -> '$a'"
    }
    
    return $diffs
  }
  
  return Compare-Properties $before $after $path
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
        if ($currentFile -match 'route_tables\.json') {
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
        
        # IAM policies: ポリシー配列をソート
        if ($currentFile -match 'iam_.*_policies\.json') {
          if ($p -eq 'Policies' -and $val) {
            $arr = @(As-Array $val | Sort-Object { 
              if ($_.PolicyArn) { return $_.PolicyArn }
              if ($_.PolicyName) { return $_.PolicyName }
              return $_.ToString()
            })
            $ht[$p] = @( $arr | ForEach-Object { Normalize $_ "$path.$p" } )
            continue
          }
          if ($p -eq 'Groups' -and $val) {
            $arr = @(As-Array $val | Sort-Object { $_.GroupName })
            $ht[$p] = @( $arr | ForEach-Object { Normalize $_ "$path.$p" } )
            continue
          }
          if ($p -eq 'InstanceProfiles' -and $val) {
            $arr = @(As-Array $val | Sort-Object { $_.InstanceProfileName })
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

  # 特殊な構造のファイルの処理
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
  
  # EC2インスタンスの特殊処理（Reservations -> Instances）
  if ($path.ToLower().EndsWith('ec2_instances.json')) {
    $map = @{}
    foreach ($reservation in (As-Array $items)) {
      foreach ($instance in (As-Array $reservation.Instances)) {
        $id = $instance.InstanceId
        if ($id) { $map[$id] = $instance }
      }
    }
    return $map
  }
  
  # ECS Services の特殊処理
  if ($path.ToLower().EndsWith('ecs_services.json')) {
    $map = @{}
    foreach ($svcWrapper in (As-Array $items)) {
      $svc = $svcWrapper.Service
      if ($svc -and $svc.serviceArn) {
        $map[$svc.serviceArn] = $svcWrapper
      }
    }
    return $map
  }
  
  # Load Balancer Listeners の特殊処理
  if ($path.ToLower().EndsWith('load_balancer_listeners.json')) {
    $map = @{}
    foreach ($listenerWrapper in (As-Array $items)) {
      $listener = $listenerWrapper.Listener
      if ($listener -and $listener.ListenerArn) {
        $map[$listener.ListenerArn] = $listenerWrapper
      }
    }
    return $map
  }
  
  # Target Health の特殊処理
  if ($path.ToLower().EndsWith('target_health.json')) {
    $map = @{}
    foreach ($healthWrapper in (As-Array $items)) {
      $id = $healthWrapper.TargetGroupArn
      if ($id) { $map[$id] = $healthWrapper }
    }
    return $map
  }
  
  # IAM User Policies の特殊処理
  if ($path.ToLower().EndsWith('iam_user_policies.json')) {
    $map = @{}
    foreach ($userPolicy in (As-Array $items)) {
      $key = "$($userPolicy.UserName)|$($userPolicy.Type)"
      $map[$key] = $userPolicy
    }
    return $map
  }
  
  # IAM Group Policies の特殊処理
  if ($path.ToLower().EndsWith('iam_group_policies.json')) {
    $map = @{}
    foreach ($groupPolicy in (As-Array $items)) {
      $key = "$($groupPolicy.GroupName)|$($groupPolicy.Type)"
      $map[$key] = $groupPolicy
    }
    return $map
  }
  
  # IAM Role Policies の特殊処理
  if ($path.ToLower().EndsWith('iam_role_policies.json')) {
    $map = @{}
    foreach ($rolePolicy in (As-Array $items)) {
      $key = "$($rolePolicy.RoleName)|$($rolePolicy.Type)"
      $map[$key] = $rolePolicy
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
  $changedDetails = @{}
  foreach ($id in $common) {
    $b = To-CanonicalJson -obj $before[$id] -currentFile $f
    $a = To-CanonicalJson -obj $after[$id]  -currentFile $f
    if ($b -ne $a) { 
      $changed += $id 
      $changedDetails[$id] = Compare-ObjectDetails -before $before[$id] -after $after[$id]
    }
  }

  $report.Add("=== $f ===")
  if ($added)   { $report.Add("  Added   : " + ($added -join ', ')) }
  if ($removed) { $report.Add("  Removed : " + ($removed -join ', ')) }
  if ($changed) { 
    $report.Add("  Changed : " + ($changed -join ', '))
    foreach ($id in $changed) {
      $report.Add("    $id details:")
      foreach ($detail in $changedDetails[$id]) {
        $report.Add($detail)
      }
    }
  }
  if (-not $added -and -not $removed -and -not $changed) { $report.Add("  No differences") }
  $report.Add("")
}

$report | Out-File -FilePath $OutReport -Encoding utf8
Write-Host "Diff report written: $OutReport"