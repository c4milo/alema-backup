#!/usr/bin/env powershell

function Get-DiskFreeSpaceEx{
    [cmdletbinding()]
    param(
        [parameter(mandatory=$true,position=0,ValueFromPipeLine=$true)]
        [validatescript({(Test-Path $_ -IsValid)})]
        [string]$path,
        [parameter(mandatory=$false,position=1)]
        [string]$unit="byte"
    )

    begin{
        switch($unit){
            "byte" {$unitval = 1;break}
            "kb" {$unitval = 1kb;break}
            "mb" {$unitval = 1mb;break}
            "gb" {$unitval = 1gb;break}
            "tb" {$unitval = 1tb;break}
            "pb" {$unitval = 1pb;break}
            default {$unitval = 1;break}
        }

        $typeDefinition = @'
[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
[return: MarshalAs(UnmanagedType.Bool)]
public static extern bool GetDiskFreeSpaceEx(string lpDirectoryName,
    out ulong lpFreeBytesAvailable,
    out ulong lpTotalNumberOfBytes,
    out ulong lpTotalNumberOfFreeBytes);
'@

    }
    process{
        $freeBytesAvail = New-Object System.UInt64
        $totalNoBytes = New-Object System.UInt64
        $totalNoFreeBytes = New-Object System.UInt64

        $type = Add-Type -MemberDefinition $typeDefinition -Name Win32Utils -Namespace GetDiskFreeSpaceEx -PassThru

        $result = $type::GetDiskFreeSpaceEx($path,([ref]$freeBytesAvail),([ref]$totalNoBytes),([ref]$totalNoFreeBytes))

        $freeBytes = {if($result){$freeBytesAvail/$unitval}else{"N/A"}}.invoke()[0]
        $totalBytes = {if($result){$totalNoBytes/$unitval}else{"N/A"}}.invoke()[0]
        $totalFreeBytes = {if($result){$totalNoFreeBytes/$unitval}else{"N/A"}}.invoke()[0]

        New-Object PSObject -Property @{
            Success = $result
            Path = $path
            "Free`($unit`)" = $freeBytes
            "total`($unit`)" = $totalBytes
            "totalFree`($unit`)" = $totalFreeBytes
        }
    }
}

function Log-Message {
	param (
		[string]$format,
		[Array]$params = ""
	)

	$msg = [string]::Format( $format, $params )
	$msg
}

function Send-Email {
	param (
		[string]$recipient
		[string]$subject
		[string]$body
		[string]$attachments
	)

	Log-Message "Enviando email..."

	start-process `
	-FilePath "enviar-email" `
	-ArgumentList " `
	-de      alemamikrotik@gmail.com
	-para    $recipient
	-asunto  $subject
	-mensaje $body
	-adjuntos $attachments" `
	-RedirectStandardOutput "backup-out.log" -RedirectStandardError "backup-err.log"
}

function Run-Backup {
	param (
		[string]$flags
	)

	Log-Message "Haciendo backup: $flags"

	start-process `
	-FilePath "HVBackup" `
	-ArgumentList $flags `
	-RedirectStandardOutput "backup-out.log" -RedirectStandardError "backup-err.log"
}

function Rotate-Files {
	param (
		[string]$path
		[byte]$days
	)

	Log-Message "Rotando backups previos..."

	$files = get-childitem -path $path -recurse | where-object {-not $_.PsIsContainer}

	if ($files.count -gt $days) {
		$files | sort-object CreationTime | select-object -first ($files.Count - $days) | remove-item -force -whatif
	}
}

function Main {
	$emailTo = "alema5@gmail.com"
	$days = 7
	$destination = "\\192.168.2.202\backupvh"
	$vmsfile = "maquinas.txt"

	try {
		$backupFlags = "-output $destination"

		if (Test-Path $vmsFile -and (Get-Item $vmsFile).length -gt 0kb) {
			$backupFlags = "$backupFlags -f $vmsFile"
		} else {
			$backupFlags = "$backupFlags -all"
		}

		Run-Backup $backupFlags
	} catch {
		$server = Get-Content env:computername
		$diskInfo = Get-DiskFreeSpaceEx $destination "gb"

		if (Test-Path "backup-err.log" -and (Get-Item "backup-err.log").length -gt 0kb) {
			$attachments = "$attachments,backup-err.log"
		}

		if (Test-Path "backup-out.log" -and (Get-Item "backup-out.log").length -gt 0kb) {
			$attachments = "$attachments,backup-out.log"
		}

		$errorMessage = $_.Exception.Message
		$failedItem = $_.Exception.ItemName

		Send-Email `
		$emailTo `
		"$server: Hyper-V Backup Error: $failedItem" `
		"Mensaje: $errorMessage </br> Información adicional: $diskInfo" `
		$attachments
	} finally {
		Rotate-Files "$destination\*.zip" $days
	}
}

# La ejecución empieza aquí
Main
