#Requires -Version 7.4
# spell:ignore minlag mmdc infa Oxipng svgo
param()

$RepositoryRoot = Convert-Path "$PSScriptRoot/.."
$MermaidCliVersionMin = [version]'11.12.0'
$MermaidDockerImage = (
    # use GitHub Container Registry in CI
    $env:GITHUB_ACTIONS -eq 'true' `
        ? "ghcr.io/mermaid-js/mermaid-cli/mermaid-cli:$MermaidCliVersionMin" `
        : "docker.io/minlag/mermaid-cli:$MermaidCliVersionMin"
)

Import-Module "$PSScriptRoot/PSTaskFramework/BuildHelpers"

function Test-DockerExists {
    <#
    .DESCRIPTION
        Checks if Docker is present on the system.
        Note that just because Docker is installed doesn't mean it's functional (e.g.
        Docker Desktop may not be running).
    #>
    [OutputType([bool])]
    param()
    $null -ne (Assert-AppExists 'docker' -PassThru -ErrorAction Ignore)
}

function Test-NpmExists {
    <#
    .DESCRIPTION
        Checks if Node.js (npm) is present on the system.
    #>
    [OutputType([bool])]
    param()
    $null -ne (Assert-AppExists 'npm' -PassThru -ErrorAction Ignore)
}

function Convert-MermaidFileToImage {
    <#
    .SYNOPSIS
        Converts a Mermaid file to an image using Mermaid CLI.
    .DESCRIPTION
        This function converts a Mermaid file to an image using Mermaid CLI. It supports
        both local and Docker-based Mermaid CLI installations.

        By default, it will auto-detect if Mermaid CLI is available locally and fall
        back to Docker or Node.js if not (Docker is preferred). You can force the use of
        Docker or Node.js with the -UseDocker or -UseNode parameter.
    #>
    [CmdletBinding(PositionalBinding = $false)]
    param(
        # The path to the Mermaid file to convert.
        [Parameter(Mandatory, Position = 0)]
        [string]$Path,
        # The path to the output image file. The output format is determined by the
        # file extension and must be supported by Mermaid CLI.
        [Parameter(Mandatory, Position = 1)]
        [string]$ImagePath,
        # The path to the Mermaid CLI config file.
        [string] $ConfigFile = (Join-Path $RepositoryRoot 'docs/generated/mermaid-config.json'),
        # The path to the Puppeteer config file for Mermaid CLI.
        [string] $PuppeteerConfigFile = (Join-Path $RepositoryRoot 'docs/generated/puppeteer-config.json'),
        # Force use of Docker to run Mermaid CLI, even if a local installation is available.
        # If both -UseDocker and -UseNode are specified, Docker will be used.
        [switch]$UseDocker,
        # Force use of Node.js to run Mermaid CLI, even if a local installation is available.
        # If both -UseDocker and -UseNode are specified, Docker will be used.
        [switch]$UseNode
    )

    if (!($Path = Convert-Path -LiteralPath $Path)) { return }
    if (!($imageDir = Convert-Path -LiteralPath (Split-Path $ImagePath -Parent))) { return }
    $ImagePath = Join-Path $imageDir (Split-Path $ImagePath -Leaf)
    if (!($ConfigFile = Convert-Path -LiteralPath $ConfigFile)) { return }
    if (!($PuppeteerConfigFile = Convert-Path -LiteralPath $PuppeteerConfigFile)) { return }

    $mmdcCommand = $null
    $mmdcArgs = @(
        '--input', $Path
        '--output', $ImagePath
        '--scale', '4'
        '--svgId', 'deer-isle-egl'
        '--configFile', $ConfigFile
        '--puppeteerConfigFile', $PuppeteerConfigFile
    )

    if (!$UseDocker -and !$UseNode) {
        # Try to find Mermaid CLI locally. If it's not found or the version is too old,
        # we'll fall back to using Docker or Node.js.
        $mmdcCommand = Assert-AppExists 'mmdc' -PassThru -ErrorAction Ignore
        $dockerExists = Test-DockerExists
        $nodeExists = Test-NpmExists

        if ($mmdcCommand) {
            $mmdcVersion = Invoke-Shell -infa Ignore -ea Continue -- $mmdcCommand --version
            if (!$mmdcVersion) {
                # ignore installed mmdc if we can't determine the version
                Write-Warning "Failed to get Mermaid CLI version. Ignoring '$mmdcCommand'."
                $mmdcCommand = $null
            }
            elseif ($mmdcVersion -ge $MermaidCliVersionMin) {
                # looks good
            }
            elseif ($dockerExists -or $nodeExists) {
                Write-Warning "Mermaid CLI $mmdcVersion found but older than $MermaidCliVersionMin. Will use $($dockerExists ? 'Docker' : 'Node.js') instead."
                $mmdcCommand = $null
            }
            else {
                Write-Warning "Mermaid CLI $mmdcVersion found but old. Consider upgrading to $MermaidCliVersionMin or later from https://mermaid.ai/."
            }
        }
        if (!$mmdcCommand) {
            # don't override the user's choice if they explicitly specified -UseDocker:$false
            $UseDocker = $dockerExists -and !$PSBoundParameters.ContainsKey('UseDocker')
            $UseNode = $nodeExists -and !$PSBoundParameters.ContainsKey('UseNode')
            if (!$UseDocker -and !$UseNode) {
                $msg = 'Mermaid CLI (mmdc) not found locally and Docker and Node.js are not available. Please install Mermaid CLI from https://mermaid-js.github.io/mermaid-cli/ or ensure Docker or Node.js are available.'
                Write-Error -Exception $msg -CategoryActivity 'Invoke-MermaidCli' -TargetObject $Path
                return
            }
        }
    }

    # Prefer Docker if both are available, since it ensures a consistent result.
    if ($UseDocker) {
        # map each file to a separate Docker volume...
        $mmdcCommand = @(
            'docker'
            'run'
            '--rm'
            '--volume', "$(Split-Path $Path -Parent):/work/src"
            '--volume', "$(Split-Path $ImagePath -Parent):/work/dst"
            '--volume', "$(Split-Path $ConfigFile -Parent):/work/config"
            if ($IsLinux -or $IsMacOS) { '--user', "$(id -u):$(id -g)" }
            $MermaidDockerImage
        )

        $mmdcArgs = $mmdcArgs.foreach{
            $_ -ceq $Path ? "/work/src/$(Split-Path $_ -Leaf)" :
            $_ -ceq $ImagePath ? "/work/dst/$(Split-Path $_ -Leaf)" :
            $_ -ceq $ConfigFile ? "/work/config/$(Split-Path $_ -Leaf)" :
            $_
        }

        # remove the puppeteer config args since they are not supported in the Docker image
        $mmdcArgs = $mmdcArgs.foreach{
            if ($_ -notIn '--puppeteerConfigFile', $PuppeteerConfigFile) {
                $_
            }
        }
    }
    elseif ($UseNode) {
        $env:NPM_CONFIG_UPDATE_NOTIFIER = 'false' # disable update notifier
        $mmdcCommand = @(
            'npx'
            '--package', "@mermaid-js/mermaid-cli@$MermaidCliVersionMin"
            '--yes' # skip prompts
            'mmdc'
        )
    }

    if ($mmdcCommand -is [string]) {
        $mmdcCommand = @($mmdcCommand)
    }

    Write-Information "Processing: '$Path' -> '$ImagePath'"
    Invoke-Shell -infa $InformationPreference -- @mmdcCommand @mmdcArgs
}

