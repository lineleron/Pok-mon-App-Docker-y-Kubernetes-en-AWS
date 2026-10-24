FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080
EXPOSE 8081

# Esta etapa se utiliza para construir el proyecto de servicio
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["API.AmazonSES/API.AmazonSES.csproj", "API.AmazonSES/"]
RUN dotnet restore "./API.AmazonSES/API.AmazonSES.csproj"
COPY . .
WORKDIR "/src/API.AmazonSES"
RUN dotnet build "./API.AmazonSES.csproj" -c Release -o /app/build

# Esta etapa se utiliza para publicar el proyecto de servicio que se copiará a la etapa final
FROM build AS publish
RUN dotnet publish "./API.AmazonSES.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Esta etapa se utiliza en producción o cuando se ejecuta desde VS en modo normal (Por defecto cuando no se utiliza la configuración Debug)
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "API.AmazonSES.dll"]