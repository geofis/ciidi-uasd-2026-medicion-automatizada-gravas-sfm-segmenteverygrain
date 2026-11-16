# RECONSTRUCCION FINAL DE CLASTOS SEG Y VALIDACION DE CAMPO
# ==========================================================
# EJECUCION: source("fusion_SEG_inventario_final.R") desde la raiz del proyecto.
# ENTRADAS:
#  - resultados/resultados_completo/granos_mana.gpkg (capa granos)
#  - datos/clastos_validacion_centroides.gpkg (primera capa, puntos)
# SALIDAS (sin alterar las entradas):
#  - resultados/resultados_completo/granos_mana_final.gpkg
#      inventario_final: UNA entidad por clasto, todas las metricas en mm
#      validacion_puntos: puntos con identificador de clasto asignado
#  - resultados/resultados_completo/granos_mana_trazabilidad.csv
#      relacion de cada poligono SEG original con su clasto final
#  - resultados/resultados_completo/granos_mana_validacion.csv
#      comparacion campo/SEG, solo clastos con puntos de campo
#
# PROTOCOLO:
# 1. En QGIS, asignar el mismo grupo_fusion solo a fragmentos de UN clasto.
#    Dejar NULL para clastos que no requieran fusion. NO reutilizar 999.
# 2. Guardar y cerrar la edicion del GeoPackage.
# 3. Ejecutar este script. Si hay ambiguedades, corregirlas en QGIS y repetir.
# 4. Abrir inventario_final. Usar a_seg_mm y b_seg_mm para analisis.
# 5. Para validar, comparar a_seg_mm/b_seg_mm con a_campo_mm/b_campo_mm.
#
# DECISIONES METODOLOGICAS:
# - Las uniones usan st_union, sin dibujar ni completar superficies.
# - a/b son ejes COMPLETOS de elipse equivalente por momentos de area;
#   no son Feret ni necesariamente equivalentes a mediciones de campo.
# - Se recalculan a/b PARA TODOS los clastos finales para mantener
#   una metrica uniforme. Esto puede tardar varios minutos.
# - No se excluyen poligonos por contacto con borde de tesela.
# - El campo grupo_fusion final toma id_campo si hay validacion.
#   grupo_fusion_manual conserva el identificador previo.
# - Si un punto cae justo en el borde, o no tiene contencion unica,
#   se detiene con error: no se inventan correspondencias.
# - Los atributos originales de grupos fusionados se heredan del primer
#   fragmento SOLO como referencia; no se deben interpretar como metricas
#   agregadas. Las metricas finales se guardan en campos *_seg_*.
# ==========================================================

suppressPackageStartupMessages(library(sf))

base <- "resultados/resultados_completo"
entrada <- file.path(base, "granos_mana.gpkg")
capa_granos <- "granos"
f_campo <- "datos/clastos_validacion_centroides.gpkg"
salida <- file.path(base, "granos_mana_final.gpkg")
archivo_traza <- file.path(base, "granos_mana_trazabilidad.csv")
archivo_validacion <- file.path(base, "granos_mana_validacion.csv")

# No sobrescribir accidentalmente una salida revisada.
for (f in c(salida, archivo_traza, archivo_validacion)) {
  if (file.exists(f)) stop("Salida ya existente; mover o renombrar: ", f)
}
stopifnot(file.exists(entrada), file.exists(f_campo))

x <- st_read(entrada, layer = capa_granos, quiet = TRUE)
puntos <- st_read(f_campo, quiet = TRUE)

# Diagnóstico de geometrías vacías
vacios_granos <- which(st_is_empty(x))
vacios_puntos <- which(st_is_empty(puntos))

cat("Granos con geometría vacía:",
    length(vacios_granos), "\n")

cat("Puntos con geometría vacía:",
    length(vacios_puntos), "\n")

# Examinar atributos de los registros problemáticos
if (length(vacios_granos) > 0) {
  print(st_drop_geometry(x[vacios_granos, ]))
}

if (length(vacios_puntos) > 0) {
  print(st_drop_geometry(puntos[vacios_puntos, ]))
}

