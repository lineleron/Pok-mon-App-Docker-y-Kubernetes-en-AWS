# Pokémon App: Docker y Kubernetes en AWS

Aplicación de ejemplo para **buscar Pokémon, guardarlos en una base de datos y compartir la lista por correo electrónico**. El proyecto reúne un frontend Angular, dos API y MongoDB, cada uno ejecutado en su propio contenedor.

El objetivo es comprender cómo se comunican estos componentes y cómo desplegar la misma aplicación con Docker, en Kubernetes local con Minikube y en Amazon EKS.

## Contenido

- [Qué hace la aplicación](#qué-hace-la-aplicación)
- [Arquitectura y funcionamiento](#arquitectura-y-funcionamiento)
- [Tecnologías utilizadas](#tecnologías-utilizadas)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Conceptos de Kubernetes](#conceptos-de-kubernetes)
- [Puertos y réplicas](#puertos-y-réplicas)
- [Configuración](#configuración)
- [Ejecución local con Docker](#ejecución-local-con-docker)
- [Publicar las imágenes en Amazon ECR](#publicar-las-imágenes-en-amazon-ecr)
- [Kubernetes local con Minikube](#kubernetes-local-con-minikube)
- [Kubernetes en AWS con Amazon EKS](#kubernetes-en-aws-con-amazon-eks)
- [Endpoints de las API](#endpoints-de-las-api)
- [Comprobaciones y problemas frecuentes](#comprobaciones-y-problemas-frecuentes)
- [Detener y eliminar recursos](#detener-y-eliminar-recursos)
- [Alcance y mejoras pendientes](#alcance-y-mejoras-pendientes)

## Qué hace la aplicación

Desde la interfaz web puedes:

1. Buscar un Pokémon por su nombre, por ejemplo, `pikachu`.
2. Consultar su imagen, tipo, peso y altura con datos de PokéAPI.
3. Guardarlo en MongoDB mediante la API Node.js.
4. Consultar y eliminar Pokémon de la lista guardada.
5. Solicitar la verificación de una dirección de correo mediante Amazon SES.
6. Enviar por correo la lista que se ha cargado en la pantalla.

Para probar el flujo completo: busca un Pokémon, pulsa **Guardar Pokemon**, carga la lista con **Ver Pokemones** y después utiliza **Compartir por Email**. Tras guardar o eliminar un registro, vuelve a cargar la lista: el código actual no la actualiza automáticamente.

## Arquitectura y funcionamiento

### Visión general del proyecto

![Visión general: Angular consulta PokéAPI y se comunica con las API Node.js y .NET, que acceden a MongoDB y Amazon SES](docs/images/vision-general.jpg)

La imagen muestra los componentes de la aplicación y los registros desde los que se descargan las imágenes Docker. Las llamadas a PokéAPI y a las API propias se realizan desde Angular en el navegador.

### Flujo de comunicación

```mermaid
flowchart LR
    Usuario[Usuario] --> Navegador[Navegador]
    subgraph Cluster[Cluster Kubernetes]
        Web[WebApp Angular / Nginx]
        Node[API Node.js]
        Net[API .NET]
        Mongo[(MongoDB)]
        Node -->|Lectura y escritura| Mongo
    end
    Web -->|Entrega HTML, CSS y JavaScript| Navegador
    Navegador -->|Consulta Pokémon| Poke[PokéAPI]
    Navegador -->|Guardar, listar y eliminar| Node
    Navegador -->|Verificar correo y compartir lista| Net
    Net -->|Verificación y envío de correo| SES[Amazon SES]
```

### Responsabilidad de cada componente

| Componente | Qué hace |
| --- | --- |
| **WebApp** | Presenta la interfaz. Angular se ejecuta en el navegador y Nginx sirve los archivos de la aplicación cuando se usa Docker. |
| **PokéAPI** | Servicio externo del que se obtienen los datos de los Pokémon. |
| **API Node.js** | Recibe las peticiones para guardar, listar y eliminar Pokémon. Utiliza Mongoose para acceder a MongoDB. |
| **MongoDB** | Almacena los Pokémon en la base de datos `blockstellart`, colección `pokemones`. |
| **API .NET** | Recibe las solicitudes de verificación y envío de correos y se comunica con Amazon SES. |
| **Amazon SES** | Servicio de AWS que envía los mensajes y los correos de verificación. |
| **Amazon ECR** | Registro privado que almacena las imágenes Docker de la WebApp y las dos API para su descarga durante el despliegue. |
| **Amazon EKS** | Servicio utilizado para ejecutar el cluster Kubernetes en AWS. |

La imagen de MongoDB se descarga de Docker Hub. Las otras tres imágenes se construyen a partir del código de `src/` y se pueden publicar en Amazon ECR.

### Cómo viajan los datos

- **Buscar:** el navegador consulta directamente PokéAPI y muestra el resultado.
- **Guardar:** el navegador envía los datos a la API Node.js, que los almacena en MongoDB.
- **Listar o eliminar:** el navegador llama a la API Node.js, que consulta o modifica MongoDB.
- **Compartir:** el navegador envía la lista cargada a la API .NET. Esta API la entrega a Amazon SES para enviarla por correo.

La API .NET recibe el contenido del mensaje desde el frontend; no consulta MongoDB. Amazon ECR participa en la distribución de imágenes, no en las peticiones habituales del usuario.

## Tecnologías utilizadas

Las versiones siguientes corresponden a lo declarado en los archivos del proyecto.

| Tecnología | Uso en este proyecto |
| --- | --- |
| Angular 18 y Bootstrap 5 | Interfaz web. |
| Node.js, Express 4 y Mongoose 8 | API de acceso a los Pokémon guardados. El Dockerfile de esta API usa Node.js 18. |
| ASP.NET Core / .NET 8 y AWS SDK para .NET | API de correo electrónico. |
| MongoDB | Base de datos documental. Se utiliza la imagen `mongo:latest`. |
| Docker y Nginx | Empaquetado de servicios y publicación del frontend. El frontend se compila con Node.js 22 en su Dockerfile. |
| Kubernetes y Minikube | Orquestación de contenedores y entorno de pruebas local. |
| Amazon ECR, EKS y SES | Registro de imágenes, cluster y servicio de correo en AWS. |
| AWS CLI y eksctl | Herramientas para preparar los recursos de AWS. |

## Estructura del proyecto

```text
.
├── README.md
├── docs/images/                     # Imágenes y diagramas utilizados en este README
├── 1-deploy-local-docker.sh          # Construye imágenes y ejecuta los contenedores
├── 2-create-push-images.sh           # Crea repositorios ECR y publica imágenes locales
├── k8s/
│   ├── MongoDB/                     # Deployment y Service de MongoDB
│   ├── APINode/                     # Deployment y Service de la API Node.js
│   ├── APINet/                      # Deployment y Service de la API .NET
│   └── WebApp/                      # Deployment y Service del frontend
└── src/
    ├── APINode/
    │   ├── controllers/             # Operaciones sobre los Pokémon
    │   ├── database/                # Conexión a MongoDB
    │   ├── models/                  # Modelo de datos
    │   ├── routes/                  # Rutas HTTP
    │   ├── index.js                 # Inicio de Express
    │   └── Dockerfile
    ├── APINet/API.AmazonSES/
    │   ├── API.AmazonSES/            # Proyecto .NET: controlador, modelos y servicio SES
    │   └── Dockerfile
    └── WebApp/
        ├── src/app/                 # Interfaz y llamadas a las API
        ├── src/assets/config.json   # Direcciones de las API que lee el navegador
        ├── nginx.conf
        ├── start.sh                 # Genera config.json al arrancar el contenedor
        └── Dockerfile
```

## Conceptos de Kubernetes

- **Cluster:** conjunto de máquinas donde Kubernetes ejecuta la aplicación.
- **Nodo:** una de esas máquinas. Puede alojar varios Pods.
- **Pod:** unidad donde se ejecutan los contenedores. Cada Pod de este proyecto contiene un contenedor de uno de los componentes.
- **Deployment:** indica qué imagen ejecutar y cuántas copias mantener. Kubernetes intenta recuperar el número deseado de réplicas si un Pod falla.
- **Service:** proporciona una dirección estable para acceder a los Pods seleccionados mediante etiquetas como `app: apinode`.
- **LoadBalancer:** tipo de Service utilizado para publicar la WebApp y las API fuera del cluster, según la integración del entorno.
- **ClusterIP:** tipo de Service que permite acceder a MongoDB desde dentro del cluster.
- **Secret de registro:** almacena la autenticación necesaria para descargar las imágenes privadas. Los manifiestos hacen referencia a `ecr-secret`.

Las réplicas son copias de un componente. Tener dos réplicas de cada API permite repartir peticiones, pero no garantiza por sí solo disponibilidad ante la caída de un nodo. Los manifiestos no obligan a colocar esas réplicas en nodos diferentes.

![Arquitectura de Kubernetes: WebApp, API Node.js, API .NET y MongoDB dentro del cluster; navegador, PokéAPI y Amazon SES fuera](docs/images/arquitectura-kubernetes.svg)

Este diagrama representa la arquitectura lógica y las réplicas configuradas. Los componentes pueden ejecutarse en distintos nodos del cluster.

## Puertos y réplicas

Estos valores reflejan los manifiestos de `k8s/` y el script de Docker local:

| Componente | Réplicas en Kubernetes | Puerto del contenedor | Service Kubernetes | Puerto del Service | Puerto publicado con Docker local |
| --- | --- | --- | --- | --- | --- |
| WebApp | 1 | 80 | `webapp`, LoadBalancer | 85 → 80 | 85 → 80 |
| API Node.js | 2 | 3000 | `apinode`, LoadBalancer | 90 → 3000 | 3000 → 3000 |
| API .NET | 2 | 8080 | `apinet`, LoadBalancer | 8080 → 8080 | 8080 → 8080 |
| MongoDB | 1 | 27017 | `mongodb`, ClusterIP | 27017 → 27017 | 27017 → 27017 |

Por ejemplo, en Kubernetes el navegador llama al puerto **90** de la API Node.js, y el Service dirige esa petición al puerto **3000** del contenedor.

El Dockerfile de .NET también declara `8081`, pero los manifiestos actuales solo publican `8080` y la aplicación no tiene HTTPS configurado.

![Puertos de los Services: WebApp 85 a 80, Node.js 90 a 3000, MongoDB 27017 a 27017 y .NET 8080 a 8080](docs/images/puertos-servicios.svg)

Las flechas indican cómo llegan las peticiones a los contenedores. El Service de MongoDB solo permite el acceso interno del cluster.

## Configuración

Ejecuta los comandos de esta guía desde la **carpeta raíz del proyecto**, salvo que se indique otra ruta. Los ejemplos usan Bash y el namespace `default` de Kubernetes.

### Variables de entorno

| Componente | Variable | Significado |
| --- | --- | --- |
| MongoDB | `MONGO_INITDB_ROOT_USERNAME` | Usuario administrador inicial. |
| MongoDB | `MONGO_INITDB_ROOT_PASSWORD` | Contraseña inicial. |
| MongoDB | `MONGO_INITDB_DATABASE` | Nombre de base de datos usado para la inicialización. |
| API Node.js | `PORT` | Puerto de escucha. Los despliegues usan `3000`; sin esta variable el código usa `3001`. |
| API Node.js | `MONGO_URI` | Cadena de conexión a MongoDB. |
| API .NET | `AWS_ACCESS_KEY_ID` | Identificador de credencial AWS para el SDK. |
| API .NET | `AWS_SECRET_ACCESS_KEY` | Clave secreta de AWS. |
| API .NET | `AWS_REGION` | Región de SES; los ejemplos utilizan `us-east-1`. |
| API .NET | `EMAILVERIFICADO` | Remitente verificado utilizado para enviar los correos. |
| WebApp | `API_NODE` | URL base de la API Node.js, terminada en `/api/`. |
| WebApp | `API_NET` | URL base de la API .NET, terminada en `/api/`. |

Ejemplo de conexión utilizado en la práctica:

```text
mongodb://admin:adminpassword@mongodb:27017/blockstellart?authSource=admin
```

`mongodb` es el nombre del contenedor en la red Docker o del Service en Kubernetes. Si ejecutas Node.js directamente en tu equipo, utiliza `localhost` y el puerto publicado de MongoDB.

### Direcciones del frontend

Al arrancar el contenedor web, `start.sh` convierte `API_NODE` y `API_NET` en las propiedades `apiNode` y `apiNet` de `/assets/config.json`. Después, `src/main.ts` carga ese archivo antes de iniciar Angular.

**Estas direcciones deben ser accesibles desde el navegador del usuario.** Por eso se usa `localhost` en Docker local y una dirección pública de balanceador en AWS. Los nombres internos del cluster, como `apinode`, sirven para la comunicación entre Pods, pero normalmente no se resuelven desde el navegador de tu equipo.

Si utilizas `npm start` para desarrollar el frontend, configura `src/WebApp/src/assets/config.json` directamente. Las variables `API_NODE` y `API_NET` se procesan mediante el arranque del contenedor.

### Preparar Amazon SES

Para probar el correo necesitas una identidad remitente verificada en la misma región utilizada por la API, credenciales con permisos para `ses:SendEmail` y `ses:VerifyEmailIdentity`, y acceso de red a AWS.

Si la cuenta está en el **sandbox de SES**, también debes verificar al destinatario. El botón **Validar** solicita el correo de verificación; el usuario debe abrirlo y confirmar el enlace. El mensaje de la aplicación solo indica que se ha enviado la solicitud de verificación. Consulta las [restricciones oficiales del sandbox de SES](https://docs.aws.amazon.com/ses/latest/dg/request-production-access.html).

El envío de correo depende de AWS incluso cuando ejecutas Docker o Minikube en local.

### Credenciales del manifiesto .NET

El archivo `k8s/APINet/deployment-api-net.yaml` contiene valores de credenciales AWS escritos directamente. **Si son válidos, revócalos o rótalos antes de compartir o reutilizar el proyecto.** Sustituye esos valores por tu configuración y utiliza referencias `secretKeyRef` a un Secret de Kubernetes para evitar incluir claves en el YAML versionado. En EKS también puedes adaptar el despliegue para utilizar una identidad IAM asociada a la aplicación.

Los valores `admin` y `adminpassword` de MongoDB son de demostración. Si los cambias, actualiza también `MONGO_URI`. No guardes credenciales reales en el README ni en archivos publicados.

## Ejecución local con Docker

### Requisitos

- Docker instalado y en ejecución.
- Bash para ejecutar los scripts `.sh`.
- Acceso a Internet para descargar imágenes, dependencias y consultar PokéAPI.
- Configuración de SES si quieres probar los correos.

### Despliegue

```bash
bash 1-deploy-local-docker.sh
```

El script:

1. Construye `blockstellart.net`, `blockstellart.node` y `blockstellart.webapp`.
2. Elimina los contenedores previos que tengan los nombres de esta práctica.
3. Crea la red `blockstellart-network`.
4. Inicia MongoDB con el volumen Docker `mongo-data`.
5. Solicita las credenciales AWS, la región y el correo remitente para iniciar la API .NET.
6. Inicia la API Node.js y la WebApp, y conecta los cuatro contenedores a la red.

La eliminación de contenedores previos no borra el volumen `mongo-data`. Evita ejecutar este script si necesitas conservar contenedores existentes con esos mismos nombres.

### Acceso

| Recurso | Dirección local |
| --- | --- |
| Aplicación web | `http://localhost:85` |
| API Node.js | `http://localhost:3000/api/pokemon` |
| Salud de Node.js | `http://localhost:3000/healthcheck` |
| Salud de .NET | `http://localhost:8080/health` |

```bash
docker ps
curl http://localhost:3000/healthcheck
curl http://localhost:8080/health
```

Para buscar, guardar y listar Pokémon utiliza la aplicación web. La configuración de SES es necesaria para las funciones de correo.

## Publicar las imágenes en Amazon ECR

Este paso prepara las imágenes privadas utilizadas por los manifiestos de Kubernetes.

Configura AWS CLI con una identidad que pueda crear o consultar repositorios, autenticarse en ECR y publicar imágenes:

```bash
aws configure
aws sts get-caller-identity
```

Si solo quieres construir las imágenes, sin ejecutar el despliegue Docker local:

```bash
docker build -t blockstellart.net ./src/APINet/API.AmazonSES
docker build -t blockstellart.node ./src/APINode
docker build -t blockstellart.webapp ./src/WebApp
```

Después ejecuta:

```bash
bash 2-create-push-images.sh
```

El script solicita el ID de cuenta AWS y crea o recupera estos repositorios:

| Imagen local | Repositorio ECR |
| --- | --- |
| `blockstellart.webapp:latest` | `blockstellart/webapp` |
| `blockstellart.node:latest` | `blockstellart/service-node` |
| `blockstellart.net:latest` | `blockstellart/service-net` |

El script usa `us-east-1` y el perfil `default`. Si cambias de perfil, ajusta también la autenticación: las consultas de repositorios reciben `--profile`, pero el comando de login del script no lo incluye. Comprueba que cada imagen termine de publicarse correctamente; el script puede omitir imágenes locales que no existan.

### Actualizar las imágenes de los manifiestos

Edita `image:` en los tres Deployments de las aplicaciones. Algunos archivos ya contienen un ID de cuenta y otro conserva `<ACCOUNT_ID>`: reemplázalos todos por el de tu cuenta.

```text
<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/blockstellart/webapp:latest
<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/blockstellart/service-node:latest
<ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/blockstellart/service-net:latest
```

MongoDB sigue utilizando `mongo:latest` de Docker Hub.

### Crear el Secret de descarga en el cluster elegido

Ejecuta este paso **después de seleccionar el contexto de Minikube o EKS**. El Secret solo existe en el cluster y namespace donde lo creas.

```bash
export AWS_ACCOUNT_ID="TU_ID_DE_CUENTA"
export AWS_REGION="us-east-1"

kubectl create secret docker-registry ecr-secret \
  --docker-server="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com" \
  --docker-username=AWS \
  --docker-password="$(aws ecr get-login-password --region "$AWS_REGION")" \
  --namespace default \
  --dry-run=client -o yaml | kubectl apply -f -
```

El token de ECR dura **12 horas**. Repite el comando para actualizar el Secret cuando sea necesario descargar imágenes con un token nuevo. Este Secret autentica la descarga de imágenes; las credenciales que usa la API .NET para SES se configuran por separado. Consulta la [autenticación oficial de ECR](https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry_auth.html).

## Kubernetes local con Minikube

### 1. Preparar el cluster

Necesitas Docker, `kubectl` y Minikube instalados.

```bash
minikube start
kubectl config use-context minikube
kubectl get nodes
```

Completa la publicación en ECR, actualiza `image:` en los Deployments y crea `ecr-secret` en este contexto. Configura también la API .NET y SES si quieres probar los correos.

### 2. Configurar las URL de las API

El Deployment web incluye estos valores para el entorno local:

```yaml
- name: API_NODE
  value: "http://127.0.0.1:90/api/"
- name: API_NET
  value: "http://127.0.0.1:8080/api/"
```

Son válidos si esos puertos están accesibles en el loopback de tu equipo. La dirección que obtiene un LoadBalancer de Minikube puede variar según el sistema y el driver; compruébala en el siguiente paso.

### 3. Aplicar los manifiestos

```bash
kubectl apply -f k8s/MongoDB/
kubectl rollout status deployment/mongodb

kubectl apply -f k8s/APINode/
kubectl apply -f k8s/APINet/
kubectl rollout status deployment/apinode
kubectl rollout status deployment/apinet

kubectl apply -f k8s/WebApp/
kubectl rollout status deployment/webapp
```

### 4. Acceder a los servicios

En otra terminal, deja ejecutándose:

```bash
minikube tunnel
```

Consulta las direcciones asignadas:

```bash
kubectl get services
```

Usa la dirección de `webapp` con el puerto `85`. Si las direcciones de `apinode` y `apinet` difieren de `127.0.0.1`, actualiza las variables del Deployment web con sus direcciones y puertos correspondientes. Después aplica el cambio:

```bash
kubectl apply -f k8s/WebApp/deployment-webapp.yaml
kubectl rollout status deployment/webapp
```

Como alternativa para probar desde tu propio equipo, abre tres terminales y mantén un comando en cada una:

```bash
kubectl port-forward service/webapp 85:85
```

```bash
kubectl port-forward service/apinode 90:90
```

```bash
kubectl port-forward service/apinet 8080:8080
```

Con estos reenvíos puedes utilizar las URL `127.0.0.1` del manifiesto y abrir `http://127.0.0.1:85`. Si el sistema impide usar puertos bajos, elige puertos locales altos y ajusta las URL del frontend.

## Kubernetes en AWS con Amazon EKS

Necesitas AWS CLI configurada, `kubectl`, `eksctl`, las imágenes publicadas en ECR y permisos para crear la infraestructura. Crear el cluster, los nodos y los balanceadores genera costes en AWS.

### 1. Crear el cluster y los nodos

```bash
eksctl create cluster \
  --name blockstellart-cluster \
  --region us-east-1 \
  --without-nodegroup

eksctl create nodegroup \
  --cluster blockstellart-cluster \
  --region us-east-1 \
  --name autoscaling-nodegroup \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 5
```

Los límites del grupo permiten ajustar su capacidad; estos comandos no instalan un mecanismo que escale automáticamente los nodos según la carga. Consulta la [guía de creación de clusters con eksctl](https://docs.aws.amazon.com/eks/latest/eksctl/creating-and-managing-clusters.html).

### 2. Seleccionar el contexto y preparar el acceso

```bash
aws eks update-kubeconfig --region us-east-1 --name blockstellart-cluster
kubectl config current-context
kubectl get nodes
```

Crea `ecr-secret` en este cluster siguiendo la sección de ECR. Revisa las imágenes, las credenciales y el remitente de SES en los manifiestos.

Para el acceso público también debes disponer de una integración de balanceadores configurada en el cluster, con los permisos y subredes necesarios. Si utilizas **AWS Load Balancer Controller**, instálalo y configura los Services para ese controlador y para exposición pública antes de aplicarlos. Los YAML incluidos solo declaran `type: LoadBalancer`; no instalan el controlador ni especifican el esquema público. Sigue la [guía oficial de balanceadores en EKS](https://docs.aws.amazon.com/eks/latest/userguide/network-load-balancing.html) para completar esta parte según tu cluster.

### 3. Desplegar MongoDB y las API

```bash
kubectl apply -f k8s/MongoDB/
kubectl rollout status deployment/mongodb
kubectl apply -f k8s/APINode/
kubectl apply -f k8s/APINet/
kubectl rollout status deployment/apinode
kubectl rollout status deployment/apinet
kubectl get services
```

Espera a que `apinode` y `apinet` tengan una dirección externa. En AWS, la columna `EXTERNAL-IP` puede mostrar un nombre DNS de balanceador.

### 4. Configurar y desplegar la WebApp

En `k8s/WebApp/deployment-webapp.yaml`, utiliza las direcciones reales de los balanceadores de las API:

```yaml
- name: API_NODE
  value: "http://<DNS_BALANCEADOR_NODE>:90/api/"
- name: API_NET
  value: "http://<DNS_BALANCEADOR_NET>:8080/api/"
```

Conserva `/api/` al final y sustituye los marcadores por las direcciones obtenidas, sin añadir otro `http://` dentro del nombre DNS.

```bash
kubectl apply -f k8s/WebApp/
kubectl rollout status deployment/webapp
kubectl get service webapp
```

Accede desde el navegador a `http://<DNS_BALANCEADOR_WEB>:85`. En AWS, `localhost` apunta al equipo de quien abre el navegador: por eso debes cambiar las URL locales del frontend.

## Endpoints de las API

Las rutas siguientes son relativas a la dirección base de cada API.

### API Node.js

| Método | Ruta | Función |
| --- | --- | --- |
| GET | `/healthcheck` | Comprueba que el servidor HTTP responde. |
| GET | `/api/pokemon` | Devuelve los Pokémon guardados. |
| POST | `/api/pokemon` | Guarda un Pokémon. |
| DELETE | `/api/pokemon/:id` | Elimina el registro identificado por su `_id` de MongoDB. |

Ejemplo de cuerpo JSON para guardar un Pokémon:

```json
{
  "name": "pikachu",
  "weight": 60,
  "height": 4,
  "spriteUrl": "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/25.png",
  "type": "electric"
}
```

El modelo exige `name`. El peso se muestra en hectogramos y la altura en decímetros.

### API .NET

| Método | Ruta | Función |
| --- | --- | --- |
| GET | `/health` | Comprueba que la aplicación HTTP responde. |
| POST | `/api/email/verificar-email` | Solicita a SES la verificación de un correo. |
| POST | `/api/email/enviar-email` | Envía un correo mediante SES. |

Cuerpo JSON para solicitar una verificación:

```json
{
  "verificarEmail": "destinatario@example.com"
}
```

Cuerpo JSON para enviar un mensaje:

```json
{
  "toEmail": "destinatario@example.com",
  "subject": "Mi lista de Pokémon",
  "body": "Mi lista de pokemon: [...]"
}
```

Estos ejemplos describen las peticiones; para enviarlas necesitas las direcciones de correo y la configuración de SES de tu entorno.

## Comprobaciones y problemas frecuentes

### Estado de los recursos

```bash
kubectl get deployments
kubectl get pods -o wide
kubectl get services
kubectl describe pod NOMBRE_DEL_POD
kubectl logs deployment/apinode
kubectl logs deployment/apinet
kubectl logs deployment/webapp
```

Sustituye `NOMBRE_DEL_POD` por uno de los nombres obtenidos con `kubectl get pods`.

Con las réplicas actuales, el despliegue estable de la aplicación tiene **6 Pods**: uno web, dos de Node.js, dos de .NET y uno de MongoDB. El cluster también puede tener Pods del sistema, y durante una actualización pueden aparecer Pods adicionales.

### Comprobar las API en Kubernetes local

Si tienes las direcciones locales configuradas o los reenvíos de puertos activos:

```bash
curl http://127.0.0.1:90/healthcheck
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:90/api/pokemon
```

Node.js responde a su comprobación con `{"ok":true,"message":"API funcionando correctamente 🚀"}` y .NET devuelve `Healthy`.

**Estas rutas de salud no verifican MongoDB ni SES.** Para comprobar MongoDB, lista y guarda Pokémon; para comprobar SES, realiza una verificación o un envío con direcciones autorizadas. Los manifiestos tampoco configuran estas rutas como probes de Kubernetes.

### Diagnóstico rápido

| Problema | Qué revisar |
| --- | --- |
| `ImagePullBackOff` o `ErrImagePull` | ID de cuenta, región, repositorio, etiqueta, permisos y existencia o renovación de `ecr-secret` en el namespace correcto. |
| `EXTERNAL-IP` permanece en `<pending>` | En Minikube, mantén abierto `minikube tunnel` o usa `port-forward`. En EKS, revisa eventos del Service, controlador, permisos, subredes y configuración de exposición. |
| El frontend abre, pero no conecta con las API | Revisa `/assets/config.json` desde el navegador, los puertos y la conectividad a ambas API. Conserva `/api/` al final de las URL base. |
| La búsqueda funciona, pero no se guardan Pokémon | PokéAPI y MongoDB siguen caminos diferentes. Revisa la API Node.js, `MONGO_URI`, las credenciales y los logs de MongoDB. |
| No se envían correos | Comprueba región, credenciales, permisos SES, remitente verificado y destinatario verificado si la cuenta está en sandbox. |
| La lista no refleja un cambio | Pulsa **Ver Pokemones** para volver a consultar MongoDB. |
| Error de arquitectura de imagen | Comprueba que la plataforma de las imágenes construidas coincida con la de los nodos, especialmente al construir en equipos ARM y desplegar en nodos x86. |

## Detener y eliminar recursos

Comprueba el contexto antes de eliminar recursos Kubernetes:

```bash
kubectl config current-context
```

### Docker local

Para detener los contenedores conservándolos y manteniendo el volumen:

```bash
docker stop blockstellart.webpokemon blockstellart.apinode blockstellart.apinet mongodb
```

### Kubernetes

Para eliminar los Deployments y Services de esta aplicación en el contexto seleccionado, utiliza la opción recursiva porque los archivos están en subcarpetas:

```bash
kubectl delete -R -f k8s/
```

**La eliminación del Pod de MongoDB en Kubernetes borra sus datos actuales**, porque utiliza `emptyDir`. El Secret `ecr-secret` se administra por separado.

### Minikube

Para detener el entorno local:

```bash
minikube stop
```

Para eliminar completamente el cluster local:

```bash
minikube delete
```

### AWS

Elimina primero los Services de la aplicación y comprueba en AWS que sus balanceadores se hayan retirado. Después elimina el cluster y espera el resultado:

```bash
eksctl delete cluster --name blockstellart-cluster --region us-east-1 --wait
```

Los repositorios e imágenes de ECR se gestionan por separado y no se eliminan con este comando. Revisa los recursos restantes en AWS para evitar costes después de la práctica.

## Alcance y mejoras pendientes

Este proyecto sirve como práctica de contenedores, comunicación entre servicios y despliegue en Kubernetes. Su configuración actual tiene estas limitaciones:

- **Persistencia:** Docker local utiliza el volumen `mongo-data`, pero Kubernetes monta `emptyDir` en `/data/db`. Este volumen sobrevive a reinicios del contenedor dentro del mismo Pod y se pierde al eliminar o reemplazar el Pod. Para conservar datos entre Pods se necesita almacenamiento persistente, por ejemplo, un PVC. Consulta el [comportamiento oficial de emptyDir](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir).
- **Acceso a las API:** no hay autenticación de usuarios y la configuración CORS permite cualquier origen. Antes de una publicación real hay que controlar quién puede operar y enviar correos.
- **Transporte:** los manifiestos publican HTTP. HTTPS, certificados e Ingress requieren configuración adicional.
- **Operación:** faltan requests y limits de CPU/memoria, probes de disponibilidad y vida, y políticas para distribuir las réplicas entre nodos.
- **Versionado:** se utilizan etiquetas `latest`; fijar versiones de imágenes permite repetir y controlar los despliegues.
- **Configuración sensible:** las credenciales incluidas en los manifiestos deben sustituirse y gestionarse fuera del código publicado.

La base permite aprender el flujo completo: **construir imágenes → publicarlas en ECR → desplegar los componentes → comprobar su comunicación**.
