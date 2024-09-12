FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build-env
WORKDIR /App

# Copy everything
COPY . ./
# Restore as distinct layers
RUN dotnet restore DotNet.Docker_rt.csproj
# Build and publish a release
RUN dotnet publish -c Release DotNet.Docker_rt.csproj -o out

# Build runtime image
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /App
#COPY appsettings.json .
COPY --from=build-env /App/out .

RUN addgroup --group rtgroup --gid 2000 

RUN adduser --disabled-password --home /App --gecos '' \    
    --uid 1000 \
    --gid 2000 \
    "rtuser" 

RUN usermod -a -G rtgroup rtuser

RUN chown -R rtuser:rtgroup  /App /tmp

USER rtuser:rtgroup

ENTRYPOINT ["dotnet", "DotNet.Docker_rt.dll"]