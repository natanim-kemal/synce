param(
  [string]$InstanceId = "",
  [string]$Release = "",
  [string]$Bucket = "synce-pdf-books-179530538522"
)

# Ships a server build to the instance with Sentry debug ids injected, so that
# production stack traces resolve to the original TypeScript.
#
# 1. build the image on the instance
# 2. pull dist out, inject debug ids locally, upload the bundle to Sentry
# 3. push the injected dist back and restart the app in place
#
# The Sentry CLI must be installed and authenticated on the machine running this.

$ErrorActionPreference = 'Stop'
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = "$env:USERPROFILE\.local\bin;" + $env:Path

if (-not $InstanceId) {
  $InstanceId = aws ec2 describe-instances --filters "Name=tag:aws:cloudformation:stack-name,Values=SynceStack" --query "Reservations[].Instances[?State.Name=='running'].InstanceId" --output text --profile aws-agent-toolkit --region eu-north-1
}
if (-not $Release) {
  $Release = (git -C (Split-Path -Parent $PSScriptRoot) rev-parse --short HEAD).Trim()
}
Write-Host "instance: $InstanceId  release: $Release"

function Invoke-Ssm([string]$script, [string]$label) {
  $params = @{ commands = @($script) } | ConvertTo-Json -Compress
  $id = aws ssm send-command --instance-ids $InstanceId --document-name "AWS-RunShellScript" --parameters $params --query "Command.CommandId" --output text --profile aws-agent-toolkit --region eu-north-1
  $deadline = (Get-Date).AddMinutes(5)
  do {
    Start-Sleep -Seconds 6
    $inv = aws ssm get-command-invocation --command-id $id --instance-id $InstanceId --profile aws-agent-toolkit --region eu-north-1 | ConvertFrom-Json
  } while ($inv.Status -eq 'InProgress' -and (Get-Date) -lt $deadline)
  Write-Host "=== $label ($($inv.Status)) ==="
  $inv.StandardOutputContent
  if ($inv.StandardErrorContent) { Write-Host "--- stderr ---"; $inv.StandardErrorContent }
}

Invoke-Ssm "cd /opt/synce && rm -f /tmp/build.log && nohup bash -c 'sudo docker compose build server > /tmp/build.log 2>&1; echo BUILD_EXIT=\$? >> /tmp/build.log' > /dev/null 2>&1 & sleep 2; echo BUILD-STARTED" "build" | Out-Null

for ($i = 0; $i -lt 30; $i++) {
  Start-Sleep -Seconds 20
  $r = (Invoke-Ssm "if grep -q BUILD_EXIT /tmp/build.log 2>/dev/null; then tail -2 /tmp/build.log; else echo STILL-BUILDING; fi" "poll $i") | Out-String
  if ($r -match "BUILD_EXIT") { break }
}

Invoke-Ssm "cd /opt/synce && sed -i 's/^SENTRY_RELEASE=.*/SENTRY_RELEASE=$Release/' server.env && sudo docker compose up -d server 2>&1 | tail -1 && sleep 10 && sudo docker exec synce-server-1 sh -c 'cd /app/dist && tar czf /tmp/dist.tgz .' && sudo docker cp synce-server-1:/tmp/dist.tgz /tmp/dist.tgz && sudo chmod 644 /tmp/dist.tgz && aws s3 cp /tmp/dist.tgz s3://$Bucket/deploy/dist.tgz --region eu-north-1 && echo DIST-OK" "pull dist" | Out-Null

$distDir = "$env:TEMP\synce-dist"
Remove-Item $distDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $distDir | Out-Null
aws s3 cp "s3://$Bucket/deploy/dist.tgz" "$env:TEMP\synce-dist.tgz" --profile aws-agent-toolkit --region eu-north-1 --quiet
tar -xzf "$env:TEMP\synce-dist.tgz" -C $distDir

Write-Host "=== injecting debug ids ==="
sentry sourcemap inject $distDir 2>&1 | Select-Object -Last 2

Write-Host "=== uploading bundle for $Release ==="
sentry sourcemap upload $distDir --release $Release --org synce --project synce-server 2>&1 | Select-Object -Last 5

tar -czf "$env:TEMP\synce-dist-injected.tgz" -C $distDir .
aws s3 cp "$env:TEMP\synce-dist-injected.tgz" "s3://$Bucket/deploy/dist-injected.tgz" --profile aws-agent-toolkit --region eu-north-1 --quiet

Invoke-Ssm "cd /tmp && aws s3 cp s3://$Bucket/deploy/dist-injected.tgz /tmp/dist-injected.tgz --region eu-north-1 && rm -rf /tmp/dist-new && mkdir /tmp/dist-new && tar -xzf /tmp/dist-injected.tgz -C /tmp/dist-new && sudo docker cp /tmp/dist-new/. synce-server-1:/app/dist/ && sudo docker compose -f /opt/synce/docker-compose.yml restart server 2>&1 | tail -1 && sleep 12 && curl -s --resolve api.synce.natanim.dev:443:127.0.0.1 https://api.synce.natanim.dev/health; echo" "deploy injected" | Out-Null
