# Quick script to get the correct zone for demo commands

Push-Location "..\..\infrastructure\gcp"
try {
    $clusterName = terraform output -raw dataproc_cluster_name
    $region = terraform output -raw gcp_region
    $project = terraform output -raw gcp_project_id
    
    $zoneUri = gcloud dataproc clusters describe $clusterName --region=$region --project=$project --format="value(config.gceClusterConfig.zoneUri)" 2>&1 | Out-String
    $zone = $zoneUri.Trim().Split('/')[-1]
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Demo Command Zone" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Cluster: $clusterName" -ForegroundColor Green
    Write-Host "Region: $region" -ForegroundColor Green
    Write-Host "Zone: $zone" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your demo command should use:" -ForegroundColor Yellow
    Write-Host "  --zone=$zone" -ForegroundColor White
    Write-Host ""
    Write-Host "Full command:" -ForegroundColor Yellow
    Write-Host "  gcloud compute ssh $clusterName-m --zone=$zone --command='yarn application -list'" -ForegroundColor White
    Write-Host ""
} finally {
    Pop-Location
}

