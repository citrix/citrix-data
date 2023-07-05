$DeliveryController = "YOUR_DDC_ADDRESS" 
$passwordRaw = “YOUR_PASSWORD”

#Import-Module .\ConvertTo-FlatObject.ps1


$filter='$filter'
$select='$select'
$expand = '$expand'

function Execute-Odata($resource)
{

        ### setting up authentication for onprem DDC ####
        $password = ConvertTo-SecureString "$passwordRaw" -AsPlainText -Force
        $credential = New-Object System.Management.Automation.PSCredential ('YOUR_DOMAIN\YOUR_USER', $password)

 
        $InvokeRestMethodParams = @{
                Uri = "http://$DeliveryController/Citrix/Monitor/OData/v4/Data/"+$resource
            }
            if ($Credential) {
                $InvokeRestMethodParams.Add("Credential", $Credential)
            } else {
                $InvokeRestMethodParams.Add("UseDefaultCredentials", $true)
            }
            
         $Result = Invoke-RestMethod @InvokeRestMethodParams 

         return $Result.value 

 }



##get all the machines that are active

Write-Host "###### Get all the machines that are active ##########"
Execute-Odata -resource 'Machines?$filter=LifecycleState eq 0 '  | Format-Table

## Get all the sessions that are active
Write-Host "###### Get all the sessions that are active ##########"
Execute-Odata -resource 'Sessions?$filter=StartDate gt 2020-03-01 &$expand=Machine($select=Name;$expand=DesktopGroup($select=Name)),User($select=FullName)&$select=StartDate,LogonDuration&orderby=LogOnDuration desc' | Format-Table


# get all the Apllicaitons published on environemnt
Write-Host "###### Get all the Apllicaitons published on environemnt ##########"
Execute-Odata -resource 'Applications?$filter=LifecycleState eq 0'| Format-Table


#Get all the failed sessions
Write-Host "###### Get all the failed sessions ##########"
Execute-Odata -resource 'Sessions?$filter=ConnectionState ne 3 or FailureDate gt 2020-12-04T15:08:25.000Z' | Format-Table


#get information on all application instance and associated application name and session information
Execute-Odata -resource "ApplicationInstances?$filter=StartDate gt 2020-03-01 &$expand=Application($filter=PublishedName eq 'Chrome'),Session"

#get summaries like total session launch, disconnected sessions etc
Execute-Odata -resource "SessionActivitySummaries?$filter=Granularity eq 1440 and DesktopGroupId eq c85b8056-515f-4aeb-b4b9-ba8484641299 &$expand=desktopgroup($select=Name)" | Select  CreatedDate,DesktopGroupId,DesktopGroup,ConnectedSessionCount,DisconnectedSessionCount | Format-Table
