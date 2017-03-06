########################################################################
#
# Linux on Hyper-V and Azure Test Code, ver. 1.0.0
# Copyright (c) Microsoft Corporation
#
# All rights reserved.
# Licensed under the Apache License, Version 2.0 (the ""License"");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#     http://www.apache.org/licenses/LICENSE-2.0
#
# THIS CODE IS PROVIDED *AS IS* BASIS, WITHOUT WARRANTIES OR CONDITIONS
# OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
# ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE, FITNESS FOR A PARTICULAR
# PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
#
# See the Apache Version 2.0 License for specific language governing
# permissions and limitations under the License.
#
########################################################################

<#
.Synopsis
    This script tests VSS backup functionality.

.Description
    This script will connect to a iSCSI target, format and mount the iSCSI disk.
    After that it will proceed with backup/restore operation. 
    
    It uses a second partition as target. 

    Note: The script has to be run on the host. A second partition
    different from the Hyper-V one has to be available. 

    A typical xml entry looks like this:

    <test>
        <testName>VSS_BackupRestore_ISCSI</testName>
        <testScript>setupscripts\VSS_BackupRestore_ISCSI.ps1</testScript> 
        <testParams>
            <param>driveletter=F:</param>
            <param>TargetIP=10.7.1.10</param>
            <param>FILESYS=ext4</param>
        </testParams>
        <timeout>1200</timeout>
        <OnError>Continue</OnError>
    </test>

.Parameter vmName
    Name of the VM to backup/restore.

.Parameter hvServer
    Name of the Hyper-V server hosting the VM.

.Parameter testParams
    Test data for this test case

.Example
    setupScripts\VSS_BackuRestore_ISCSI.ps1 -hvServer localhost -vmName NameOfVm -testParams 'sshKey=path/to/ssh;rootdir=path/to/testdir;ipv4=ipaddress;driveletter=D:;TargetIP=ipOfTheIscsiTarget;FILESYS=ext4'

#>

param([string] $vmName, [string] $hvServer, [string] $testParams)

$retVal = $false
$remoteScript = "STOR_VSS_ISCSI_PartitionDisks.sh"

####################################################################### 
# 
# Main script body 
# 
#######################################################################

# Check input arguments
if ($vmName -eq $null)
{
    "ERROR: VM name is null"
    return $retVal
}

# Check input params
$params = $testParams.Split(";")

foreach ($p in $params)
{
    $fields = $p.Split("=")
        switch ($fields[0].Trim())
        {
		"TC_COVERED" { $TC_COVERED = $fields[1].Trim() }
        "sshKey" { $sshKey = $fields[1].Trim() }
        "ipv4" { $ipv4 = $fields[1].Trim() }
        "rootdir" { $rootDir = $fields[1].Trim() }
        "driveletter" { $driveletter = $fields[1].Trim() }
        "FILESYS" { $FILESYS = $fields[1].Trim() }
        "TargetIP" { $TargetIP = $fields[1].Trim() }
        "TestLogDir" { $TestLogDir = $fields[1].Trim() }
        default  {}          
        }
}

if ($null -eq $sshKey)
{
    "ERROR: Test parameter sshKey was not specified"
    return $False
}

if ($null -eq $ipv4)
{
    "ERROR: Test parameter ipv4 was not specified"
    return $False
}

if ($null -eq $rootdir)
{
    "ERROR: Test parameter rootdir was not specified"
    return $False
}

if ($null -eq $driveletter)
{
    "ERROR: Test parameter driveletter was not specified."
    return $False
}

if ($null -eq $FILESYS)
{
    "ERROR: Test parameter FILESYS was not specified"
    return $False
}

if ($null -eq $TargetIP)
{
    "ERROR: Test parameter TargetIP was not specified"
    return $False
}

# Change the working directory to where we need to be
cd $rootDir

#
# Delete any summary.log from a previous test run, then create a new file
#
$summaryLog = "${vmName}_summary.log"
del $summaryLog -ErrorAction SilentlyContinue
Write-output "This script covers test case: ${TC_COVERED}" | Tee-Object -Append -file $summaryLog

# Source TCUtils.ps1 for common functions
if (Test-Path ".\setupScripts\TCUtils.ps1") {
	. .\setupScripts\TCUtils.ps1
	"Info: Sourced TCUtils.ps1"
}
else {
	"Error: Could not find setupScripts\TCUtils.ps1"
	return $false
}

Write-Output "Info: Removing old backups"
try { Remove-WBBackupSet -Force -WarningAction SilentlyContinue }
Catch { Write-Output "No existing backup's to remove"}

# Check if the Vm VHD in not on the same drive as the backup destination 
$vm = Get-VM -Name $vmName -ComputerName $hvServer
if (-not $vm)
{
    "Error: VM '${vmName}' does not exist"
    return $False
}
 
foreach ($drive in $vm.HardDrives)
{
    if ( $drive.Path.StartsWith("${driveLetter}"))
    {
        "Error: Backup partition '${driveLetter}' is same as partition hosting the VMs disk"
        "       $($drive.Path)"
        return $False
    }
}

