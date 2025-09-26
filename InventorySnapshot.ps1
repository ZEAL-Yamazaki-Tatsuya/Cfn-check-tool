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

# EC2 Instances
$resp = Run-AwsJson "aws ec2 describe-instances --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'ec2_instances.json') -Encoding utf8

# EC2 Key Pairs
$resp = Run-AwsJson "aws ec2 describe-key-pairs --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'ec2_key_pairs.json') -Encoding utf8

# EC2 Images (AMIs) - 自分が所有するもののみ
$resp = Run-AwsJson "aws ec2 describe-images --owners self --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'ec2_images.json') -Encoding utf8

# EC2 Volumes
$resp = Run-AwsJson "aws ec2 describe-volumes --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'ec2_volumes.json') -Encoding utf8

# EC2 Snapshots - 自分が所有するもののみ
$resp = Run-AwsJson "aws ec2 describe-snapshots --owner-ids self --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'ec2_snapshots.json') -Encoding utf8

# ECS Clusters
$resp = Run-AwsJson "aws ecs list-clusters --output json"
if ($resp -and $resp.clusterArns) {
  $clusterDetails = Run-AwsJson "aws ecs describe-clusters --clusters $($resp.clusterArns -join ' ') --include CONFIGURATIONS,TAGS --output json"
  $clusterDetails | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'ecs_clusters.json') -Encoding utf8
  
  # ECS Services for each cluster
  $allServices = @()
  foreach ($clusterArn in $resp.clusterArns) {
    $services = Run-AwsJson "aws ecs list-services --cluster $clusterArn --output json"
    if ($services -and $services.serviceArns) {
      $serviceDetails = Run-AwsJson "aws ecs describe-services --cluster $clusterArn --services $($services.serviceArns -join ' ') --output json"
      if ($serviceDetails -and $serviceDetails.services) {
        foreach ($service in $serviceDetails.services) {
          $allServices += [pscustomobject]@{
            ClusterArn = $clusterArn
            Service = $service
          }
        }
      }
    }
  }
  $allServices | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'ecs_services.json') -Encoding utf8
  
  # ECS Task Definitions
  $taskDefs = Run-AwsJson "aws ecs list-task-definitions --output json"
  if ($taskDefs -and $taskDefs.taskDefinitionArns) {
    # 最新のリビジョンのみを取得（最大50個）
    $latestTaskDefs = $taskDefs.taskDefinitionArns | Select-Object -Last 50
    $taskDefDetails = @()
    foreach ($taskDefArn in $latestTaskDefs) {
      $taskDef = Run-AwsJson "aws ecs describe-task-definition --task-definition $taskDefArn --output json"
      if ($taskDef) { $taskDefDetails += $taskDef.taskDefinition }
    }
    $taskDefDetails | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'ecs_task_definitions.json') -Encoding utf8
  }
} else {
  # 空のファイルを作成
  @{} | ConvertTo-Json | Out-File (Join-Path $target 'ecs_clusters.json') -Encoding utf8
  @() | ConvertTo-Json | Out-File (Join-Path $target 'ecs_services.json') -Encoding utf8
  @() | ConvertTo-Json | Out-File (Join-Path $target 'ecs_task_definitions.json') -Encoding utf8
}

# Application Load Balancers (ALB)
$resp = Run-AwsJson "aws elbv2 describe-load-balancers --output json"
if ($resp -and $resp.LoadBalancers) {
  $resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'load_balancers.json') -Encoding utf8
  
  # Target Groups
  $targetGroups = Run-AwsJson "aws elbv2 describe-target-groups --output json"
  $targetGroups | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'target_groups.json') -Encoding utf8
  
  # Listeners for each load balancer
  $allListeners = @()
  foreach ($lb in $resp.LoadBalancers) {
    $listeners = Run-AwsJson "aws elbv2 describe-listeners --load-balancer-arn $($lb.LoadBalancerArn) --output json"
    if ($listeners -and $listeners.Listeners) {
      foreach ($listener in $listeners.Listeners) {
        $allListeners += [pscustomobject]@{
          LoadBalancerArn = $lb.LoadBalancerArn
          Listener = $listener
        }
      }
    }
  }
  $allListeners | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'load_balancer_listeners.json') -Encoding utf8
  
  # Target Health for each target group
  $allTargetHealth = @()
  if ($targetGroups -and $targetGroups.TargetGroups) {
    foreach ($tg in $targetGroups.TargetGroups) {
      $health = Run-AwsJson "aws elbv2 describe-target-health --target-group-arn $($tg.TargetGroupArn) --output json"
      if ($health) {
        $allTargetHealth += [pscustomobject]@{
          TargetGroupArn = $tg.TargetGroupArn
          TargetHealthDescriptions = $health.TargetHealthDescriptions
        }
      }
    }
  }
  $allTargetHealth | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'target_health.json') -Encoding utf8
} else {
  # 空のファイルを作成
  @{} | ConvertTo-Json | Out-File (Join-Path $target 'load_balancers.json') -Encoding utf8
  @{} | ConvertTo-Json | Out-File (Join-Path $target 'target_groups.json') -Encoding utf8
  @() | ConvertTo-Json | Out-File (Join-Path $target 'load_balancer_listeners.json') -Encoding utf8
  @() | ConvertTo-Json | Out-File (Join-Path $target 'target_health.json') -Encoding utf8
}

