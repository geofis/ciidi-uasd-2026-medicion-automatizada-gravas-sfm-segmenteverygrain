# Detección automatizada de tramos costeros arenosos para el análisis multitemporal de playas de República Dominicana

**Presentación en el V Congreso Internacional de Investigación, Desarrollo e Innovación (I+D+I), UASD, 2026**

**José-Ramón Martínez-Batlle**  
Facultad de Ciencias, Universidad Autónoma de Santo Domingo (UASD)  
Santo Domingo, República Dominicana  
<jmartinez19@uasd.edu.do>  
ORCID: [0000-0001-9924-0327](https://orcid.org/0000-0001-9924-0327)

**Enlace a la presentación de diapositivas:**  
https://geofis.github.io/ciidi-uasd-2026-deteccion-automatizada-tramos-costeros-arenosos/

**Número de palabras en el resumen:** 205

## Resumen

La identificación de playas arenosas es un paso necesario para evaluar sistemáticamente sus cambios mediante imágenes satelitales, pero su delimitación manual a escala nacional resulta costosa y poco reproducible. Este trabajo tiene como objetivo desarrollar un procedimiento automatizado para identificar tramos costeros arenosos de República Dominicana que posteriormente puedan ser analizados mediante series históricas de líneas de costa. La metodología utiliza Google Earth Engine e imágenes Sentinel-2 para generar composiciones estacionales del período seco mediante enmascaramiento de nubes y sombras y estadísticos temporales robustos. Se combinan bandas espectrales, índices de agua, vegetación y suelo desnudo e información temática auxiliar. Las pruebas preliminares permitieron obtener mosaicos nacionales de alta calidad, pero mostraron que la clasificación espectral sin restricciones espaciales confunde arena de playa con superficies construidas, suelos desnudos y depósitos fluviales. A partir de estos resultados se propone delimitar primero la interfaz mar-tierra, restringir la clasificación a una franja litoral y caracterizar segmentos costeros para determinar la presencia de superficies arenosas. Se concluye que incorporar explícitamente el contexto espacial costero es necesario para reducir falsos positivos y automatizar la selección de unidades de análisis. Los tramos resultantes permitirán aplicar posteriormente CoastSat y series Landsat para reconstruir la evolución de las playas desde la década de 1990.

## Recursos

- [Presentación interactiva](https://geofis.github.io/ciidi-uasd-2026-deteccion-automatizada-tramos-costeros-arenosos/)

## Algunas instrucciones

- Para generar la presentación HTML autocontenida, ejecutar en Bash:

```bash
mkdir -p /tmp/ciidi-autocontenido
quarto render index.qmd \
  --to revealjs \
  --output index_autocontenido.html \
  --output-dir /tmp/ciidi-autocontenido \
  -M self-contained:true \
  -M embed-resources:true
mv /tmp/ciidi-autocontenido/index_autocontenido.html docs/presentacion-autocontenida.html
# NO OLVIDAR VOLVER A RENDERIZAR index.qmd y generar PDF (ver abajo) para que la presentación interactiva vuelva a usar recursos externos.
```
- Para generar el PDF de la presentación, ejecutar en la consola de R (PRIMERO RENDERIZAR index.qmd) `pagedown::chrome_print("docs/index.html", output = "docs/index.pdf")`