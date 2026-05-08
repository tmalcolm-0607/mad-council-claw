# MAD.Council sandbox — pwsh 7 + Pester + PSScriptAnalyzer + ajv
# See MAD/operations/sandbox-testing.md for design.
#
# Build:  docker build -t mad-sandbox:latest -f MAD/docker/Dockerfile .
# Run:    pwsh MAD/docker/run-sandbox.ps1
# Clean:  docker image rm mad-sandbox:latest
#
# The MAD/ tree is bind-mounted at runtime (read-only) at /mad.
# Reports land on a host-rw bind-mount at /mad-report.

FROM mcr.microsoft.com/powershell:lts-ubuntu-22.04

# PowerShell modules + Node/ajv for JSON-schema validation
RUN pwsh -NoProfile -Command \
    "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted; \
     Install-Module -Name Pester -MinimumVersion 5.5 -Force -Scope AllUsers -SkipPublisherCheck; \
     Install-Module -Name PSScriptAnalyzer -MinimumVersion 1.22 -Force -Scope AllUsers" \
 && apt-get update \
 && apt-get install -y --no-install-recommends nodejs npm ca-certificates \
 && npm install -g ajv-cli@5 ajv-formats@3 \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /root/.npm

WORKDIR /mad

# Entrypoint runs the smoke suite.
# Overridable for development: docker run ... mad-sandbox:latest pwsh ...
ENTRYPOINT ["pwsh", "-NoProfile", "-File", "/mad/scripts/run-sandbox-tests.ps1"]
CMD ["-ReportPath", "/mad-report/smoke.json", "-MadRoot", "/mad"]