# Classic Load Balancers (CLB) - 旧世代だが念のため
$resp = Run-AwsJson "aws elb describe-load-balancers --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'classic_load_balancers.json') -Encoding utf8

# IAM Users
$resp = Run-AwsJson "aws iam list-users --output json"
if ($resp -and $resp.Users) {
  $resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'iam_users.json') -Encoding utf8
  
  # User policies for each user
  $allUserPolicies = @()
  foreach ($user in $resp.Users) {
    $userName = $user.UserName
    
    # Attached managed policies
    $attachedPolicies = Run-AwsJson "aws iam list-attached-user-policies --user-name $userName --output json"
    if ($attachedPolicies) {
      $allUserPolicies += [pscustomobject]@{
        UserName = $userName
        Type = "AttachedManagedPolicies"
        Policies = $attachedPolicies.AttachedPolicies
      }
    }
    
    # Inline policies
    $inlinePolicies = Run-AwsJson "aws iam list-user-policies --user-name $userName --output json"
    if ($inlinePolicies -and $inlinePolicies.PolicyNames) {
      $inlinePolicyDetails = @()
      foreach ($policyName in $inlinePolicies.PolicyNames) {
        $policyDoc = Run-AwsJson "aws iam get-user-policy --user-name $userName --policy-name $policyName --output json"
        if ($policyDoc) {
          $inlinePolicyDetails += $policyDoc
        }
      }
      $allUserPolicies += [pscustomobject]@{
        UserName = $userName
        Type = "InlinePolicies"
        Policies = $inlinePolicyDetails
      }
    }
    
    # User groups
    $userGroups = Run-AwsJson "aws iam get-groups-for-user --user-name $userName --output json"
    if ($userGroups) {
      $allUserPolicies += [pscustomobject]@{
        UserName = $userName
        Type = "Groups"
        Groups = $userGroups.Groups
      }
    }
  }
  $allUserPolicies | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'iam_user_policies.json') -Encoding utf8
} else {
  @{} | ConvertTo-Json | Out-File (Join-Path $target 'iam_users.json') -Encoding utf8
  @() | ConvertTo-Json | Out-File (Join-Path $target 'iam_user_policies.json') -Encoding utf8
}

# IAM Groups
$resp = Run-AwsJson "aws iam list-groups --output json"
if ($resp -and $resp.Groups) {
  $resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'iam_groups.json') -Encoding utf8
  
  # Group policies for each group
  $allGroupPolicies = @()
  foreach ($group in $resp.Groups) {
    $groupName = $group.GroupName
    
    # Attached managed policies
    $attachedPolicies = Run-AwsJson "aws iam list-attached-group-policies --group-name $groupName --output json"
    if ($attachedPolicies) {
      $allGroupPolicies += [pscustomobject]@{
        GroupName = $groupName
        Type = "AttachedManagedPolicies"
        Policies = $attachedPolicies.AttachedPolicies
      }
    }
    
    # Inline policies
    $inlinePolicies = Run-AwsJson "aws iam list-group-policies --group-name $groupName --output json"
    if ($inlinePolicies -and $inlinePolicies.PolicyNames) {
      $inlinePolicyDetails = @()
      foreach ($policyName in $inlinePolicies.PolicyNames) {
        $policyDoc = Run-AwsJson "aws iam get-group-policy --group-name $groupName --policy-name $policyName --output json"
        if ($policyDoc) {
          $inlinePolicyDetails += $policyDoc
        }
      }
      $allGroupPolicies += [pscustomobject]@{
        GroupName = $groupName
        Type = "InlinePolicies"
        Policies = $inlinePolicyDetails
      }
    }
  }
  $allGroupPolicies | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'iam_group_policies.json') -Encoding utf8
} else {
  @{} | ConvertTo-Json | Out-File (Join-Path $target 'iam_groups.json') -Encoding utf8
  @() | ConvertTo-Json | Out-File (Join-Path $target 'iam_group_policies.json') -Encoding utf8
}

