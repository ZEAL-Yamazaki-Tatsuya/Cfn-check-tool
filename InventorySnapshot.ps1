Param(
  [Parameter(Mandatory=$true)] [string]$OutDir,
  [Parameter(Mandatory=$true)] [string]$Label
)

# 出力先フォルダ作成
$target = Join-Path $OutDir $Label
New-Item -ItemType Directory -Force -Path $target | Out-Null

function Run-AwsJson {
  param([string]$Cmd)
  $json = cmd /c $Cmd 2>$null
  if (-not $json) { return $null }
  try { return ($json | ConvertFrom-Json) } catch { return $null }
}

# VPC
$resp = Run-AwsJson "aws ec2 describe-vpcs --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'vpcs.json') -Encoding utf8

# Subnets
$resp = Run-AwsJson "aws ec2 describe-subnets --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'subnets.json') -Encoding utf8

# Route Tables
$resp = Run-AwsJson "aws ec2 describe-route-tables --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'route_tables.json') -Encoding utf8

# Internet Gateways
$resp = Run-AwsJson "aws ec2 describe-internet-gateways --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'internet_gateways.json') -Encoding utf8

# DHCP Options
$resp = Run-AwsJson "aws ec2 describe-dhcp-options --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'dhcp_options.json') -Encoding utf8

# Elastic IPs
$resp = Run-AwsJson "aws ec2 describe-addresses --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'elastic_ips.json') -Encoding utf8

# Managed Prefix Lists
$mpl = Run-AwsJson "aws ec2 describe-managed-prefix-lists --output json"
if ($mpl) {
  $mpl | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'managed_prefix_lists.json') -Encoding utf8
  $entriesAll = @()
  foreach ($pl in $mpl.ManagedPrefixLists) {
    $plid = $pl.PrefixListId
    $entries = Run-AwsJson "aws ec2 describe-managed-prefix-list-entries --prefix-list-id $plid --output json"
    if ($entries) {
      $entriesAll += [pscustomobject]@{ PrefixListId = $plid; Entries = $entries.Entries }
    }
  }
  $entriesAll | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'managed_prefix_list_entries.json') -Encoding utf8
}

# NAT Gateways
$resp = Run-AwsJson "aws ec2 describe-nat-gateways --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'nat_gateways.json') -Encoding utf8

# VPC Peering
$resp = Run-AwsJson "aws ec2 describe-vpc-peering-connections --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'vpc_peering_connections.json') -Encoding utf8

# Network ACLs
$resp = Run-AwsJson "aws ec2 describe-network-acls --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'network_acls.json') -Encoding utf8

# Security Groups
$resp = Run-AwsJson "aws ec2 describe-security-groups --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'security_groups.json') -Encoding utf8

# VPC Endpoints
$resp = Run-AwsJson "aws ec2 describe-vpc-endpoints --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'vpc_endpoints.json') -Encoding utf8

# Endpoint Services
$resp = Run-AwsJson "aws ec2 describe-vpc-endpoint-service-configurations --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'vpc_endpoint_service_configurations.json') -Encoding utf8

$svcPerms = @()
if ($resp -and $resp.ServiceConfigurations) {
  foreach ($svc in $resp.ServiceConfigurations) {
    $sid = $svc.ServiceId
    $p = Run-AwsJson "aws ec2 describe-vpc-endpoint-service-permissions --service-id $sid --output json"
    if ($p) { $svcPerms += [pscustomobject]@{ ServiceId=$sid; AllowedPrincipals=$p.AllowedPrincipals } }
  }
}
$svcPerms | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'vpc_endpoint_service_permissions.json') -Encoding utf8

# VPC Lattice
$latticeServices = Run-AwsJson "aws vpc-lattice list-services --output json"
$latticeServices | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'vpc_lattice_services.json') -Encoding utf8

$latticeSns = Run-AwsJson "aws vpc-lattice list-service-networks --output json"
$latticeSns | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'vpc_lattice_service_networks.json') -Encoding utf8

$snVpcAssocAll = @()
if ($latticeSns -and $latticeSns.Items) {
  foreach ($sn in $latticeSns.Items) {
    $snid = $sn.Id
    $a = Run-AwsJson "aws vpc-lattice list-service-network-vpc-associations --service-network-identifier $snid --output json"
    if ($a) { $snVpcAssocAll += [pscustomobject]@{ ServiceNetworkId=$snid; Items=$a.Items } }
  }
}
$snVpcAssocAll | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'vpc_lattice_service_network_vpc_associations.json') -Encoding utf8

# VPN Gateways
$resp = Run-AwsJson "aws ec2 describe-vpn-gateways --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'vpn_gateways.json') -Encoding utf8

Write-Host "Snapshot completed: $target"