if (!"grupo_fusion" %in% names(x)) stop("Falta grupo_fusion en granos")
if (!all(c("id_campo", "a_campo_mm", "b_campo_mm") %in% names(puntos))) {
  stop("Faltan id_campo, a_campo_mm o b_campo_mm en los puntos")
}
if (is.na(st_crs(x)) || st_is_longlat(x)) stop("Granos requiere CRS proyectado en metros")
if (is.na(st_crs(puntos))) stop("Los puntos no tienen CRS")
if (!all(as.character(st_geometry_type(x)) %in% c("POLYGON", "MULTIPOLYGON"))) {
  stop("La capa granos debe contener solo poligonos")
}
# if (any(st_is_empty(x)) || any(st_is_empty(puntos))) stop("Geometrias vacias")
# Conservar registros excluidos para auditoría
granos_vacios <- x[st_is_empty(x), ]
puntos_vacios <- puntos[st_is_empty(puntos), ]

# Excluir únicamente las geometrías vacías
x <- x[!st_is_empty(x), ]
puntos <- puntos[!st_is_empty(puntos), ]

cat("Granos excluidos:", nrow(granos_vacios), "\n")
cat("Puntos excluidos:", nrow(puntos_vacios), "\n")

if (nrow(x) == 0 || nrow(puntos) == 0) {
  stop("No quedan geometrías suficientes para continuar.")
}

invalidos <- which(!st_is_valid(x))
cat("Polígonos inválidos:", length(invalidos), "\n")
cat("Porcentaje:", round(100 * length(invalidos) / nrow(x), 2), "%\n")
# Motivos de invalidez
table(st_is_valid(x, reason = TRUE)[invalidos])

# Reparar únicamente las geometrías inválidas
invalidos <- which(!st_is_valid(x))

if (length(invalidos) > 0) {
  cat("Reparando", length(invalidos),
      "geometrías inválidas...\n")
  
  x[invalidos, ] <- st_make_valid(x[invalidos, ])
}

# Extraer componentes poligonales si la reparación
# produjo colecciones de geometrías
x <- st_collection_extract(x, "POLYGON", warn = FALSE)

# Comprobación posterior
if (any(!st_is_valid(x))) {
  stop("Persisten geometrías inválidas después de la reparación")
}

if (any(st_is_empty(x))) {
  stop("La reparación produjo geometrías vacías")
}

if (any(!st_is_valid(puntos))) stop("Hay puntos invalidos")
if (nrow(x) == 0L) stop("Inventario vacio")

puntos <- st_transform(puntos, st_crs(x))
x$grupo_fusion <- trimws(as.character(x$grupo_fusion))
x$grupo_fusion[is.na(x$grupo_fusion) | x$grupo_fusion == ""] <- NA_character_
if (any(x$grupo_fusion == "999", na.rm = TRUE)) {
  stop("Quedan poligonos con grupo_fusion='999'. Revisar antes: ",
       sum(x$grupo_fusion == "999", na.rm = TRUE))
}

puntos$id_campo <- trimws(as.character(puntos$id_campo))
if (any(is.na(puntos$id_campo) | puntos$id_campo == "")) stop("Puntos sin id_campo")
if (anyDuplicated(puntos$id_campo)) stop("Hay id_campo repetidos en puntos")

# Evitar colisiones con columnas calculadas de salida.
calculadas <- c("uid_final", "grupo_fusion_manual", "n_fragmentos", "ids_seg_origen",
                "id_campo", "a_campo_mm", "b_campo_mm", "a_seg_mm", "b_seg_mm",
                "area_seg_m2", "area_seg_mm2", "perimetro_seg_m", "d_equiv_mm",
                "razon_ba_seg", "error_a_mm", "error_b_mm", "error_a_pct",
                "error_b_pct", "estado_fusion")
colisiones <- intersect(names(x), setdiff(calculadas, c("id_campo", "a_campo_mm", "b_campo_mm")))
if (length(colisiones)) stop("Campos de salida ya presentes en granos: ", paste(colisiones, collapse = ", "))
# Si ya hay campos de validacion en granos, los sustituimos con los del punto.
for (nm in intersect(names(x), c("id_campo", "a_campo_mm", "b_campo_mm"))) x[[nm]] <- NULL