# IAM Roles
$resp = Run-AwsJson "aws iam list-roles --output json"
if ($resp -and $resp.Roles) {
  $resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'iam_roles.json') -Encoding utf8
  
  # Role policies for each role
  $allRolePolicies = @()
  foreach ($role in $resp.Roles) {
    $roleName = $role.RoleName
    
    # Attached managed policies
    $attachedPolicies = Run-AwsJson "aws iam list-attached-role-policies --role-name $roleName --output json"
    if ($attachedPolicies) {
      $allRolePolicies += [pscustomobject]@{
        RoleName = $roleName
        Type = "AttachedManagedPolicies"
        Policies = $attachedPolicies.AttachedPolicies
      }
    }
    
    # Inline policies
    $inlinePolicies = Run-AwsJson "aws iam list-role-policies --role-name $roleName --output json"
    if ($inlinePolicies -and $inlinePolicies.PolicyNames) {
      $inlinePolicyDetails = @()
      foreach ($policyName in $inlinePolicies.PolicyNames) {
        $policyDoc = Run-AwsJson "aws iam get-role-policy --role-name $roleName --policy-name $policyName --output json"
        if ($policyDoc) {
          $inlinePolicyDetails += $policyDoc
        }
      }
      $allRolePolicies += [pscustomobject]@{
        RoleName = $roleName
        Type = "InlinePolicies"
        Policies = $inlinePolicyDetails
      }
    }
    
    # Instance profiles
    $instanceProfiles = Run-AwsJson "aws iam list-instance-profiles-for-role --role-name $roleName --output json"
    if ($instanceProfiles) {
      $allRolePolicies += [pscustomobject]@{
        RoleName = $roleName
        Type = "InstanceProfiles"
        InstanceProfiles = $instanceProfiles.InstanceProfiles
      }
    }
  }
  $allRolePolicies | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'iam_role_policies.json') -Encoding utf8
} else {
  @{} | ConvertTo-Json | Out-File (Join-Path $target 'iam_roles.json') -Encoding utf8
  @() | ConvertTo-Json | Out-File (Join-Path $target 'iam_role_policies.json') -Encoding utf8
}

# IAM Managed Policies (Customer managed only)
$resp = Run-AwsJson "aws iam list-policies --scope Local --output json"
if ($resp -and $resp.Policies) {
  $resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'iam_managed_policies.json') -Encoding utf8
  
  # Policy versions and documents
  $allPolicyVersions = @()
  foreach ($policy in $resp.Policies) {
    $policyArn = $policy.Arn
    
    # Get policy versions
    $versions = Run-AwsJson "aws iam list-policy-versions --policy-arn $policyArn --output json"
    if ($versions -and $versions.Versions) {
      foreach ($version in $versions.Versions) {
        if ($version.IsDefaultVersion -eq $true) {
          $policyDoc = Run-AwsJson "aws iam get-policy-version --policy-arn $policyArn --version-id $($version.VersionId) --output json"
          if ($policyDoc) {
            $allPolicyVersions += [pscustomobject]@{
              PolicyArn = $policyArn
              VersionId = $version.VersionId
              IsDefaultVersion = $version.IsDefaultVersion
              Document = $policyDoc.PolicyVersion.Document
              CreateDate = $version.CreateDate
            }
          }
        }
      }
    }
  }
  $allPolicyVersions | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'iam_policy_versions.json') -Encoding utf8
} else {
  @{} | ConvertTo-Json | Out-File (Join-Path $target 'iam_managed_policies.json') -Encoding utf8
  @() | ConvertTo-Json | Out-File (Join-Path $target 'iam_policy_versions.json') -Encoding utf8
}

# IAM Instance Profiles
$resp = Run-AwsJson "aws iam list-instance-profiles --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'iam_instance_profiles.json') -Encoding utf8

