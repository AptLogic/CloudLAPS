# To enable ssh & remote debugging on app service change the base image to the one below
# FROM mcr.microsoft.com/azure-functions/powershell:4-powershell7.4-appservice
FROM mcr.microsoft.com/azure-functions/powershell:4-powershell7.4
ENV AzureWebJobsScriptRoot=/home/site/wwwroot \
    FUNCTIONS_WORKER_RUNTIME=powershell \
    FUNCTIONS_WORKER_RUNTIME_VERSION=7.4 \
    AzureFunctionsJobHost__Logging__Console__IsEnabled=true

COPY . /home/site/wwwroot