# 1. Agrupar SOLO los registros con grupo_fusion; los demas quedan individuales.
#    Usar indices de filas, sin depender de id_grano, que podria repetirse.
indices_grupo <- split(which(!is.na(x$grupo_fusion)),
                       x$grupo_fusion[!is.na(x$grupo_fusion)])
indices_solos <- which(is.na(x$grupo_fusion))
cat("Originales:", nrow(x), "| grupos:", length(indices_grupo),
    "| sin agrupar:", length(indices_solos), "\n")

# Mantener todos los atributos del primer fragmento de cada grupo y los
# atributos de cada poligono no agrupado, sin construir 47 mil sf individuales.
primeros <- c(vapply(indices_grupo, `[`, integer(1), 1L), indices_solos)
miembros <- c(unname(indices_grupo), as.list(indices_solos))
if (length(primeros) != length(miembros)) stop("Error al construir indices")
if (length(unlist(miembros)) != nrow(x) ||
    anyDuplicated(unlist(miembros))) stop("No hay correspondencia 1:1 de originales")

final <- x[primeros, , drop = FALSE]
final$grupo_fusion_manual <- final$grupo_fusion
final$n_fragmentos <- lengths(miembros)
final$estado_fusion <- ifelse(final$n_fragmentos > 1L, "fusionado", "individual")
final$uid_final <- seq_len(nrow(final))
final$ids_seg_origen <- vapply(miembros, function(ii) {
  if ("id_grano" %in% names(x)) paste(x$id_grano[ii], collapse = ";")
  else paste(ii, collapse = ";")
}, character(1))

# Fusionar solo grupos con mas de una entidad.
# IMPORTANTE: reconstruir sfc tras incorporar MULTIPOLYGON.
# Modificar g[[k]] en una sfc_POLYGON NO actualiza su clase.
g <- as.list(st_geometry(final))
for (k in which(final$n_fragmentos > 1L)) {
  gg <- st_union(st_geometry(x)[miembros[[k]]])
  if (length(gg) != 1L) {
    stop("Union inesperada en grupo: ", final$grupo_fusion[k])
  }
  g[[k]] <- gg[[1]]
}
# Construir una sfc nueva y homogeneizar todos los tipos a MULTIPOLYGON.
# No altera los contornos: un POLYGON se convierte en MULTIPOLYGON
# de una sola parte.
g <- st_sfc(
  lapply(seq_along(g), function(i) st_cast(g[[i]], "MULTIPOLYGON")),
  crs = st_crs(x)
)
g <- st_cast(g, "MULTIPOLYGON")
st_geometry(final) <- g

cat("Tipos finales:\n")
print(table(st_geometry_type(final)))
cat("Clase sfc:", paste(class(st_geometry(final)), collapse = ", "), "\n")

validez_final <- st_is_valid(final)
if (anyNA(validez_final) || any(!validez_final)) {
  stop("La union produjo geometrías inválidas; revisar grupos: ",
       paste(final$grupo_fusion[which(is.na(validez_final) |
                                     !validez_final)], collapse = ", "))
}

# 2. Union espacial de puntos de campo, DESPUES de fusionar.
#    st_within exige contencion estricta y unica.
rel <- st_within(puntos, final)
n_rel <- lengths(rel)
if (any(n_rel != 1L)) {
  print(data.frame(id_campo = puntos$id_campo[n_rel != 1L],
                   coincidencias = n_rel[n_rel != 1L]))
  stop("Puntos de campo sin poligono contenedor unico. Revisar geometria/posicion")
}
pos <- vapply(rel, `[`, integer(1), 1L)
if (anyDuplicated(pos)) {
  print(data.frame(id_campo = puntos$id_campo, uid_final = final$uid_final[pos]))
  stop("Dos o mas puntos de campo corresponden al mismo clasto")
}

# Evitar que id_campo de un punto se confunda con otro grupo manual existente.
colision <- puntos$id_campo %in% final$grupo_fusion_manual[!is.na(final$grupo_fusion_manual)] &
  vapply(seq_along(pos), function(i) {
    puntos$id_campo[i] != final$grupo_fusion_manual[pos[i]]
  }, logical(1))
