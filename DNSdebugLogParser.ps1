<#
.SYNOPSIS
     Microsoft DNS server log parser
.DESCRIPTION     
 Reads log file (created by Windows Server DNS debug logging)
 and displays statistics:
     - number of DNS requests recieved from certain IP
     - list of FQDNs each DNS client tried to resolve
 .PARAMETER param_pathToLogFile 
     path to DNS log file
 .NOTES
 hardcoded constant $nrOfLinesToProcess = 1000000  - change it if you feel your sistem can handle bigger files
 WARNING! don't run it on production systems. It read all log file to memory (for performance reasons)
 what can cause problems in certain situations.
 Author: Aleksandr Reznik (aleksandr@reznik.lt)
#>

param(
[string]$param_pathToLogFile="C:\logfiles\dnsdebug.log"
)

$ipCountHT = @{} #hashtable contaiining number of requests recieved from certain IPs
$ip2fqdnHT = @{} #hashtable containing FQDNs beeing resolved by certain IPs
$currLineNr = 0
$nrOfLinesToProcess = 1000000
$AMPMpresent = $false
$startTime= Get-Date
write-host "Reading file to memory.. please wait"
$fileContnents = Get-Content $param_pathToLogFile
write-host "File reading elapsed time: $((Get-Date) - $startTime)"
$startTime= Get-Date
foreach($line in $fileContnents)
{
     if( ([byte]$line[0] -lt 58) -and ([byte]$line[0] -gt 47)){
          if($line.Length -gt 72){
               $currLineNr++
               
               #using first line to determine if format contains AM/PM 
               if($currLineNr -eq 1){ 
                    if($currArray1[2] -eq "am" -or $currArray1[2] -eq "pm"){
                         $AMPMpresent = $true
                    }
                    else{
                         $AMPMpresent = $false
                    }
               }

               #writing nr of lines processed for each new 100 lines
               if (($currLineNr % 100) -eq 0){ 
                    write-host "Line nr: $($currLineNr)"     
               }

               #if limit of lines to process specified in parameter is reached - stopping processing the file
               if ($currLineNr -gt $nrOfLinesToProcess){ 
                    break
               }
               $line2partsTEMP = $line.Split("]")
               $currArray1 = $line2partsTEMP[0].Split(" ")
               
               if ($AMPMpresent){
                    $ipStr=$currArray1[9]
                    $oprName = $currArray1[8]     
               }
               else{
                    $ipStr=$currArray1[8]
                    $oprName = $currArray1[7]
               }
               
               #processing only packets recieved ("Rcv") by server
               if ($oprName -eq "Rcv"){
                    $FQDN = $line2partsTEMP[1].substring(8,$line2partsTEMP[1].length-8)
                    $FQDN = $FQDN -replace "(\(\d+\))","."
                    $FQDN = $FQDN.Substring(1)
                    if ($FQDN -eq ""){
                         $FQDN = "."
                    }
                    
                    #filling ip2fqdn hashtable
                    if($ip2fqdnHT.ContainsKey($ipStr)){
                         if ($ip2fqdnHT[$ipStr].ContainsKey($FQDN)){
                              #do nothing as FQDN is already in a list
                         }
                         else{ #add FQDN
                              $ip2fqdnHT[$ipStr].add($FQDN,"")

                         }
                    }
                    else{
                         $ip2fqdnHT.Add($ipStr,@{$FQDN = ""})

                    }
                    
                    #filling ipCountHT hashtable
                    if ($ipCountHT.ContainsKey($ipStr)){ #if key (IP) already in hash table
                         $currIPcount = $ipCountHT[$ipStr]  
                         $ipCountHT[$ipStr] = $currIPcount + 1
                    }
                    else{# if it is new IP
                         $ipCountHT.Add($ipStr,1)
                    }
               }
          }
     }
}
Write-Host
write-host "Elapsed time: $((Get-Date) - $startTime)"
write-host 
write-host "Table containing number of requests recieved from each IP:" -NoNewline
$ipCountHT.GetEnumerator() | Sort-Object Value -Descending
write-host 

write-host "Table containg list of FQDNs resolved by each IP:"
#foreach ($currip2fqdnHT in $ip2fqdnHT.Keys) { #unsorted version
foreach ($currip2fqdnHT in ($ipCountHT.GetEnumerator() | Sort-Object Value -Descending).Key) {
     Write-Host "IP $($currip2fqdnHT) tried to resolve following FQDNs:"
     foreach($currFQDN in $ip2fqdnHT[$currip2fqdnHT].Keys){
          Write-Host "    $($currFQDN)"
     }
     write-host
     
}
Write-host "Finished!"
