param(
    #Servername of the serverlog to monitor
    [Parameter(Mandatory=$true)]    
    [string]$Servername,
    #Line to watch for and end monitoring if found
    [Parameter(Mandatory=$false)]    
    [string]$Breakline = "## OS CORE DEPLOYMENT FINISHED ##",
    #If we do not want to start from the beginning, we can choose the line with matching content to start from.
    [Parameter(Mandatory=$false)]    
    [string]$Startline = $null,
    #What is the path of the logfile?
    [Parameter(Mandatory=$false)]    
    [string]$Path
)

$FilePath = ""
$i=0
$Maxtries = 720
$SecondsTowait = 15
$Startindex = $null

Do{
    #File that is going to be read.
    $Content = Get-content -Path $FilePath
    #We have to set a startindex, if there is none but we have a startline as an argument, so it wont start from the beginning.
    If ($Startindex -eq $null -and $Startline -ne $null){
        $MatchingLine = $Null
        $MatchingLine = $content -match $Startline
        $Startindex = $content.indexof($Startline)+1 
    }
    #Alternative if there is nothing it will start from 0. Mostly this is on the first run.
    elseif ($Startindex -eq $null -and $startline -eq $null){
        $Startindex = 0
    }
    #Lets determine where the end is. If our target line is inside of the file, just output the content until it is reached.
    If ($content -match $Breakline){
        $MatchingLine = $Null
        $MatchingLine = $content -match $Breakline
        $Endindex = $content.IndexOf($MatchingLine)
    }
    #If the target line is not inside of the file go to the end.
    else {
        $Endindex = $Content.Length-1
    }
    #output the whole file until the end is reached. $c gets counted 1 after the end of the file. This will be used as the next starting point.
    For($c=$Startindex;$c -le $Endindex;$c++){
        write-host $content[$c]
    }
    #Set the last index as the new starting point, if the target line is not found.
    $Startindex=$c

    #If the target line is not inside wait an amount of time to try again.
    If ($content[$c-1] -notmatch $Breakline){
        If ($i -ne $Maxtries){
            $i++
            Start-Sleep -Seconds $SecondsTowait
            write-host -BackgroundColor DarkBlue "Amount taken: $i; Last Line $($content[$c-1]); Time taken: $($SecondsTowait*$i)"
        }
        else{
            write-host "Timeout occured. It took too long to wait for $Breakline"
            break
        }
    }
}
#go out of the loop if the target line is found.
until ($content -match $Breakline)