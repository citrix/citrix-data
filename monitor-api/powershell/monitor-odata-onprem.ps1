#requires -version 3

<#
    Get Monitor data using the OData API (on-prem)
#>

<#
.SYNOPSIS

Send queries to Citrix Director and return/write the results back as JSON or CSV objects

.PARAMETER ddc

The Delivery Controller to query. Defaults to localhost

.PARAMETER outputfile

Name and path to write output to. If it exists, use -overwrite to overwrite.
Pseudo environment variables like %day% and %month% can be used in the folder and/or file name and will be created as necessary

.PARAMETER overwrite

If specified as "yes", any existing output file will be overwritten otherwise the script will fail if the outoput file already exists

.PARAMETER flatten

If specified as "yes", any nested JSON fields will be flattened by using '.', e.g. Machine.DesktopGroup.Name. This is by default applied for CSV.

.PARAMETER format

The output format to use. If not specified it will be determined from the output file extension

.PARAMETER outputEncoding

The output encoding to use. Defaults to UTF8

.PARAMETER query

The ODATA query

.PARAMETER maximumItems

The maximum number of items to return although as results are returned in pages, it may be slightly more than this number

.PARAMETER oDataVersion

The version of OData to use in the query. Defaults to 4

.PARAMETER username

The username to use when querying the Delivery Controller. If not specified the user running the script will be used

.PARAMETER password

The password for the account named by -username, as a SecureString. Omit it to be prompted with masked
input, or set the %CITRIX_MONITOR_PASSWORD% environment variable for unattended runs. Do not build a
SecureString from a plain string on the command line - the plain value would be written to PowerShell
console history and captured by process-creation logging. Populate the environment variable from a secret
store or from your scheduler: typing it into the console puts it in history just the same, and setx writes
it to the registry permanently.

.PARAMETER protocol

The protocol used to reach the Delivery Controller. Defaults to https.

Use http only on a network you trust: it sends the query results - which can include user names, UPNs,
machine names and client IP addresses - in clear text, and it gives the client no way to verify that it is
talking to the real Delivery Controller. The Windows authentication exchange is also unprotected. See
"Securing on-premises Monitor OData API access" in the Monitor Service OData API documentation for how to
enable SSL on the controller.



.EXAMPLE

'.\<script>' -username <UserName> -query "Users" -outputFile out.json -format json -overWrite yes -Verbose

Get list of users, prompting for the password with masked input

.EXAMPLE

'.\<script>' -username <UserName> -query "Applications?`$filter=LifecycleState eq 0&`$count=true" -outputFile c:\logs\%year%\%monthname%\citrix.odata.%hour%.%minute%.%second%.csv

Get active applications

.EXAMPLE

'.\<script>' -ddc <DeliveryController> -protocol http -query "Users"

Query a controller that has no SSL certificate bound. Only do this on a network you trust

.NOTES

Reference:
https://developer-docs.citrix.com/en-us/monitor-service-odata-api

Reference:
https://github.com/guyrleech/Citrix/blob/master/Get%20Citrix%20OData%20data.ps1

In the queries below, you need to escape all '$' characters in the query with the use of '`', e.g. '`$count'
You also need to replace any placeholder values (e.g. {start_time}) with an actual value, possibly calculated within the script.


Other Examples:

- Citrix DaaS ICA Round Trip Time (RTT)
  This is the time interval measured at the client between the first step (user action) and the last step (graphical response displayed). This metric can be thought of as a measurement of the screen lag that a user experiences while interacting with an application hosted in a session.
  URL: SessionMetrics?$filter=CollectedDate gt {start_time} and IcaRttMS gt 0&$select=CollectedDate,IcaRttMS&$expand=Session($select=ConnectionStateChangeDate;$expand=User($select=upn),Machine($select=DnsName))

  Session RTT?
  SessionMetrics?$filter=(SessionId eq $SessionKey)

- Session summary
  Hourly summary of session counts by delivery group.
  URL: SessionActivitySummaries?$filter=Granularity eq 60 and SummaryDate gt {start_time}&$select=SummaryDate,ConnectedSessionCount,DisconnectedSessionCount,ConcurrentSessionCount&$expand=DesktopGroup($select=Id,Name)

  Includes session usage?

- Application launches
  URL: ApplicationInstances?$filter=(StartDate gt {start_time})&$select=StartDate&$expand=Session($select=SessionType;$expand=User($select=upn),Machine($select=DnsName),Connections($select=ClientName,ClientPlatform,ClientVersion,ConnectedViaIPAddress)),Application($select=Name)"