# IAM SAML Providers
$resp = Run-AwsJson "aws iam list-saml-providers --output json"
if ($resp -and $resp.SAMLProviderList) {
  $resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'iam_saml_providers.json') -Encoding utf8
  
  # SAML Provider details
  $samlProviderDetails = @()
  foreach ($provider in $resp.SAMLProviderList) {
    $providerArn = $provider.Arn
    $providerDetail = Run-AwsJson "aws iam get-saml-provider --saml-provider-arn $providerArn --output json"
    if ($providerDetail) {
      $samlProviderDetails += [pscustomobject]@{
        Arn = $providerArn
        SAMLMetadataDocument = $providerDetail.SAMLMetadataDocument
        CreateDate = $providerDetail.CreateDate
        ValidUntil = $providerDetail.ValidUntil
      }
    }
  }
  $samlProviderDetails | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'iam_saml_provider_details.json') -Encoding utf8
} else {
  @{} | ConvertTo-Json | Out-File (Join-Path $target 'iam_saml_providers.json') -Encoding utf8
  @() | ConvertTo-Json | Out-File (Join-Path $target 'iam_saml_provider_details.json') -Encoding utf8
}

# IAM OIDC Providers
$resp = Run-AwsJson "aws iam list-open-id-connect-providers --output json"
if ($resp -and $resp.OpenIDConnectProviderList) {
  $resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'iam_oidc_providers.json') -Encoding utf8
  
  # OIDC Provider details
  $oidcProviderDetails = @()
  foreach ($provider in $resp.OpenIDConnectProviderList) {
    $providerArn = $provider.Arn
    $providerDetail = Run-AwsJson "aws iam get-open-id-connect-provider --open-id-connect-provider-arn $providerArn --output json"
    if ($providerDetail) {
      $oidcProviderDetails += [pscustomobject]@{
        Arn = $providerArn
        Url = $providerDetail.Url
        ClientIDList = $providerDetail.ClientIDList
        ThumbprintList = $providerDetail.ThumbprintList
        CreateDate = $providerDetail.CreateDate
      }
    }
  }
  $oidcProviderDetails | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'iam_oidc_provider_details.json') -Encoding utf8
} else {
  @{} | ConvertTo-Json | Out-File (Join-Path $target 'iam_oidc_providers.json') -Encoding utf8
  @() | ConvertTo-Json | Out-File (Join-Path $target 'iam_oidc_provider_details.json') -Encoding utf8
}

# RDS DB Instances
$resp = Run-AwsJson "aws rds describe-db-instances --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'rds_db_instances.json') -Encoding utf8

# RDS DB Clusters (Aurora)
$resp = Run-AwsJson "aws rds describe-db-clusters --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'rds_db_clusters.json') -Encoding utf8

# RDS DB Subnet Groups
$resp = Run-AwsJson "aws rds describe-db-subnet-groups --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'rds_db_subnet_groups.json') -Encoding utf8

# RDS DB Parameter Groups
$resp = Run-AwsJson "aws rds describe-db-parameter-groups --output json"
if ($resp -and $resp.DBParameterGroups) {
  $resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'rds_db_parameter_groups.json') -Encoding utf8
  
  # Parameter Group details (custom parameter groups only)
  $allParameters = @()
  foreach ($pg in $resp.DBParameterGroups) {
    # Skip default parameter groups to avoid too much data
    if ($pg.DBParameterGroupName -notmatch '^default\.') {
      $pgName = $pg.DBParameterGroupName
      $params = Run-AwsJson "aws rds describe-db-parameters --db-parameter-group-name $pgName --output json"
      if ($params -and $params.Parameters) {
        # Only include modified parameters
        $modifiedParams = $params.Parameters | Where-Object { $_.Source -eq 'user' }
        if ($modifiedParams) {
          $allParameters += [pscustomobject]@{
            DBParameterGroupName = $pgName
            Parameters = $modifiedParams
          }
        }
      }
    }
  }
  $allParameters | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'rds_db_parameter_details.json') -Encoding utf8
} else {
  @{} | ConvertTo-Json | Out-File (Join-Path $target 'rds_db_parameter_groups.json') -Encoding utf8
  @() | ConvertTo-Json | Out-File (Join-Path $target 'rds_db_parameter_details.json') -Encoding utf8
}

