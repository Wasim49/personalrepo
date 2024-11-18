using 'vm.bicep'

param resourceGroupName = '1-dae277f2-playground-sandbox'
param location = 'southcentralus'
param vmBaseName = 'vm'
param vmCount = 3
param adminUsername = 'vmadmin'
param adminPassword = '*PJIPHV5d32Vjt@K'
param vmSize = 'Standard_D2s_v3'
param scriptUri = 'https://raw.githubusercontent.com/Wasim49/Github-Repo/refs/heads/main/ansible-windows-tar-prereqs.ps1'
param commandToExecute = 'powershell.exe -ExecutionPolicy Unrestricted -File ansible-windows-tar-prereqs.ps1'