function Optimize-PngImage {
    <#
    .SYNOPSIS
        Optimizes a PNG image.
    .DESCRIPTION
        This function optimizes a PNG image using Oxipng.

        By default, it will auto-detect if Oxipng is available locally and fall back
        to Docker if not. You can force the use of Docker with the -UseDocker parameter.
    #>
    [CmdletBinding(PositionalBinding = $false)]
    param(
        # The path to the PNG image to optimize.
        [Parameter(Mandatory, Position = 0)]
        [string]$ImagePath,
        # Force use of Docker, even if a local installation is available.
        [switch]$UseDocker
    )

    if (!($ImagePath = Convert-Path -LiteralPath $ImagePath)) { return }

    # See https://github.com/oxipng/oxipng/blob/master/MANUAL.txt
    $oxipngCommand = $null
    $oxipngArgs = @(
        '--opt', '4' # optimization level
        '--strip', 'safe' # remove all non-critical metadata chunks except those that affect the image appearance
        $ImagePath
    )

    if (!$UseDocker) {
        $oxipngCommand = Assert-AppExists 'oxipng' -PassThru -ErrorAction Ignore
        if (!$oxipngCommand) {
            # don't override the user's choice if they explicitly specified -UseDocker:$false
            $UseDocker = (Test-DockerExists) -and !$PSBoundParameters.ContainsKey('UseDocker')
            if (!$UseDocker) {
                Write-Warning 'Skipping PNG optimization: Oxipng not found locally and Docker is not available. Install Oxipng from https://github.com/oxipng/oxipng or ensure Docker is available.'
                return
            }
        }
    }

    if ($UseDocker) {
        # map file to a Docker volume...
        $oxipngCommand = @(
            'docker'
            'run'
            '--rm'
            '--volume', "$(Split-Path $ImagePath -Parent):/work"
            if ($IsLinux -or $IsMacOS) { '--user', "$(id -u):$(id -g)" }
            'ghcr.io/oxipng/oxipng:v10.1.1'
        )
        $oxipngArgs = $oxipngArgs.foreach{
            $_ -ceq $ImagePath ? "/work/$(Split-Path $ImagePath -Leaf)" :
            $_
        }
    }

    if ($oxipngCommand -is [string]) {
        $oxipngCommand = @($oxipngCommand)
    }

    Write-Information 'Optimizing image with Oxipng...'
    Invoke-Shell -infa $InformationPreference -- @oxipngCommand @oxipngArgs
}