# RDS DB Cluster Parameter Groups
$resp = Run-AwsJson "aws rds describe-db-cluster-parameter-groups --output json"
if ($resp -and $resp.DBClusterParameterGroups) {
  $resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'rds_db_cluster_parameter_groups.json') -Encoding utf8
  
  # Cluster Parameter Group details (custom parameter groups only)
  $allClusterParameters = @()
  foreach ($cpg in $resp.DBClusterParameterGroups) {
    # Skip default parameter groups to avoid too much data
    if ($cpg.DBClusterParameterGroupName -notmatch '^default\.') {
      $cpgName = $cpg.DBClusterParameterGroupName
      $params = Run-AwsJson "aws rds describe-db-cluster-parameters --db-cluster-parameter-group-name $cpgName --output json"
      if ($params -and $params.Parameters) {
        # Only include modified parameters
        $modifiedParams = $params.Parameters | Where-Object { $_.Source -eq 'user' }
        if ($modifiedParams) {
          $allClusterParameters += [pscustomobject]@{
            DBClusterParameterGroupName = $cpgName
            Parameters = $modifiedParams
          }
        }
      }
    }
  }
  $allClusterParameters | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'rds_db_cluster_parameter_details.json') -Encoding utf8
} else {
  @{} | ConvertTo-Json | Out-File (Join-Path $target 'rds_db_cluster_parameter_groups.json') -Encoding utf8
  @() | ConvertTo-Json | Out-File (Join-Path $target 'rds_db_cluster_parameter_details.json') -Encoding utf8
}

# RDS Option Groups
$resp = Run-AwsJson "aws rds describe-option-groups --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'rds_option_groups.json') -Encoding utf8

# RDS DB Snapshots (自分が所有するもののみ)
$resp = Run-AwsJson "aws rds describe-db-snapshots --snapshot-type manual --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'rds_db_snapshots.json') -Encoding utf8

# RDS DB Cluster Snapshots (自分が所有するもののみ)
$resp = Run-AwsJson "aws rds describe-db-cluster-snapshots --snapshot-type manual --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'rds_db_cluster_snapshots.json') -Encoding utf8

# ElastiCache Clusters
$resp = Run-AwsJson "aws elasticache describe-cache-clusters --show-cache-node-info --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'elasticache_clusters.json') -Encoding utf8

# ElastiCache Replication Groups (Redis)
$resp = Run-AwsJson "aws elasticache describe-replication-groups --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'elasticache_replication_groups.json') -Encoding utf8

# ElastiCache Subnet Groups
$resp = Run-AwsJson "aws elasticache describe-cache-subnet-groups --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'elasticache_subnet_groups.json') -Encoding utf8

# ElastiCache Parameter Groups
$resp = Run-AwsJson "aws elasticache describe-cache-parameter-groups --output json"
if ($resp -and $resp.CacheParameterGroups) {
  $resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'elasticache_parameter_groups.json') -Encoding utf8
  
  # Parameter Group details (custom parameter groups only)
  $allCacheParameters = @()
  foreach ($cpg in $resp.CacheParameterGroups) {
    # Skip default parameter groups to avoid too much data
    if ($cpg.CacheParameterGroupName -notmatch '^default\.') {
      $cpgName = $cpg.CacheParameterGroupName
      $params = Run-AwsJson "aws elasticache describe-cache-parameters --cache-parameter-group-name $cpgName --output json"
      if ($params -and $params.Parameters) {
        # Only include modified parameters
        $modifiedParams = $params.Parameters | Where-Object { $_.Source -eq 'user' }
        if ($modifiedParams) {
          $allCacheParameters += [pscustomobject]@{
            CacheParameterGroupName = $cpgName
            Parameters = $modifiedParams
          }
        }
      }
    }
  }
  $allCacheParameters | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'elasticache_parameter_details.json') -Encoding utf8
} else {
  @{} | ConvertTo-Json | Out-File (Join-Path $target 'elasticache_parameter_groups.json') -Encoding utf8
  @() | ConvertTo-Json | Out-File (Join-Path $target 'elasticache_parameter_details.json') -Encoding utf8
}

# ElastiCache Security Groups (VPC以外の場合)
$resp = Run-AwsJson "aws elasticache describe-cache-security-groups --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'elasticache_security_groups.json') -Encoding utf8

# ElastiCache Snapshots (Redis)
$resp = Run-AwsJson "aws elasticache describe-snapshots --output json"
$resp | ConvertTo-Json -Depth 100 | Out-File (Join-Path $target 'elasticache_snapshots.json') -Encoding utf8

Write-Host "Snapshot completed: $target"