if (any(colision)) stop("id_campo coincide con un grupo manual de OTRO clasto: ",
                        paste(puntos$id_campo[colision], collapse = ", "))






final$id_campo <- NA_character_
final$a_campo_mm <- NA_real_
final$b_campo_mm <- NA_real_
final$id_campo[pos] <- puntos$id_campo
final$a_campo_mm[pos] <- suppressWarnings(as.numeric(as.character(puntos$a_campo_mm)))
final$b_campo_mm[pos] <- suppressWarnings(as.numeric(as.character(puntos$b_campo_mm)))
if (any(!is.finite(final$a_campo_mm[pos]) | !is.finite(final$b_campo_mm[pos]) |
        final$a_campo_mm[pos] <= 0 | final$b_campo_mm[pos] <= 0)) {
  stop("Dimensiones de campo invalidas o no numericas")
}
final$grupo_fusion[pos] <- puntos$id_campo

# 3. Momentos de area: trasladar al origen local para evitar cancelacion UTM.
momentos_anillo <- function(xy) {
  if (nrow(xy) < 4L) stop("Anillo con menos de cuatro vertices")
  if (!all(xy[1, ] == xy[nrow(xy), ])) xy <- rbind(xy, xy[1, ])
  i <- seq_len(nrow(xy) - 1L); j <- i + 1L
  xi <- xy[i, 1]; yi <- xy[i, 2]
  xj <- xy[j, 1]; yj <- xy[j, 2]
  cr <- xi * yj - xj * yi
  c(A = sum(cr) / 2,
    Mx = sum((xi + xj) * cr) / 6,
    My = sum((yi + yj) * cr) / 6,
    Ixx = sum((yi^2 + yi*yj + yj^2) * cr) / 12,
    Iyy = sum((xi^2 + xi*xj + xj^2) * cr) / 12,
    Ixy = sum((2*xi*yi + xi*yj + xj*yi + 2*xj*yj) * cr) / 24)
}
metricas_elipse <- function(geom, crs) {
  s <- st_sfc(geom, crs = crs)
  bb <- st_bbox(s)
  origen <- c((bb["xmin"] + bb["xmax"]) / 2,
              (bb["ymin"] + bb["ymax"]) / 2)
  s <- s - as.numeric(origen)
  mp <- st_cast(s, "MULTIPOLYGON")[[1]]
  m <- setNames(numeric(6), c("A", "Mx", "My", "Ixx", "Iyy", "Ixy"))
  for (pol in mp) for (k in seq_along(pol)) {
    mk <- momentos_anillo(pol[[k]][, 1:2, drop = FALSE])
    if (abs(mk["A"]) < .Machine$double.eps) next
    m <- m + mk * (if (k == 1L) 1 else -1) * sign(mk["A"])
  }
  A <- unname(m["A"])
  if (!is.finite(A) || A <= 0) stop("Area no positiva")
  cx <- unname(m["Mx"]) / A; cy <- unname(m["My"]) / A
  S <- matrix(c(unname(m["Iyy"]) / A - cx^2,
                unname(m["Ixy"]) / A - cx*cy,
                unname(m["Ixy"]) / A - cx*cy,
                unname(m["Ixx"]) / A - cy^2), nrow = 2)
  lambda <- eigen(S, symmetric = TRUE, only.values = TRUE)$values
  if (any(lambda < -1e-9)) stop("Momentos negativos: revisar geometria")
  lambda <- pmax(lambda, 0)
  c(a_seg_mm = 4000 * sqrt(lambda[1]),
    b_seg_mm = 4000 * sqrt(lambda[2]),
    area_seg_m2 = A)
}

cat("Calculando ejes para", nrow(final), "clastos finales...\n")
met <- matrix(NA_real_, nrow(final), 3L,
              dimnames = list(NULL, c("a_seg_mm", "b_seg_mm", "area_seg_m2")))