# Check to see Linux VM is running VSS backup daemon 
$sts = RunRemoteScript "STOR_VSS_Check_VSS_Daemon.sh"
if (-not $sts[-1])
{
    Write-Output "ERROR executing $remoteScript on VM. Exiting test case!" >> $summaryLog
    Write-Output "ERROR: Running $remoteScript script failed on VM!"
    return $False
}

Write-Output "Info: VSS Daemon is running" >> $summaryLog

# Run the remote script
$sts = RunRemoteScript $remoteScript
if (-not $sts[-1])
{
    Write-Output "ERROR executing $remoteScript on VM. Exiting test case!" >> $summaryLog
    Write-Output "ERROR: Running $remoteScript script failed on VM!"
    return $False
}
Write-Output "$remoteScript execution on VM: Success"
Write-Output "$remoteScript execution on VM: Success" >> $summaryLog

# Remove Existing Backup Policy
try { Remove-WBPolicy -all -force }
Catch { Write-Output "No existing backup policy to remove"}

# Set up a new Backup Policy
$policy = New-WBPolicy

# Set the backup backup location
$backupLocation = New-WBBackupTarget -VolumePath $driveletter

# Remove Existing Backups
Write-Output "Removing old backups from $backupLocation"
try { Remove-WBBackupSet -BackupTarget $backupLocation -Force }
Catch { Write-Output "No existing backup's to remove"}

# Define VSS WBBackup type
Set-WBVssBackupOptions -Policy $policy -VssCopyBackup

# Add the Virtual machines to the list
$VM = Get-WBVirtualMachine | where vmname -like $vmName
Add-WBVirtualMachine -Policy $policy -VirtualMachine $VM
Add-WBBackupTarget -Policy $policy -Target $backupLocation

# Start the backup
Write-Output "Backing to $driveletter"
Start-WBBackup -Policy $policy

# Review the results            
$BackupTime = (New-Timespan -Start (Get-WBJob -Previous 1).StartTime -End (Get-WBJob -Previous 1).EndTime).Minutes
Write-Output "Backup duration: $BackupTime minutes"           
"Backup duration: $BackupTime minutes" >> $summaryLog

$sts=Get-WBJob -Previous 1
if ($sts.JobState -ne "Completed" -or $sts.HResult -ne 0)
{
    Write-Output "ERROR: VSS Backup failed"
    Write-Output $sts.ErrorDescription
    $retVal = $false
    return $retVal
}

Write-Output "`nInfo: Backup successful!`n"
# Let's wait a few Seconds
Start-Sleep -Seconds 70

# Start the Restore
Write-Output "`nNow let's restore the VM from backup...`n"

# Get BackupSet
$BackupSet=Get-WBBackupSet -BackupTarget $backupLocation

# Start Restore
Start-WBHyperVRecovery -BackupSet $BackupSet -VMInBackup $BackupSet.Application[0].Component[0] -Force -WarningAction SilentlyContinue
$sts=Get-WBJob -Previous 1
if ($sts.JobState -ne "Completed" -or $sts.HResult -ne 0)
{
    Write-Output "ERROR: VSS Restore failed"
    Write-Output $sts.ErrorDescription
    $retVal = $false
    return $retVal
}

# Review the results  
$RestoreTime = (New-Timespan -Start (Get-WBJob -Previous 1).StartTime -End (Get-WBJob -Previous 1).EndTime).Minutes
Write-Output "Restore duration: $RestoreTime minutes"
"Restore duration: $RestoreTime minutes" >> $summaryLog

# Make sure VM exist after VSS backup/restore operation 
$vm = Get-VM -Name $vmName -ComputerName $hvServer
    if (-not $vm)
    {
        Write-Output "ERROR: VM ${vmName} does not exist after restore"
        return $False
    }
Write-Output "Restore success!"

# After Backup Restore VM must be off make sure that.
if ( $vm.state -ne "Off" )  
{
    Write-Output "ERROR: VM is not in OFF state, current state is " + $vm.state
    return $False
}

# Now Start the VM
$timeout = 300
$sts = Start-VM -Name $vmName -ComputerName $hvServer 
if (-not (WaitForVMToStartKVP $vmName $hvServer $timeout ))
{
    Write-Output "ERROR: ${vmName} failed to start"
    return $False
}
else
{
    Write-Output "INFO: Started VM ${vmName}"
}

# Now Check the boot logs in VM to verify if there is no Recovering journals in it . 
$sts=CheckRecoveringJ
if ($sts[-1])
{
    Write-Output "ERROR: Recovering Journals in Boot log file, VSS backup/restore failed!"
    Write-Output "No Recovering Journal in boot logs: Failed" >> $summaryLog
    return $False
}
else 
{
    $results = "Passed"
    $retVal = $True
    Write-Output "INFO: VSS Back/Restore: Success"   
    Write-Output "Recovering Journal in boot msg: Success" >> $summaryLog
}

# Remove Existing Backups
Write-Output "Removing old backups from $backupLocation"
try { Remove-WBBackupSet -BackupTarget $backupLocation -Force -WarningAction SilentlyContinue }
Catch { Write-Output "No existing backup's to remove"}

Write-Output "INFO: Test ${results}"
return $retVal
