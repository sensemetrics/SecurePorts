# Get the list of installed programs
$installedPrograms = Get-ItemProperty HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*

# Find the stunnel installation directory
$stunnelInstallDir = $installedPrograms | Where-Object {$_.DisplayName -like "*stunnel*"} | Select-Object -ExpandProperty DisplayIcon
$stunnelInstallDir = $stunnelInstallDir -replace '\\bin\\stunnel\.exe$'

# Print the installation directory
Write-Host "Detected stunnel installation directory: $stunnelInstallDir"
Write-Host ""

# Change to the stunnelInstallDir bin directory
Set-Location $stunnelInstallDir\bin

# Prompt user for number of ports
$numberOfPorts = Read-Host "Enter the number of ports"

# Validate input
while ($numberOfPorts -notmatch "^\d+$" -or $numberOfPorts -le 0) {
  Write-Host "Invalid input. Please enter a positive integer greater than 0."
  $numberOfPorts = Read-Host "Enter the number of ports"
}

# Prompt for port number for each port
$portNumbers = @()
for ($i = 1; $i -le $numberOfPorts; $i++) {
  $port = Read-Host "Enter port number for port $i"
  while ($port -notmatch "^\d+$" -or $port -le 0) {
    Write-Host "Invalid input. Please enter a positive integer greater than 0."
    $port = Read-Host "Enter port number for port $i"
  }
  while ($portNumbers -contains $port) {
    Write-Host "You already entered port $port. Please enter a unique port number."
	$port = Read-Host "Enter port number for port $i"
  }
  $portNumbers += $port
}

# Use the $portNumbers array as needed
Write-Host "You entered the following port numbers: $portNumbers"

# Run OpenSSL command for each port number
foreach ($port in $portNumbers) {
  Write-Host "Creating certificate and key for port $port..."
  Invoke-Expression ".\openssl req -x509 -newkey ed25519 -nodes -keyout ..\config\$port.key -out ..\config\$port.crt -days 18250 -subj '/CN=$port'"
}

# Add header lines to ..\config\stunnel.conf
$header = "client = yes
connect = deviceproxy-service.iiot-services.bentley.com:443
"
Set-Content -Path ..\config\stunnel.conf -Value $header

# Write stanza for each port number to ..\config\stunnel.conf
foreach ($port in $portNumbers) {
  $stanza = "[$port]
sni = $port
accept = localhost:$port
cert = $port.crt
key = $port.key
"
  Add-Content -Path ..\config\stunnel.conf -Value $stanza
}

# Install stunnel as a Windows service
Invoke-Expression ".\stunnel.exe -install /quiet"

# Prompt for success and wait for Enter key press
Write-Host "Step completed successfully! Press Enter to close this window..."
Read-Host