# ImageGeoRef para AutoCAD

Un script de AutoLISP para georreferenciar imágenes raster en AutoCAD utilizando archivos de georreferenciación (*World Files*).

## Descripción

Esta herramienta permite a los usuarios de AutoCAD seleccionar una imagen raster (como JPG, PNG, TIF) y aplicar automáticamente la posición, escala y rotación correctas basándose en un archivo *World* asociado (por ejemplo, `.jgw`, `.pgw`, `.tfw`).

## Características

- Georreferenciación automática de imágenes.
- Cálculo y aplicación de posición, escala y rotación. El script maneja rotaciones simples (ejes ortogonales).
- Compatible con AutoCAD 2012 y versiones posteriores.
- Soporta los formatos de imagen más comunes.
- Incluye un método alternativo (usando comandos nativos) para máxima compatibilidad con diferentes versiones de AutoCAD.
- Implementación robusta para leer las dimensiones de archivos PNG y JPEG directamente desde la cabecera del archivo, evitando inconsistencias de AutoCAD.

## Requisitos

- AutoCAD 2012 o una versión más reciente.
- En Windows, el componente `ADODB.Stream` debe estar disponible (generalmente incluido en el sistema operativo) para la lectura de dimensiones de archivos PNG y JPEG.

## Instalación y Uso

1.  **Cargar el script:**
    *   Abre AutoCAD.
    *   Usa el comando `APPLOAD`.
    *   Busca y selecciona el archivo `ImageGeoRef.lsp`.
    *   Haz clic en "Load". Verás un mensaje de confirmación en la línea de comandos: `[OK] ImageGeoRef.lsp cargado.`

2.  **Ejecutar el comando:**
    *   Asegúrate de que la imagen que quieres georreferenciar ya esté insertada en tu dibujo de AutoCAD.
    *   Asegúrate de que el archivo *World* (p. ej., `mi_imagen.jgw`) esté en la misma carpeta que tu archivo de imagen (`mi_imagen.jpg`).
    *   Escribe el comando `IMAGEGEOREF` en la línea de comandos y presiona Enter.
    *   Sigue las instrucciones: selecciona la imagen raster.

El script buscará automáticamente el archivo *World* correspondiente y aplicará la transformación.

## Formatos Soportados

| Extensión de Imagen | Extensión de Archivo World |
| ------------------- | -------------------------- |
| `.jpg`, `.jpeg`     | `.jgw`                     |
| `.png`              | `.pgw`                     |
| `.tif`, `.tiff`     | `.tfw`                     |
| `.bmp`              | `.bpw`                     |
| `.gif`              | `.gfw`                     |

## Licencia

Este proyecto está licenciado bajo la Licencia Pública General de GNU v3.0.
Consulta el archivo `LICENSE` para más detalles.