- Desktop launches
  URL: Connections?$filter=(LogOnStartDate gt {start_time})&$select=LogOnStartDate,ClientName,ClientPlatform,ClientVersion,ConnectedViaIPAddress&$expand=Session($filter=SessionType eq 0;$select=SessionType;$expand=User($select=upn),Machine($select=DnsName))"

- VDA Availability
  Hourly summary of VDA availability by delivery group.
  URL: MachineSummaries?$filter=Granularity eq 60 and SummaryDate gt {start_time}&$select=SummaryDate,PoweredOnMachinesCount,RegisteredMachinesCount,MachinesInMaintenanceModeCount,MachinesCount&$expand=DesktopGroup($select=Id,Name)"

  Can include Machines in a failure state?

- Machine CPU, Memory and disk usage (during a user session)
    ResourceUtilization?$filter=MachineID eq $MachineID and CollectedDate gt $SessionStartDate and CollectedDate lt $SessionEndDate

- Last logon time for a user session
    Sessions?$filter=(CreatedDate gt $CreatedDate) and (User/Username eq 'MYUSER')&$expand=User($select=username,upn),Connections($select=LogonStartDate,ClientName,ConnectedViaIPAddress;$OrderBy=LogonStartDate Desc;$top=1)&OrderBy=StartDate Desc&$top=1


#>

[CmdletBinding()]
Param
(
    [string]$ddc = 'localhost',
    [string]$query ,
    [int]$maximumItems = 0 ,
    [ValidateSet('csv','json')]
    [string]$format = 'csv' ,
    [ValidateSet( 'String' , 'Unicode' , 'Byte' , 'BigEndianUnicode' , 'UTF8' , 'UTF7' , 'UTF32' , 'Ascii' , 'Default' , 'Oem' , 'BigEndianUTF32' )]
    [string]$outputEncoding = 'UTF8' ,
    [ValidateSet('Yes','No')]
    [string]$overWrite = 'No' ,
    [string]$flatten = 'No' ,
    [string]$csvOutputDelimiter = ',',
    [string]$outputFile ,
    [string]$username ,
    [securestring]$password ,
    [ValidateSet('https','http')]
    [string]$protocol = 'https' ,
    [int]$oDataVersion = 4 ,
    [int]$retryMilliseconds = 1000
)

# $VerbosePreference="Continue"


Function Flatten-Object {                                       # Version 00.02.12, by iRon
    [CmdletBinding()]Param (
        [Parameter(ValueFromPipeLine = $True)][Object[]]$Objects,
        [String]$Separator = ".", [ValidateSet("", 0, 1)]$Base = 1, [Int]$Depth = 5, [Int]$Uncut = 1,
        [String[]]$ToString = ([String], [DateTime], [TimeSpan]), [String[]]$Path = @()
    )
    $PipeLine = $Input | ForEach {$_}; If ($PipeLine) {$Objects = $PipeLine}
    If (@(Get-PSCallStack)[1].Command -eq $MyInvocation.MyCommand.Name -or @(Get-PSCallStack)[1].Command -eq "<position>") {
        $Object = @($Objects)[0]; $Iterate = New-Object System.Collections.Specialized.OrderedDictionary
        If ($ToString | Where {$Object -is $_}) {$Object = $Object.ToString()}
        ElseIf ($Depth) {$Depth--
            If ($Object.GetEnumerator.OverloadDefinitions -match "[\W]IDictionaryEnumerator[\W]") {
                $Iterate = $Object
            } ElseIf ($Object.GetEnumerator.OverloadDefinitions -match "[\W]IEnumerator[\W]") {
                $Object.GetEnumerator() | ForEach -Begin {$i = $Base} {$Iterate.($i) = $_; $i += 1}
            } Else {
                $Names = If ($Uncut) {$Uncut--} Else {$Object.PSStandardMembers.DefaultDisplayPropertySet.ReferencedPropertyNames}
                If (!$Names) {$Names = $Object.PSObject.Properties | Where {$_.IsGettable} | Select -Expand Name}
                If ($Names) {$Names | ForEach {$Iterate.$_ = $Object.$_}}
            }
        }
        If (@($Iterate.Keys).Count) {
            $Iterate.Keys | ForEach {
                Flatten-Object @(,$Iterate.$_) $Separator $Base $Depth $Uncut $ToString ($Path + $_)
            }
        }  Else {$Property.(($Path | Where {$_}) -Join $Separator) = $Object}
    } ElseIf ($Objects -ne $Null) {
        @($Objects) | ForEach -Begin {$Output = @(); $Names = @()} {
            New-Variable -Force -Option AllScope -Name Property -Value (New-Object System.Collections.Specialized.OrderedDictionary)
            Flatten-Object @(,$_) $Separator $Base $Depth $Uncut $ToString $Path
            $Output += New-Object PSObject -Property $Property
            $Names += $Output[-1].PSObject.Properties | Select -Expand Name
        }
        $Output | Select ([String[]]($Names | Select -Unique))
    }
}; Set-Alias Flatten Flatten-Object



