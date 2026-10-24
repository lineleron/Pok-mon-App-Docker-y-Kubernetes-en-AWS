#!/bin/bash

# ------------------------------------------------------------------
# Script para subir imágenes Docker a repositorios privados de Amazon ECR
#  1) Crear repositorios privados en Amazon ECR (si no existen),
#  2) Obtener las URIs de los repositorios,
#  3) Hacer docker tag y docker push de las imágenes locales
#     hacia los repositorios correspondientes.
# ------------------------------------------------------------------

# Configuración
AWS_REGION="us-east-1"        # Región de AWS
AWS_PROFILE="default"         # Perfil de AWS CLI (deja 'default' si no usas múltiples perfiles)

# Solicita el ID de la cuenta de AWS (12 dígitos)
read -p "Ingrese ID de la cuenta de AWS: " AWS_ACCOUNT_ID

# Lista de repositorios que se crearán en ECR privado
REPOSITORIES=(
  "blockstellart/webapp"
  "blockstellart/service-node"
  "blockstellart/service-net"
)

# Lista de imágenes locales y sus respectivos repositorios en ECR
LOCAL_IMAGES=("blockstellart.webapp" "blockstellart.node" "blockstellart.net")
REMOTE_REPOS=("${REPOSITORIES[@]}")

# ------------------------------------------------------------------
# Paso 1: Crear o recuperar repositorios en Amazon ECR
# ------------------------------------------------------------------
echo "=== Creando o recuperando repositorios privados en Amazon ECR... ==="
declare -a REPO_URIS # Arreglo para almacenar las URIs completas de los repositorios

for i in "${!REPOSITORIES[@]}"; do
  REPO="${REPOSITORIES[$i]}"
  echo "Procesando repositorio: ${REPO}"

  # Intentar crear el repositorio
  REPOSITORY_URI=$(aws ecr create-repository \
    --repository-name "${REPO}" \
    --profile "${AWS_PROFILE}" \
    --region "${AWS_REGION}" \
    --query "repository.repositoryUri" \
    --output text 2>/dev/null)

  # Si no se pudo crear, intentar recuperarlo
  if [ -z "$REPOSITORY_URI" ]; then
    echo "El repositorio '${REPO}' ya existe o no pudo ser creado. Recuperando URI..."
    REPOSITORY_URI=$(aws ecr describe-repositories \
      --repository-names "${REPO}" \
      --profile "${AWS_PROFILE}" \
      --region "${AWS_REGION}" \
      --query "repositories[0].repositoryUri" \
      --output text)
  fi

  # Guardar la URI en el arreglo si se recuperó correctamente
  if [ -n "$REPOSITORY_URI" ]; then
    echo "Repositorio URI: ${REPOSITORY_URI}"
    REPO_URIS[$i]="$REPOSITORY_URI"
  else
    echo "Error: No se pudo crear o recuperar el repositorio '${REPO}'."
  fi
done

echo "=== Repositorios privados creados o recuperados exitosamente. ==="
echo

# ------------------------------------------------------------------
# Paso 2: Autenticarse en ECR
# ------------------------------------------------------------------
echo "=== Autenticándose en ECR privado... ==="
aws ecr get-login-password \
  --region "${AWS_REGION}" \
  | docker login \
    --username AWS \
    --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

if [ $? -ne 0 ]; then
  echo "ERROR: Falló la autenticación en ECR privado."
  exit 1
fi

echo "Autenticación exitosa en ECR privado."
echo

# ------------------------------------------------------------------
# Paso 3: Subir imágenes locales a ECR
# ------------------------------------------------------------------
echo "=== Iniciando docker push de las imágenes locales... ==="

# Iterar sobre las imágenes locales y sus repositorios correspondientes
for i in "${!LOCAL_IMAGES[@]}"; do
  LOCAL_IMAGE="${LOCAL_IMAGES[$i]}:latest"  # Etiqueta de la imagen local
  REPO_URI="${REPO_URIS[$i]}"              # URI completa del repositorio
  REMOTE_IMAGE="${REPO_URI}:latest"        # Etiqueta remota para la imagen en ECR

  echo "Procesando imagen local: ${LOCAL_IMAGE}"

  # Verificar si la imagen local existe
  docker image inspect "$LOCAL_IMAGE" >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "La imagen local '${LOCAL_IMAGE}' no existe. Omitiendo push."
    continue
  fi

  # Etiquetar la imagen local para el repositorio remoto
  echo "Etiquetando imagen: ${LOCAL_IMAGE} -> ${REMOTE_IMAGE}"
  docker tag "$LOCAL_IMAGE" "$REMOTE_IMAGE"

  # Subir la imagen al repositorio en ECR
  echo "Subiendo imagen a ECR: ${REMOTE_IMAGE}"
  docker push "$REMOTE_IMAGE"
  if [ $? -eq 0 ]; then
    echo "Push exitoso: ${REMOTE_IMAGE}"
  else
    echo "ERROR: Falló el push de ${REMOTE_IMAGE}"
  fi

  echo
done

echo "=== Proceso de push completado. ==="