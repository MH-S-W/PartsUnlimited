# Use an official .NET runtime as a parent image
FROM mcr.microsoft.com/dotnet/framework/sdk:4.8 AS build
WORKDIR /app

# Copy csproj and restore as distinct layers
COPY *.sln .
COPY src/PartsUnlimitedWebsite/*.csproj  ./PartsUnlimitedWebsite/
COPY src/PartsUnlimitedWebsite/*.config  ./PartsUnlimitedWebsite/
RUN nuget restore
RUN dotnet restore

# Copy everything else and build the app
COPY src/PartsUnlimitedWebsite/. ./PartsUnlimitedWebsite/
WORKDIR /app/PartsUnlimitedWebsite
RUN msbuild /p:Configuration=Release -r:False

FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8 AS runtime
WORKDIR /inetpub/wwwroot
COPY --from=build /app/PartsUnlimitedWebsite/. ./
