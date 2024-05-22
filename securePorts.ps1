# install stunnel 5.72
Invoke-Expression ".\stunnel-5.72-win64-installer.exe /AllUsers /S"

# Use the default stunnel installation directory
$stunnelInstallDir = "C:\Program Files (x86)\stunnel"

# Wait for install to finish and folder to exist
$timeout = 20 # wait 20 seconds at most
$startTime = Get-Date
while (!(Test-Path -Path $stunnelInstallDir\bin)) {
    Start-Sleep -Milliseconds 1000
    if (((Get-Date) - $startTime).TotalSeconds -ge $timeout) {
        Write-Host "Timeout reached. Unable to install stunnel. Please close this window and try again."
        Exit
    }
}

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
  Invoke-Expression ".\openssl req -x509 -newkey ed25519 -nodes -keyout ..\config\${port}_private -out ..\config\${port}_public -days 18250 -subj '/CN=$port'"
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
cert = ${port}_public
key = ${port}_private
"
  Add-Content -Path ..\config\stunnel.conf -Value $stanza
}

# Install stunnel as a Windows service
Invoke-Expression ".\stunnel.exe -install /quiet"

# Prompt for success and wait for Enter key press
Write-Host "Step completed successfully! Press Enter to close this window..."
Read-Host
