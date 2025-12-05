;;; ImageGeoRef.lsp -- Georreferencia imagenes raster en AutoCAD usando archivos World.
;;; Copyright (C) [Año] [Nombre del autor]
;;;
;;; This program is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; INFO:
;;; Este script es compatible con AutoCAD 2012 y versiones posteriores.
;;; Lee un archivo World (.jgw, .pgw, etc.) para aplicar posición, escala y rotación.

;;; Asegura que las funciones VLAX esten disponibles (necesario para AutoCAD clasico).
(if (not (vl-catch-all-error-p (vl-catch-all-apply 'vlax-get-acad-object nil)))
  (vl-load-com)
)

;;; Funcion principal del comando IMAGEGEOREF.
(defun c:ImageGeoRef (/ img-ent img-path img-dir img-name img-ext world-ext world-path world-data success)
  (princ "\n=== Georreferenciacion de Imagenes Raster ===\n")
  
  ;; Solicita al usuario la seleccion de una entidad de imagen.
  (setq img-ent (car (entsel "\nSelecciona la imagen raster a georreferenciar: ")))
  
  (if img-ent
    (progn
      ;; Obtener la ruta del archivo de imagen
      (setq img-path (get-image-path img-ent))
      
      (if img-path
        (progn
          ;; Extraer directorio, nombre y extensión
          (setq img-dir (vl-filename-directory img-path))
          (setq img-name (vl-filename-base img-path))
          ;; Obtener extensión (en mayúsculas y sin el punto inicial)
          (setq img-ext (strcase (vl-string-left-trim "." (vl-filename-extension img-path))))
          
          ;; Determinar extensión del archivo World
          (setq world-ext (get-world-extension img-ext))
          
          (if world-ext
            (progn
              ;; Construir ruta del archivo World (compatible con Windows)
              (if img-dir
                (setq world-path (strcat img-dir "\\" img-name world-ext))
                (setq world-path (strcat img-name world-ext))
              )
              
              (princ (strcat "\nBuscando archivo World: " world-path))
              
              ;; Leer archivo World
              (setq world-data (read-world-file world-path))
              
              (if world-data
                (progn
                  ;; Aplicar georreferenciación
                  (setq success (apply-georeference img-ent world-data))
                  
                  (if success
                    (princ "\n[OK] Imagen georreferenciada correctamente.")
                    (princ "\n[ERROR] Error al aplicar la georreferenciacion.")
                  )
                )
                (princ (strcat "\n[ERROR] No se pudo leer el archivo World: " world-path))
              )
            )
            (princ (strcat "\n[ERROR] Extension de imagen no soportada: " img-ext))
          )
        )
        (princ "\n[ERROR] No se pudo obtener la ruta del archivo de imagen.")
      )
    )
    (princ "\n[ERROR] No se selecciono ninguna imagen.")
  )
  
  (princ)
)

;;; Obtiene la ruta completa del archivo de una entidad de imagen raster.
;;; Valida que la entidad seleccionada sea una imagen.
(defun get-image-path (ent / obj img-path err)
  (if ent
    (progn
      ;; Manejo de errores para compatibilidad con AutoCAD 2012
      (setq err (vl-catch-all-apply 
                  '(lambda ()
                     (setq obj (vlax-ename->vla-object ent))
                     (if (and obj (= (vla-get-objectname obj) "AcDbRasterImage"))
                       (progn
                         (setq img-path (vla-get-imagefile obj))
                         img-path
                       )
                       (progn
                         (princ "\n[ERROR] La entidad seleccionada no es una imagen raster.")
                         nil
                       )
                     )
                   )
                )
      )
      (if (vl-catch-all-error-p err)
        (progn
          (princ "\n[ERROR] No se pudo acceder a las propiedades de la imagen.")
          nil
        )
        err
      )
    )
    nil
  )
)

;;; Devuelve la extension del archivo World correspondiente a la extension de la imagen.
;;; Por ejemplo, para "PNG" devuelve ".PGW".
(defun get-world-extension (img-ext / ext-map)
  (setq ext-map '(("JPG" . ".JGW")    ; JPG -> JGW
                  ("JPEG" . ".JGW")   ; JPEG -> JGW
                  ("PNG" . ".PGW")    ; PNG -> PGW (mismo formato que JGW/TFW)
                  ("TIF" . ".TFW")    ; TIF -> TFW
                  ("TIFF" . ".TFW")   ; TIFF -> TFW
                  ("BMP" . ".BPW")    ; BMP -> BPW
                  ("GIF" . ".GFW")))  ; GIF -> GFW
  
  (cdr (assoc img-ext ext-map))
)

;;; Lee un archivo World y devuelve una lista con sus seis valores numericos.
(defun read-world-file (world-path / file line values found-path)
  ;; Buscar el archivo (compatible con AutoCAD 2012)
  (setq found-path (findfile world-path))
  (if found-path
    (progn
      (setq file (open found-path "r"))
      (if file
        (progn
          (setq values '())
          ;; Leer las 6 líneas del archivo World
          (repeat 6
            (setq line (read-line file))
            (if line
              (setq values (append values (list (atof line))))
              (setq values nil)
            )
          )
          (close file)
          
          (if (and values (= (length values) 6))
            values
            (progn
              (princ "\n[ERROR] El archivo World no tiene el formato correcto (debe tener 6 lineas).")
              nil
            )
          )
        )
        (progn
          (princ (strcat "\n[ERROR] No se pudo abrir el archivo: " found-path))
          nil
        )
      )
    )
    (progn
      (princ (strcat "\n[ERROR] Archivo World no encontrado: " world-path))
      nil
    )
  )
)

;;; Aplica la transformacion de georreferenciacion a la entidad de imagen.
;;; Intenta primero el metodo VLA, que es mas directo y preciso. Si falla
;;; (comun en versiones antiguas o con configuraciones especificas), recurre a un
;;; metodo alternativo que utiliza comandos de AutoCAD (MOVE, SCALE, ROTATE).
(defun apply-georeference (ent world-data / obj pixel-size-x rot-row rot-col pixel-size-y 
                                 origin-x origin-y img-width-px img-height-px insertion-point 
                                 scale-x scale-y rotation err err-msg success corner-ll-x
                                 corner-ll-y success-alt current-insertion ent-data img-path 
                                 scale-factor-avg err3 min-pt max-pt img-width-actual
                                 min-pt-list max-pt-list img-width-desired scale-base-point
                                 img-dims)
  (if (and ent world-data (= (length world-data) 6))
    (progn
      (setq obj (vlax-ename->vla-object ent))
      
      (if (and obj (= (vla-get-objectname obj) "AcDbRasterImage"))
        (progn
          ;; Extraer valores del archivo World
          (setq pixel-size-x (nth 0 world-data))
          (setq rot-row (nth 1 world-data))
          (setq rot-col (nth 2 world-data))
          (setq pixel-size-y (nth 3 world-data))
          (setq origin-x (nth 4 world-data))
          (setq origin-y (nth 5 world-data))
          
          ;; Validar datos del archivo World
          (if (or (equal pixel-size-x 0.0 1e-9) (equal pixel-size-y 0.0 1e-9))
            (progn
              (princ "\n[ERROR] El archivo World contiene un tamaño de píxel (pixel-size) de cero, lo cual no es válido.")
              (setq success nil) ; Marcar como fallo para que no continue
            )
            (progn ; Continuar solo si los datos son validos
              ;; Obtener dimensiones de la imagen en pixeles de forma robusta.
              (setq img-path (vla-get-imagefile obj))
              (setq img-dims (get-image-dimensions-robust img-path obj))
              (setq img-width-px (car img-dims))
              (setq img-height-px (cadr img-dims))
              
              ;; El punto de insercion de una imagen en AutoCAD es su esquina inferior izquierda.
              ;; El origen del archivo World es el centro del pixel superior izquierdo.
              ;; La siguiente seccion calcula la coordenada de la esquina inferior izquierda
              ;; de la imagen en el sistema de coordenadas del mundo.
              ;;
              ;; Transformacion afin para convertir coordenadas de pixel a coordenadas del mundo:
              ;; X_world = origin-x + col * pixel-size-x + row * rot-col
              ;; Y_world = origin-y + col * rot-row + row * pixel-size-y
              (if (and (= rot-row 0.0) (= rot-col 0.0))
                ;; Sin rotación: caso simple
            (progn
              ;; Para calcular la esquina inferior izquierda:
              ;; 1. Se parte del centro del pixel (0,0) -> (origin-x, origin-y).
              ;; 2. Se mueve a la esquina superior izquierda -> restar medio pixel en X y Y.
              ;; 3. Se baja toda la altura de la imagen -> sumar (img-height * pixel-size-y).
              (setq insertion-point (list 
                                      (- origin-x (* 0.5 pixel-size-x))
                                      (+ origin-y (* img-height-px pixel-size-y) (* -0.5 pixel-size-y))))
            )
                ;; Con rotación: caso general
            (progn
              ;; Calcular centro del píxel inferior izquierdo (0, height-px-1)
              (setq corner-ll-x (+ origin-x (* (- img-height-px 1) rot-col)))
              (setq corner-ll-y (+ origin-y (* (- img-height-px 1) pixel-size-y)))
              
              ;; Ajustar a la esquina real (no centro del píxel)
              ;; Aplicar transformación inversa de medio píxel
              (setq insertion-point (list 
                                      (- corner-ll-x (* 0.5 pixel-size-x) (* 0.5 rot-col))
                                      (+ corner-ll-y (* 0.5 rot-row) (* 0.5 pixel-size-y))))
            )
              )
              
              ;; Calcular escala (magnitud de los vectores de transformación)
              (setq scale-x (sqrt (+ (* pixel-size-x pixel-size-x) (* rot-row rot-row))))
              (setq scale-y (sqrt (+ (* rot-col rot-col) (* pixel-size-y pixel-size-y))))
              
              ;; Calcular rotación (ángulo del vector de transformación en X)
              (if (and (= rot-row 0.0) (= rot-col 0.0))
                (setq rotation 0.0)
                (setq rotation (atan rot-row pixel-size-x))
              )
              
              ;; --- METODO PRINCIPAL (VLA) ---
              ;; Intenta aplicar la transformacion directamente a las propiedades del objeto imagen.
              ;; Es el metodo mas limpio y preciso, pero puede fallar en algunas versiones de AutoCAD.
              (setq success T)
              (setq err-msg "")
              
              (setq err (vl-catch-all-apply 
                          '(lambda ()
                             (vlax-put obj 'Origin (vlax-3d-point insertion-point))
                           )
                        )
              )
              (if (vl-catch-all-error-p err)
                (progn
                  (setq success nil)
                  (setq err-msg (strcat err-msg "Origin: " (vl-catch-all-error-message err) "; "))
                )
              )
              
              (if success
                (progn
                  (setq err (vl-catch-all-apply 
                              '(lambda ()
                                 (vlax-put obj 'ScaleFactor scale-x) ; ScaleFactor es un Double, no un punto 3D
                               )
                            )
                  )
                  (if (vl-catch-all-error-p err)
                    (progn
                      (setq success nil)
                      (setq err-msg (strcat err-msg "ScaleFactor: " (vl-catch-all-error-message err) "; "))
                    )
                  )
                )
              )
              
              (if (and success (not (and (= rot-row 0.0) (= rot-col 0.0))))
                (progn
                  (setq err (vl-catch-all-apply 
                              '(lambda ()
                                 (vlax-put obj 'Rotation rotation)
                               )
                            )
                  )
                  (if (vl-catch-all-error-p err)
                    (progn
                      (setq success nil)
                      (setq err-msg (strcat err-msg "Rotation: " (vl-catch-all-error-message err) "; "))
                    )
                  )
                )
              )
              
              (if success
                (progn
                  ;; Muestra un resumen de la transformacion aplicada.
                  (princ (strcat "\n  Origen World (centro pixel 0,0): X=" (rtos origin-x 2 4) ", Y=" (rtos origin-y 2 4)))
                  (princ (strcat "\n  Punto insercion (esq. inf. izq.): X=" (rtos (car insertion-point) 2 4) 
                                ", Y=" (rtos (cadr insertion-point) 2 4)))
                  (princ (strcat "\n  Escala: X=" (rtos scale-x 2 6) ", Y=" (rtos scale-y 2 6)))
                  (if (not (= rotation 0.0))
                    (princ (strcat "\n  Rotacion: " (rtos (* rotation (/ 180.0 pi)) 2 2) " grados"))
                  )
                  T
                )
                (progn
                  ;; --- METODO ALTERNATIVO (Comandos) ---
                  ;; Si el metodo VLA falla, se intenta georreferenciar la imagen
                  ;; usando los comandos nativos de AutoCAD: MOVE, SCALE y ROTATE.
                  ;; No se muestra el error VLA si el metodo alternativo tiene exito.
                  (princ "\n[INFO] El metodo VLA no esta disponible, intentando metodo alternativo...")
                  (setq success-alt nil)
                  
                  (setq err (vl-catch-all-apply 
                              '(lambda ()
                                 (setq current-insertion (vlax-get obj 'Origin))
                               )
                            )
                  )
                  
                  (if (vl-catch-all-error-p err)
                    (progn
                      (setq ent-data (entget ent))
                      (setq current-insertion (cdr (assoc 10 ent-data)))
                      (if current-insertion
                        (setq success-alt T)
                        (princ "\n[ERROR] No se pudo obtener la posicion actual de la imagen.")
                      )
                    )
                    (setq success-alt T)
                  )
                  
                  (if success-alt
                    (progn
                      (setq err3 (vl-catch-all-apply
                                   '(lambda ()
                                      ;; Método de escala alternativo: comparar tamaño actual con tamaño deseado.
                                      ;; Obtener el tamaño actual de la imagen en unidades de dibujo (sin rotación)
                                      (vla-getboundingbox obj 'min-pt 'max-pt)
                                      (setq min-pt-list (vlax-safearray->list min-pt))
                                      (setq max-pt-list (vlax-safearray->list max-pt))
                                      (setq img-width-actual (abs (- (car max-pt-list) (car min-pt-list))))
    
                                      ;; Calcular el tamaño deseado
                                      (setq img-width-desired (* img-width-px (abs pixel-size-x)))
    
                                      ;; Calcular el factor de escala necesario (deseado / actual).
                                      (if (> img-width-actual 1e-9)
                                        (setq scale-factor-avg (/ img-width-desired img-width-actual))
                                        (setq scale-factor-avg 1.0)
                                      )
                                    )
                                 )
                      )
                      
                      (if (not (vl-catch-all-error-p err3))
                        (progn
                          ;; Se mueve la imagen a su posicion final y luego se escala y rota
                          ;; usando esa posicion como punto base.
                          (setq scale-base-point insertion-point)
                          (setvar "CMDECHO" 0)
                          (command "_.MOVE" ent "" "_non" current-insertion "_non" scale-base-point)
                          (command "_.SCALE" ent "" "_non" scale-base-point scale-factor-avg)
                          (setvar "CMDECHO" 1)
                          
                          ;; El comando SCALE aplica un factor uniforme. Si el pixel no es cuadrado,
                          ;; la escala puede no ser perfecta en ambos ejes.
                          (if (not (equal (abs pixel-size-x) (abs pixel-size-y) 1e-9))
                            (princ "\n[ADVERTENCIA] El pixel no es cuadrado. El método alternativo usa una escala uniforme, lo que podría distorsionar la imagen. La escala se ha calculado en base al eje X.")
                          )
                        )
                        (progn
                          (princ (strcat "\n[ERROR] No se pudo calcular la escala: " (vl-catch-all-error-message err3)))
                        )
                      )
                      
                      ;; Aplicar rotación si existe
                      (if (not (and (= rot-row 0.0) (= rot-col 0.0)))
                        (progn
                          (setvar "CMDECHO" 0)
                          (command "_.ROTATE" ent "" 
                                   "_non" (list (car insertion-point) (cadr insertion-point) 0.0)
                                   (* rotation (/ 180.0 pi)))
                          (setvar "CMDECHO" 1)
                        )
                      )
                      
                      T
                    )
                    (progn
                      ;; Si ambos metodos fallan, se muestran todos los errores.
                      (princ (strcat "\n[ERROR] Fallo el metodo principal VLA: " err-msg))
                      (princ "\n[ERROR] Fallo el metodo alternativo: no se pudo obtener la posicion actual.")
                      nil
                    )
                  )
                )
              )
            ) ; Cierre del progn de validacion de datos del world file
          )
        )
        (progn
          (princ "\n[ERROR] La entidad no es una imagen raster valida.")
          nil
        )
      )
    )
    nil
  )
)

;;; Obtiene las dimensiones de una imagen de forma robusta leyendo la cabecera del archivo.
;;; Despacha al lector apropiado segun la extension del archivo.
;;; Recurre al metodo VLA si no hay un lector especifico.
(defun get-image-dimensions-robust (file-path obj / img-ext)
  (setq img-ext (strcase (vl-string-left-trim "." (vl-filename-extension file-path))))
  (cond
    ((= img-ext "PNG") (get-png-dimensions file-path))
    ((member img-ext '("JPG" "JPEG")) (get-jpeg-dimensions file-path))
    (t
      ;; Para otros formatos, se intenta el metodo VLA, que puede ser poco fiable.
      (if obj
        (list (vla-get-imagewidth obj) (vla-get-imageheight obj))
        '(0 0)
      )
    )
  )
)

;;; Obtiene las dimensiones (ancho x alto) de una imagen PNG.
;;; Este metodo es necesario porque las funciones VLA (vla-get-imagewidth) a veces
;;; devuelven valores incorrectos en algunas configuraciones de AutoCAD.
;;; La funcion lee directamente la cabecera del archivo PNG para obtener los valores.
;;;
;;; Especificacion PNG: https://www.w3.org/TR/PNG/
;;; El ancho y el alto son enteros de 32 bits (big-endian) en el chunk IHDR,
;;; comenzando en el byte 16 del archivo.
(defun get-png-dimensions (file-path / bytes width height err stream-obj)
  (setq width 0 height 0)
  (setq err (vl-catch-all-apply
              '(lambda ()
                 (setq stream-obj (vlax-create-object "ADODB.Stream"))
                 (vlax-put-property stream-obj 'Type 1) ; 1 = adTypeBinary
                 (vlax-invoke stream-obj 'Open) ; Usar vlax-invoke sin argumentos, es el método estándar para abrir un stream vacío
                 (vlax-invoke-method stream-obj 'LoadFromFile file-path)
                 (vlax-put-property stream-obj 'Position 16)
                 (setq bytes (vlax-safearray->list (vlax-variant-value (vlax-invoke-method stream-obj 'Read 8))))
                 (vlax-invoke-method stream-obj 'Close)
                 (vlax-release-object stream-obj)
                 (setq stream-obj nil)
               )
            )
  )
  (if (vl-catch-all-error-p err)
    (progn
      (princ (strcat "\n[ERROR] No se pudo leer el archivo PNG para obtener sus dimensiones: " (vl-catch-all-error-message err)))
      (if stream-obj (vlax-release-object stream-obj)) ; Asegurarse de liberar el objeto si hubo un error a medio camino
    )
    (if (and bytes (= (length bytes) 8))
      (progn ; Si la lectura fue exitosa, procesar los bytes
        ;; Calcular ancho (bytes 0-3, big-endian)
        (setq width (+ (* (nth 0 bytes) 16777216) (* (nth 1 bytes) 65536) (* (nth 2 bytes) 256) (nth 3 bytes)))
        ;; Calcular alto (bytes 4-7, big-endian)
        (setq height (+ (* (nth 4 bytes) 16777216) (* (nth 5 bytes) 65536) (* (nth 6 bytes) 256) (nth 7 bytes)))
      )
    )
  )
  (list width height)
)

;;; Obtiene las dimensiones (ancho x alto) de una imagen JPEG.
;;; Lee la cabecera del archivo para encontrar un marcador SOF (Start of Frame)
;;; y extrae el ancho y el alto.
;;; Especificacion JPEG: https://www.w3.org/Graphics/JPEG/itu-t81.pdf
(defun get-jpeg-dimensions (file-path / stream-obj err width height found-marker marker-type segment-len-bytes segment-len h-bytes w-bytes)
  (setq width 0 height 0 found-marker nil)
  (setq err (vl-catch-all-apply
              '(lambda ()
                 (setq stream-obj (vlax-create-object "ADODB.Stream"))
                 (vlax-put-property stream-obj 'Type 1) ; adTypeBinary
                 (vlax-invoke stream-obj 'Open)
                 (vlax-invoke-method stream-obj 'LoadFromFile file-path)
                 
                 ;; Saltar marcador SOI (Start of Image), que son 2 bytes (FF D8)
                 (vlax-put-property stream-obj 'Position 2)
                 
                 ;; Buscar el marcador SOF (Start of Frame)
                 (while (and (not found-marker) (< (vlax-get-property stream-obj 'Position) (vlax-get-property stream-obj 'Size)))
                   ;; Todos los marcadores empiezan con 0xFF
                   (if (= (car (vlax-safearray->list (vlax-variant-value (vlax-invoke-method stream-obj 'Read 1)))) 255)
                     (progn
                       (setq marker-type (car (vlax-safearray->list (vlax-variant-value (vlax-invoke-method stream-obj 'Read 1)))))
                       (cond
                         ;; Marcadores SOF (Start of Frame) que contienen dimensiones.
                         ;; SOF0, SOF1, SOF2, etc. (0xC0-CF), excluyendo DHT(C4), JPGR(C8), DAC(CC).
                         ((member marker-type '(192 193 194 195 197 198 199 201 202 203 205 206 207))
                           (setq found-marker T)
                           (vlax-invoke-method stream-obj 'Read 3) ; Saltar longitud del segmento (2) y precision (1)
                           (setq h-bytes (vlax-safearray->list (vlax-variant-value (vlax-invoke-method stream-obj 'Read 2))))
                           (setq w-bytes (vlax-safearray->list (vlax-variant-value (vlax-invoke-method stream-obj 'Read 2))))
                           (setq height (+ (* (car h-bytes) 256) (cadr h-bytes)))
                           (setq width (+ (* (car w-bytes) 256) (cadr w-bytes)))
                         )
                         ;; Marcadores sin datos (RST, SOI, EOI) - no deberian encontrarse aqui, pero por si acaso.
                         ((member marker-type '(1 208 209 210 211 212 213 214 215 216 217))
                           ; No hacer nada, solo seguir buscando
                         )
                         ;; Otros marcadores tienen un campo de longitud que nos permite saltarlos.
                         (T
                           (setq segment-len-bytes (vlax-safearray->list (vlax-variant-value (vlax-invoke-method stream-obj 'Read 2))))
                           (setq segment-len (+ (* (car segment-len-bytes) 256) (cadr segment-len-bytes)))
                           ;; Mover la posicion mas alla de este segmento
                           (vlax-put-property stream-obj 'Position (+ (vlax-get-property stream-obj 'Position) (- segment-len 2)))
                         )
                       )
                     )
                   )
                 )
                 (vlax-invoke-method stream-obj 'Close)
                 (vlax-release-object stream-obj)
                 (setq stream-obj nil)
               )
            )
  )
  (if (vl-catch-all-error-p err)
    (progn (princ (strcat "\n[ERROR] No se pudo leer el archivo JPEG: " (vl-catch-all-error-message err))) (if stream-obj (vlax-release-object stream-obj)))
    (if (not found-marker) (princ "\n[ADVERTENCIA] No se encontró el marcador de dimensiones (SOF) en el archivo JPEG."))
  )
  (list width height)
)

;;; Mensaje de confirmacion de carga del script.
(princ "\n[OK] ImageGeoRef.lsp cargado. Usa el comando ImageGeoRef para georreferenciar imagenes.")
(princ)
