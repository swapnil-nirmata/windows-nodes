Param(

    [parameter(Mandatory = $false)] $BaseDir="c:\k",
    [parameter(Mandatory = $false)] $ClusterCIDR="10.244.0.0/16",
    [parameter(Mandatory = $false)] $ServiceCIDR="10.10.0.0/16",
    [parameter(Mandatory = $false)] $InterfaceName="Ethernet0",
    [parameter(Mandatory = $false)] $Release = "1.21.5",
    [parameter(Mandatory = $false)] $NanosServerImageTag = "10.0.17763.802",
    [parameter(Mandatory = $false)] $ServerCoreImageTag = "ltsc2019",
    [parameter(Mandatory = $false)] $webproxy = "http://nibr-proxy.global.nibr.novartis.net:2011",
    [parameter(Mandatory = $false)] [switch] $Reset=$false
)


$Global:BaseDir=$BaseDir
$Global:Release= $Release
$Global:LogDir=[io.Path]::combine($Global:Dir,"log")
$Global:GithubSDNRepository = 'Microsoft/SDN'
$Global:GithubSDNBranch = 'master'
$Global:NanosServerImageTag = $NanosServerImageTag
$Global:NanoServerImageName = "mcr.microsoft.com/windows/nanoserver"
$Global:ServerCoreImageTag = $ServerCoreImageTag
$Global:ServercoreImageName = "mcr.microsoft.com/windows/servercore"
$Global:NetworkName="vxlan0"
$Global:NetworkMode="overlay"
$Global:ServiceCidr= $ServiceCIDR
$Global:CniPath=$Global:BaseDir
# $Global:ManagementIp="10.10.1.161"
$Global:InterfaceName=$InterfaceName
$Global:ClusterCidr=$ClusterCIDR
#$Global:KubeletFeatureGates="RotateKubeletClientCertificate=true"
$Global:KubeproxyFeatureGates="WinOverlay=true,IPv6DualStack=false"
$Global:webproxy = "http://nibr-proxy.global.nibr.novartis.net:2011"

function InstallPauseImage() 
{
    # Prepare POD infra Images
    $infraPodImage=docker images kubeletwin/pause -q
    if (!$infraPodImage)
    {
        Write-Host "No infrastructure container image found. Building kubeletwin/pause image"
        pushd
        cd $Global:BaseDir
        #DownloadFile -Url "https://github.com/$Global:GithubSDNRepository/raw/$Global:GithubSDNBranch/Kubernetes/windows/Dockerfile" -Destination $Global:BaseDir\Dockerfile
        Invoke-WebRequest -Uri "https://github.com/$Global:GithubSDNRepository/raw/$Global:GithubSDNBranch/Kubernetes/windows/Dockerfile" -OutFile  $Global:BaseDir\Dockerfile -Proxy $webproxy
        #docker build -t kubeletwin/pause .
        popd
    }
}

function InstallPauseImage() 