for (k in seq_len(nrow(final))) {
  met[k, ] <- metricas_elipse(st_geometry(final)[[k]], st_crs(final))
  if (k %% 5000L == 0L) cat("  calculados:", k, "\n")
}
final$a_seg_mm <- met[, "a_seg_mm"]
final$b_seg_mm <- met[, "b_seg_mm"]
final$area_seg_m2 <- met[, "area_seg_m2"]
final$area_seg_mm2 <- final$area_seg_m2 * 1e6
final$perimetro_seg_m <- as.numeric(st_length(st_boundary(final)))
final$d_equiv_mm <- 2000 * sqrt(final$area_seg_m2 / pi)
final$razon_ba_seg <- final$b_seg_mm / final$a_seg_mm
final$error_a_mm <- final$a_seg_mm - final$a_campo_mm
final$error_b_mm <- final$b_seg_mm - final$b_campo_mm
final$error_a_pct <- 100 * final$error_a_mm / final$a_campo_mm
final$error_b_pct <- 100 * final$error_b_mm / final$b_campo_mm

# Trazabilidad: una fila por poligono SEG original.
traza <- data.frame(
  fila_seg = unlist(miembros, use.names = FALSE),
  uid_final = rep(final$uid_final, lengths(miembros)),
  grupo_fusion_manual = rep(final$grupo_fusion_manual, lengths(miembros)),
  grupo_fusion_final = rep(final$grupo_fusion, lengths(miembros)),
  stringsAsFactors = FALSE
)
if ("id_grano" %in% names(x)) traza$id_grano <- as.character(x$id_grano[traza$fila_seg])
if ("tesela" %in% names(x)) traza$tesela <- as.character(x$tesela[traza$fila_seg])
stopifnot(nrow(traza) == nrow(x), !anyDuplicated(traza$fila_seg))

puntos$uid_final <- final$uid_final[pos]
puntos$grupo_fusion <- final$grupo_fusion[pos]
puntos$a_seg_mm <- final$a_seg_mm[pos]
puntos$b_seg_mm <- final$b_seg_mm[pos]
puntos$error_a_pct <- final$error_a_pct[pos]
puntos$error_b_pct <- final$error_b_pct[pos]

# GeoPackage: inventario unico + puntos enlazados.
st_write(final, salida, layer = "inventario_final", quiet = TRUE)
st_write(puntos, salida, layer = "validacion_puntos", quiet = TRUE)
write.csv(traza, archivo_traza, row.names = FALSE, na = "")
write.csv(st_drop_geometry(final[!is.na(final$id_campo),
                                 c("uid_final", "grupo_fusion", "id_campo",
                                   "a_campo_mm", "b_campo_mm", "a_seg_mm", "b_seg_mm",
                                   "error_a_mm", "error_b_mm", "error_a_pct",
                                   "error_b_pct")]),
          archivo_validacion, row.names = FALSE, na = "")
cat("LISTO. Originales:", nrow(x), "| clastos finales:", nrow(final),
    "| validados:", length(pos), "\n")
cat("GeoPackage:", salida, "\n")







library(sf)
library(dplyr)
library(ggplot2)

base <- "resultados/resultados_completo"
archivo <- file.path(base, "granos_mana_final.gpkg")
dir.create("resultados/presentacion",
           recursive = TRUE, showWarnings = FALSE)
destino <- "resultados/presentacion"

stopifnot(file.exists(archivo))

datos <- st_read(
  archivo, layer = "inventario_final", quiet = TRUE
) |>
  st_drop_geometry()

# Filtrar mediciones válidas
datos <- datos |>
  filter(
    is.finite(a_seg_mm),
    is.finite(b_seg_mm),
    a_seg_mm > 0,
    b_seg_mm > 0
  )

# Resumen del inventario
resumen <- datos |>
  summarise(
    n_clastos = n(),
    n_fusionados = sum(n_fragmentos > 1),
    a_mediana_mm = median(a_seg_mm),
    b_mediana_mm = median(b_seg_mm),
    a_media_mm = mean(a_seg_mm),
    b_media_mm = mean(b_seg_mm),
    a_p95_mm = unname(quantile(a_seg_mm, .95)),
    b_p95_mm = unname(quantile(b_seg_mm, .95)),
    relacion_ba_mediana = median(razon_ba_seg)
  )

print(resumen)

write.csv(
  resumen,
  file.path(destino, "resumen_inventario.csv"),
  row.names = FALSE
)