if( -Not [string]::IsNullOrEmpty( $outputFile ) )
{
    ## format not specified so get from output file extension
    if( -not $PSBoundParameters[ 'format' ] )
    {
        try
        {
            $format = $outputFile -replace '^.*\.(\w+)$' , '$1'
        }
        catch
        {
            Throw "Cannot determine a supported output format from output file extension on $outputFile"
        }
    }

    if( $outputFile.IndexOf( '%' ) -ne $outputFile.LastIndexOf( '%' ) )
    {
        $now = [datetime]::Now
        $outputFile = $outputFile -replace '%year%' , $now.ToString( 'yyyy' ) -replace '%month%' , $now.ToString( 'MM' ) -replace '%day%' , $now.ToString( 'dd') -replace '%monthname%' , $now.ToString( 'MMMM' ) -replace '%dayname%' , $now.ToString( 'dddd') `
            -replace '%hours?%' , $now.ToString( 'HH')  -replace'%minutes?%' , $now.ToString( 'mm') -replace '%seconds?%' , $now.ToString( 'ss')
        [string]$logFolder = Split-Path -Path $outputFile -Parent
        if( (-Not [string]::IsNullOrEmpty( $logFolder )) -and (-Not ( Test-Path -Path $logFolder -PathType Container )))
        {
            if( -Not( New-Item -Path $logFolder -ItemType Directory -Force ) )
            {
                Write-Warning -Message "Failed to create log folder $logFolder"
            }
        }
    }
    
    if( (Test-Path -Path $outputFile) -and $overwrite -ine 'yes' )
    {
        Throw "Cannot proceeed as output file `"$outputFile`" already exists and -overwrite not used"
    }
}

[hashtable]$outputProcessors = @{
    'csv' =    @{ Command = 'ConvertTo-csv'  ; Arguments = @{ 'NoTypeInformation' = $true ; 'Delimiter' = $csvOutputDelimiter } }
    'json' =   @{ Command = 'ConvertTo-Json' ; Arguments = @{ 'Depth' = 10 } }
}

if( $outputProcessor = $outputProcessors[ $format ] )
{
    $outputCommand = $outputProcessor.Command
    $outputArguments = $outputProcessor.Arguments
}
else
{
    Throw "Unsupported output format $format"
}



[hashtable]$params = @{}


if( $PSBoundParameters[ 'username' ] )
{
    if( $null -eq $password )
    {
        ## lets an unattended caller supply the password without putting it on the command line, where it
        ## would land in console history and in process-creation logs
        if( -Not [string]::IsNullOrEmpty( $env:CITRIX_MONITOR_PASSWORD ) )
        {
            $password = ConvertTo-SecureString -AsPlainText -String $env:CITRIX_MONITOR_PASSWORD -Force
        }
        else
        {
            $password = Read-Host -Prompt "Password for $username" -AsSecureString
        }
    }
    if( $null -eq $password -or $password.Length -eq 0 )
    {
        Throw "Must specify password when using -username either via -password or %CITRIX_MONITOR_PASSWORD%"
    }
    $credential = New-Object System.Management.Automation.PSCredential( $username , $password )
}

if( $credential )
{
    $params.Add( 'Credential' , $credential )
    if( $protocol -ieq 'http' )
    {
        Write-Warning -Message "Authenticating over http to $ddc - credentials and results are not encrypted in transit"
        ## PowerShell 6+ refuses to send credentials over an unencrypted connection unless this is set,
        ## so without it -protocol http fails before the request is made. The parameter does not exist
        ## on Windows PowerShell 5.1, which sends the request either way.
        if( $PSVersionTable.PSVersion.Major -ge 6 )
        {
            $params.Add( 'AllowUnencryptedAuthentication' , $true )
        }
    }
}

