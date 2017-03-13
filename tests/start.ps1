param (
  [Parameter(Mandatory=$true)]
  [string]$OctopusVersion,
  [Parameter(Mandatory=$false)]
  [string]$ProjectName = "octopusdocker"
)

$env:OCTOPUS_VERSION=$OctopusVersion;
$ServerServiceName=$ProjectName+"_octopus_1";

#Consider different endpoints for concurrent testing
$env:PORT_PORTAL=81;
$env:PORT_HALIBUT=10943;


write-host "docker-compose --project-name $ProjectName up --force-recreate -d"
& "docker-compose" --project-name $ProjectName --file .\docker-compose.yml --file .\tests\docker-compose.yml up --force-recreate -d
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

# Wait for health check to indicate its alive!
$attempts = 0;
$sleepsecs = 5;
While($attempts -lt 20)
{	
	$attempts++
	$health = ($(docker inspect $ServerServiceName) | ConvertFrom-Json).State.Health.Status;
	Write-Host "Waiting status of healthy ($health)..."
	if ($health -eq "healthy"){
		break;
	}
	if ($LASTEXITCODE -ne 0) {
		exit $LASTEXITCODE
	}
	Sleep -Seconds $sleepsecs
}
if ((($(docker inspect $ServerServiceName) | ConvertFrom-Json).State.Health.Status) -ne "healthy"){
	Write-Error "Octopus container failed to go healthy after $($attempts * $sleepsecs) seconds";
	exit 1;
}

# Write out helpful info on success
$docker = docker inspect $ServerServiceName | convertfrom-json
Write-Host Server available from the host at http://$($docker[0].NetworkSettings.Networks.nat.IpAddress):81