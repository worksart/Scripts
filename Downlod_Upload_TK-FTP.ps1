param (
    $remotePathDone = "/OutTest/Spending/",
    $CompanyPath = "C:\1C\Test",
    $logdownload = "C:\1C\logdownload.log",
    $logupload = "C:\1C\logupload.log",
    
    $RemotePath = "/OutTest",
    $LocalPath  = "C:\1C\Test"
)
 #FTP:\OutTest\Spending\<Company>\Done  пере местить в Test\<company> на сервер 1С

 
 #перекладывает из 1С  Test\<Company>\Error\Spending  в FTP:\OutTest\Spending\<Company>.

 #Перекладывает файлы из папки на FTP:OUTTEST\<company>\Done  на 1С сервер в Test\<company>

 #Перекладывает с 1С сервера Test\<company>\Error  в FTP:\OutTest\<Company>\ 


 Function Write-Log {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$False)]
    [ValidateSet("INFO","WARN","ERROR","FATAL","info")]
    [String]
    $Level = "INFO",

    [Parameter(Mandatory=$True)]
    [string]
    $Message,

    [Parameter(Mandatory=$False)]
    [string]
    $logfile
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"
    If($logfile) {
       Add-Content $logfile -Value $Line
    }
    Else {
        Write-Output $Line
    }
   }

try
{
    # Load WinSCP .NET assembly
    Add-Type -Path "WinSCPnet.dll"
 
    # Setup session options
    $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
        Protocol = [WinSCP.Protocol]::ftp
        HostName = "Localhost"
        UserName = "admin"
        Password = "12345"
        #SshHostKeyFingerprint = "ssh-rsa 2048 xx:xx:xx:xx:xx:xx:xx:xx..."
    }
 
    $session = New-Object WinSCP.Session
    $time = get-date -Format g
    try
    {
        # Connect
        $session.Open($sessionOptions)
 
        # Upload files
        $transferOptions = New-Object WinSCP.TransferOptions
        $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
        $transferstatus = $null
        $transferstatus2 = $null
        $FilesToDownload = $session.EnumerateRemoteFiles("$RemotePath",$null,"AllDirectories") |? {$_.name -like "*.pdf" -or $_.name -like "*.xml"} | Select Fullname
        $FilesToDownload.fullname |% {
            $CurFile = $_
            $Path = ($_ -split "/")[-2]
            $Company = ($_ -split "/")[-3]
 
            $DstPath = "$LocalPath\$Company"
            
            if (!(Test-Path "$DstPath")) { New-Item -ItemType Directory -Path "$DstPath" -force }
            $transferDownloadStatus =  $session.GetFiles($CurFile, "$DstPath\", $False, $transferOptions) ##### True for move file (False to copy)
           # Write-Host "Download on $CurFile in $DstPath\"
            "$time Download file: $CurFile in FTP: $DstPath\" |Out-File -Encoding ascii -Append $logdownload 
            #$transferstatus += $transferDownloadStatus 
        }

        $FilesToUpload = Get-ChildItem "$LocalPath" -recurse |? {$_.name -like "*.pdf" -or $_.name -like "*.xml"} | Select Fullname 
        $FilesToUpload = $FilesToUpload |? {$_ -like "*\Error\*"}
       foreach ($curfiletoupload in $($FilesToUpload.FullName)) { 
            $CurLFile = $curfiletoupload
            $isSpending = ($curfiletoupload -split "\\")[-2]
            #$Company = ($_ -split "\\")[2]
            switch ($isSpending) {
                "Spending" {
                    $Company = ($curfiletoupload -split "\\")[-4]
                    $FtpPathToUpload = "$RemotePath/Spending/$Company"                    
                }
                Default {
                    $Company = ($curfiletoupload -split "\\")[-3]
                    $FtpPathToUpload = "$RemotePath/$Company"
                }
            }
            $transferUploadStatus = $session.PutFiles("$curfiletoupload", "/$FtpPathToUpload/", $false, $transferOptions)   ##### True for move file (False to copy)
            #Write-Host "Current file to upload: $curfiletoupload move to: $FtpPathToUpload/"
            "$time Current file: $curfiletoupload upload to: $FtpPathToUpload/" | out-file -Encoding ascii $logupload -Append
            #$transferstatus2 += $transferUploadStatus      
        }
        
        if ($FilesToDownload -eq $null){
           
           Write-Host "Download - 0"
            }
        
        if ($FilesToUpload -eq $null){
            Write-Host "Upload - 0"
        }
            #Write-Log -Level INFO -Message "Upload of $($FilesToDownload) succeeded, moving to $DstPath" -LogFile $logdownload
            #Write-Log -Level INFO -Message "Upload of $() succeeded, moving to $DstPath" -LogFile $logdownload


<#      
        foreach ($transfer in $transferResultDone.Transfers) {#  Done path transfer success or error?

            if ($transfer.Error -eq $Null )
            {
                Write-Host ("Upload of {0} succeeded, moving to $CompanyPath\$Path" -f $transfer.FileName )
                Write-Log -Level INFO -Message "Upload of $($transfer.FileName) succeeded, moving to $CompanyPath\$Path" -LogFile $logdownload
            }

            else
            {
                Write-Host ("Upload of {0} failed: {1}" -f $transfer.FileName, $transfer.Error.Message)
                Write-Log ERROR "Upload of $($transfer.FileName) failed: $($transfer.Error.Message)" $logdownload
            }
        }
        
        
  #Error path  transfer success or error?      
        foreach ($transfer in $transferResultDone.Transfers) {
            if ($transferResultError -eq $null) {
                Write-Host ("Upload of {0} succeeded, moving to $remotePathDone\$Company\$Path" -f $transfer.FileName )
                Write-Log -Level INFO -Message "Upload of $($transfer.FileName) succeeded, moving to $remotePathDone\$Company\$Path" -LogFile $logdownload
            }
            else {
                Write-Host ("Upload of {0} failed: {1}" -f $transfer.FileName, $transfer.Error.Message)
                Write-Log ERROR "Upload of $($transfer.FileName) failed: $($transfer.Error.Message)" $logdownload
            }
        }
#>        
    }
    finally {
        # Disconnect, clean up
        $session.Dispose()
    }
    exit 0
}
catch {
    Write-Host "Error: $($_.Exception.Message)"
    exit 1
}