$updated_query = $query -replace '\`' , ''
## braces around the variable name are required, otherwise "$protocol:" parses as a scope qualifier
$params[ 'Uri' ] = "${protocol}://$ddc/Citrix/Monitor/OData/v$oDataVersion/Data/$updated_query"


Write-Verbose "URL: $($params.Uri)"


[int]$exitNow = 0
[array]$data = @( do
{
    try
    {
        [int]$results = 0
        [int]$requests = 0
        [string]$lasturi = $params.uri
        [bool]$firstQuery = $true
        [int]$countOfItems = 0

        do
        {
            $requests++
            $resultsPage = $null
            $resultsPage = Invoke-RestMethod @params

            if( $null -ne $resultsPage )
            {
                if( $firstQuery )
                {
                    if( $resultsPage.psobject.Properties[ '@odata.count' ] )
                    {
                        $countOfItems = $resultsPage.'@odata.count'
                        Write-Verbose -Message "$countOfItems items fetched"
                    }
                    $firstQuery = $false
                }
                $results += ( $resultsPage | Select-Object -ExpandProperty Value | Measure-Object).Count
                # $resultsPage.'odata.Value'

                $resultsPage | Select-Object -ExpandProperty Value

                ## https://support.citrix.com/article/CTX312284
                if( $resultsPage.PSObject.Properties['@odata.nextLink' ] -and -not [string]::IsNullOrEmpty( $resultsPage.'@odata.nextLink' ) )
                {
                    $params.uri = $resultsPage.'@odata.nextLink' ## -replace [regex]::Escape( $countQuery )
                    ## prevent infinite loop if something goes wrong
                    if( $params.uri -ne $lasturi )
                    {
                        Write-Verbose -Message "More data available ($($countOfItems - $results)), fetching from $($params.uri)"
                        $lasturi = $params.uri
                    }
                    else
                    {
                        Write-Warning -Message "Next link $lasturi is the same as the previous one so aborting loop"
                        break
                    }
                }
                else ## no further results available so quit loop
                {
                    break
                }
            }
        } while( $resultsPage -and ( $maximumItems -le 0 -or $results -lt $maximumItems ))
        Write-Verbose -Message "Got $results query results in total across $requests requests"
            
        $fatalException = $null
        break ## since call(s) succeeded so that we don't report for lower versions
    }
    catch
    {
        $fatalException = $_
        if( $fatalException.Exception.Response.StatusCode -eq 429 ) ##  Too Many Requests
        {
            Write-Verbose -Message "$(Get-Date -Format G) : too many requests error so will retry after $($retryMilliseconds)ms"
            Start-Sleep -Milliseconds $retryMilliseconds
        }
        else ## something unrecoverable so exit loop
        {
            $exitNow = 1
        }
    }
} while ( $exitNow -eq 0 ) )

if( $fatalException )
{
    Throw $fatalException
}

if( $data -and $data.Count )
{
    Write-Verbose -Message "Got $($data.Count) results"

    if( $format -eq "csv" )
    {
        $finalOutput = $data | Flatten-Object | . $outputCommand @outputArguments ## output to stdout
    }
    else
    {
        if ($flatten -ieq 'yes')
        {
            $finalOutput = $data | Flatten-Object | . $outputCommand @outputArguments
        }
        else
        {
            $finalOutput = $data | . $outputCommand @outputArguments
        }
    }

    if( [string]::IsNullOrEmpty( $outputFile ) )
    {
        $finalOutput
    }
    else
    {
        $written = $null
        $finalOutput | Set-Content -Path "$outputFile.tmp" -Encoding $outputEncoding
        # Post processing step to remove the odata.id fields
        if( $format -eq "csv" )
        {
            Import-Csv "$outputFile.tmp" | Select-Object -Property * -ExcludeProperty "*@odata.id" | Export-Csv -Path "$outputFile" -NoTypeInformation
        }
        else
        {
            Get-Content -Path "$outputFile.tmp" | Select-String -Pattern '@odata.id' -NotMatch | Set-Content -Path "$outputFile"
        }
        Remove-Item -Path "$outputFile.tmp"
        if( $? )
        {
            Write-Verbose -Message "Wrote $($finalOutput.Length) items to `"$outputFile`""
        }
    }
}
else
{
    Write-Warning "No data returned"
}
