#!/bin/bash

########################################
# Script para compilar y desplegar servicios Docker
# utilizando MongoDB, API .NET, API Node y una WebApp.
########################################

set -e  # Terminar el script en caso de error

########################################
# 1. COMPILAR IMÁGENES DOCKER
########################################

echo "=== Compilando imágenes Docker... ==="

# API .NET
echo "== Compilando imagen para la API .NET... =="
cd src/APINet/API.AmazonSES || { echo "ERROR: No se encontró la carpeta de la API .NET"; exit 1; }
docker build -t blockstellart.net .
cd ../../..  # Volver a la raíz del repositorio

# API Node
echo "== Compilando imagen para la API Node... =="
cd src/APINode || { echo "ERROR: No se encontró la carpeta de la API Node"; exit 1; }
docker build -t blockstellart.node .
cd ../..  # Volver a la raíz del repositorio

# WebApp
echo "== Compilando imagen para la WebApp... =="
cd src/WebApp || { echo "ERROR: No se encontró la carpeta de la WebApp"; exit 1; }
docker build -t blockstellart.webapp .
cd ../..  # Volver a la raíz del repositorio

echo "=== Imágenes compiladas con éxito ==="
echo

########################################
# 2. LIMPIAR CONTENEDORES PREVIOS
########################################

echo "=== Eliminando contenedores anteriores si existen... ==="
docker rm -f mongodb blockstellart.apinet blockstellart.apinode blockstellart.webpokemon || true
echo

########################################
# 3. CREAR RED DOCKER
########################################

echo "=== Creando red Docker: blockstellart-network ==="
docker network create blockstellart-network || true
echo "Red creada exitosamente."
echo

########################################
# 4. DESPLEGAR CONTENEDOR DE MONGODB
########################################

echo "=== Iniciando contenedor de MongoDB... ==="
docker run --name mongodb \
  -dp 27017:27017 \
  -e MONGO_INITDB_ROOT_USERNAME=admin \
  -e MONGO_INITDB_ROOT_PASSWORD=adminpassword \
  -e MONGO_INITDB_DATABASE=blockstellart \
  -v mongo-data:/data/db \
  mongo:latest

docker network connect blockstellart-network mongodb
echo "MongoDB desplegado y conectado a la red."
echo

########################################
# 5. DESPLEGAR API .NET
########################################

echo "=== Configurando la API .NET... ==="
read -p "Ingrese AWS_ACCESS_KEY_ID: " AWS_ACCESS_KEY_ID
read -p "Ingrese AWS_SECRET_ACCESS_KEY: " AWS_SECRET_ACCESS_KEY
read -p "Ingrese AWS_REGION (ej. us-east-1): " AWS_REGION
read -p "Ingrese EMAIL (correo válido): " EMAILVERIFICADO

echo "=== Iniciando contenedor de la API .NET... ==="
docker run -dp 8080:8080 \
  --name blockstellart.apinet \
  -e AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
  -e AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
  -e AWS_REGION="${AWS_REGION}" \
  -e EMAILVERIFICADO="${EMAILVERIFICADO}" \
  blockstellart.net

docker network connect blockstellart-network blockstellart.apinet
echo "API .NET desplegada y conectada a la red."
echo

########################################
# 6. DESPLEGAR API NODE
########################################

echo "=== Iniciando contenedor de la API Node... ==="
docker run -dp 3000:3000 \
  --name blockstellart.apinode \
  -e PORT=3000 \
  -e MONGO_URI="mongodb://admin:adminpassword@mongodb:27017/blockstellart?authSource=admin" \
  blockstellart.node

docker network connect blockstellart-network blockstellart.apinode
echo "API Node desplegada y conectada a la red."
echo

########################################
# 7. DESPLEGAR WEBAPP
########################################

echo "=== Iniciando contenedor de la WebApp... ==="
docker run -dp 85:80 \
  --name blockstellart.webpokemon \
  -e API_NODE="http://localhost:3000/api/" \
  -e API_NET="http://localhost:8080/api/" \
  blockstellart.webapp

docker network connect blockstellart-network blockstellart.webpokemon
echo "WebApp desplegada y conectada a la red."
echo

########################################
# 8. VERIFICACIÓN
########################################

echo "=== Verificando contenedores desplegados... ==="
docker ps

echo "=== Despliegue completado exitosamente. ==="
echo