tema <- theme_minimal(base_size = 13)

# Figura 1. Distribución del eje menor
p1 <- ggplot(datos, aes(x = b_seg_mm)) +
  geom_histogram(bins = 60, fill = "#4477AA") +
  scale_x_log10() +
  labs(
    title = "Distribución granulométrica",
    subtitle = "Eje menor de elipse equivalente",
    x = "Eje menor b (mm, escala logarítmica)",
    y = "Número de clastos"
  ) +
  tema

ggsave(
  file.path(destino, "01_granulometria.png"),
  p1, width = 10, height = 6, dpi = 250
)

# Figura 2. Distribución acumulada de tamaños
p2 <- ggplot(datos, aes(x = b_seg_mm)) +
  stat_ecdf(geom = "step", linewidth = 1) +
  scale_x_log10() +
  scale_y_continuous(labels = scales::percent) +
  labs(
    title = "Distribución acumulada de tamaños",
    x = "Eje menor b (mm, escala logarítmica)",
    y = "Porcentaje acumulado de clastos"
  ) +
  tema

ggsave(
  file.path(destino, "02_acumulada.png"),
  p2, width = 10, height = 6, dpi = 250
)

# Figura 3. Relación entre ejes
p3 <- ggplot(datos, aes(x = a_seg_mm, y = b_seg_mm)) +
  geom_point(alpha = .12, size = .6) +
  geom_abline(slope = 1, intercept = 0,
              linetype = "dashed") +
  coord_equal() +
  labs(
    title = "Relación entre los ejes de los clastos",
    x = "Eje mayor a (mm)",
    y = "Eje menor b (mm)"
  ) +
  tema

ggsave(
  file.path(destino, "03_relacion_ejes.png"),
  p3, width = 8, height = 7, dpi = 250
)

# Validación campo / SEG
val <- datos |>
  filter(
    !is.na(id_campo),
    is.finite(a_campo_mm),
    is.finite(b_campo_mm),
    a_campo_mm > 0,
    b_campo_mm > 0
  )

cat("\nClastos validados:", nrow(val), "\n")

if (nrow(val) > 0) {
  comparacion <- bind_rows(
    val |>
      transmute(
        id_campo, eje = "a",
        campo_mm = a_campo_mm,
        seg_mm = a_seg_mm
      ),
    val |>
      transmute(
        id_campo, eje = "b",
        campo_mm = b_campo_mm,
        seg_mm = b_seg_mm
      )
  ) |>
    mutate(
      error_mm = seg_mm - campo_mm,
      error_abs_mm = abs(error_mm),
      error_pct = 100 * error_mm / campo_mm
    )
  
  resumen_validacion <- comparacion |>
    group_by(eje) |>
    summarise(
      n = n(),
      sesgo_mm = mean(error_mm),
      MAE_mm = mean(error_abs_mm),
      RMSE_mm = sqrt(mean(error_mm^2)),
      MAPE_pct = mean(abs(error_pct)),
      correlacion = if (n() > 1)
        cor(campo_mm, seg_mm) else NA_real_,
      .groups = "drop"
    )
  
  print(resumen_validacion, width = Inf)
  
  write.csv(
    resumen_validacion,
    file.path(destino, "resumen_validacion.csv"),
    row.names = FALSE
  )
  
  p4 <- ggplot(
    comparacion,
    aes(x = campo_mm, y = seg_mm)
  ) +
    geom_point(size = 2.5, alpha = 0.8,
               color = "#4477AA") +
    geom_abline(
      slope = 1, intercept = 0,
      linetype = "dashed", color = "red"
    ) +
    facet_wrap(~eje, scales = "fixed") +
    coord_equal() +
    labs(
      title = "Validación de dimensiones de clastos",
      subtitle = "Línea discontinua: concordancia perfecta",
      x = "Medición de campo (mm)",
      y = "Medición mediante SEG (mm)"
    ) +
    tema
  
  p4
  
  ggsave(
    file.path(destino, "04_validacion.png"),
    p4, width = 10, height = 6, dpi = 250
  )
}

cat("\nResultados guardados en:", destino, "\n")