function Optimize-SvgImage {
    <#
    .SYNOPSIS
        Optimizes an SVG image.
    .DESCRIPTION
        This function optimizes an SVG image using SVGO.

        By default, it will auto-detect if SVGO is available locally and fall back
        to Node.js or Docker if not (Node.js is preferred since it is a quicker download).
        You can force the use of Node.js or Docker with the -UseNode or -UseDocker parameter.
    #>
    [CmdletBinding(PositionalBinding = $false)]
    param(
        # The path to the SVG image to optimize.
        [Parameter(Mandatory, Position = 0)]
        [string]$ImagePath,
        # The path to the SVGO config file.
        [string]$ConfigFile = (Join-Path $RepositoryRoot 'docs/generated/svgo-config.mjs'),
        # Force use of Node.js, even if a local installation is available.
        # If both -UseNode and -UseDocker are specified, Node.js will be used.
        [switch]$UseNode,
        # Force use of Docker, even if a local installation is available.
        # If both -UseNode and -UseDocker are specified, Node.js will be used.
        [switch]$UseDocker
    )

    if (!($ImagePath = Convert-Path -LiteralPath $ImagePath)) { return }

    $svgoCommand = $null
    $svgoArgs = @(
        '-i', $ImagePath
        '--config', $ConfigFile
    )

    if (!$UseDocker -and !$UseNode) {
        $svgoCommand = Assert-AppExists 'svgo' -PassThru -ErrorAction Ignore
        if (!$svgoCommand) {
            # don't override the user's choice if they explicitly specified -UseDocker:$false
            $UseDocker = (Test-DockerExists) -and !$PSBoundParameters.ContainsKey('UseDocker')
            $UseNode = (Test-NpmExists) -and !$PSBoundParameters.ContainsKey('UseNode')
            if (!$UseDocker -and !$UseNode) {
                Write-Warning 'Skipping SVG optimization: SVGO not found locally and Docker and Node.js are not available. Install SVGO from https://github.com/svg/svgo or ensure Docker or Node.js is available.'
                return
            }
        }
    }

    $nodeArgs = @(
        'npx'
        '--yes' # skip prompts
        'svgo@4.0.1'
    )

    # Prefer Node if both are available, since it it is faster than downloading the Docker image
    if ($UseNode) {
        $env:NPM_CONFIG_UPDATE_NOTIFIER = 'false' # disable update notifier
        $svgoCommand = $nodeArgs
    }
    elseif ($UseDocker) {
        # No official image, so just use Node and run svgo via npx.
        # map file to a Docker volume...
        $svgoCommand = @(
            'docker'
            'run'
            '--rm'
            '--volume', "$(Split-Path $ImagePath -Parent):/work/src"
            '--volume', "$(Split-Path $ImagePath -Parent):/work/cfg"
            if ($IsLinux -or $IsMacOS) { '--user', "$(id -u):$(id -g)" }
            '-e', 'NPM_CONFIG_UPDATE_NOTIFIER=false' # disable update notifier
            'node:24-slim'
            $nodeArgs
        )
        $svgoArgs = $svgoArgs.foreach{
            $_ -ceq $ImagePath ? "/work/src/$(Split-Path $ImagePath -Leaf)" :
            $_ -ceq $ConfigFile ? "/work/cfg/$(Split-Path $ConfigFile -Leaf)" :
            $_
        }
    }

    if ($svgoCommand -is [string]) {
        $svgoCommand = @($svgoCommand)
    }

    Write-Information 'Optimizing image with SVGO...'
    Invoke-Shell -infa $InformationPreference -- @svgoCommand @svgoArgs
}
