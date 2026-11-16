# Medición automatizada del tamaño superficial de gravas en llanuras de inundación mediante fotogrametría SfM y SegmentEveryGrain

**Presentación en el V Congreso Internacional de Investigación, Desarrollo e Innovación (I+D+I), UASD, 2026**

**José-Ramón Martínez-Batlle**  
Facultad de Ciencias, Universidad Autónoma de Santo Domingo (UASD)  
Santo Domingo, República Dominicana  
<jmartinez19@uasd.edu.do>  
ORCID: [0000-0001-9924-0327](https://orcid.org/0000-0001-9924-0327)

**Enlace a la presentación de diapositivas:**  
https://geofis.github.io/ciidi-uasd-2026-medicion-automatizada-gravas-sfm-segmenteverygrain/

**Número de palabras en el resumen:** 207

## Resumen

La caracterización granulométrica de depósitos de grava es fundamental para interpretar procesos fluviales, pero los métodos tradicionales de medición en campo son laboriosos y limitan la extensión espacial del muestreo. Este trabajo tiene como objetivo evaluar un procedimiento para medir y cartografiar el tamaño superficial de gravas en llanuras de inundación mediante la integración de fotogrametría Structure from Motion (SfM) y segmentación de imágenes basada en aprendizaje automático. Se utilizan fotografías adquiridas con dron a baja altura y procesadas fotogramétricamente para obtener productos georreferenciados de muy alta resolución. Sobre imágenes representativas se aplica SegmentEveryGrain, herramienta que combina redes neuronales y modelos de segmentación para delimitar clastos individuales. A partir de los objetos segmentados se obtienen métricas de tamaño y forma, que posteriormente se integran espacialmente para caracterizar la distribución granulométrica superficial. Los análisis preliminares muestran que las imágenes adquiridas a baja altura permiten reconocer clastos individuales y extender la medición automatizada a superficies mayores que las abordables mediante muestreo manual, aunque requieren control de calidad ante oclusiones, contactos entre granos y variaciones de iluminación. La integración de SfM y segmentación automatizada ofrece una estrategia reproducible y escalable para ampliar espacialmente el muestreo granulométrico y analizar patrones sedimentarios y geomorfológicos en llanuras de inundación con depósitos de gravas.

## Recursos

- [Presentación interactiva](https://geofis.github.io/ciidi-uasd-2026-medicion-automatizada-gravas-sfm-segmenteverygrain)

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
mv /tmp/ciidi-autocontenido/index_autocontenido.html "docs/José Martínez + Medición automatizada del tamaño superficial de gravas en llanuras de inundación mediante fotogrametría SfM y SegmentEveryGrain + 18 de noviembre + Sala LAB-FIA-408.html"
# NO OLVIDAR VOLVER A RENDERIZAR index.qmd y generar PDF (ver abajo) para que la presentación interactiva vuelva a usar recursos externos.
```
- Para generar el PDF de la presentación, ejecutar en la consola de R (PRIMERO RENDERIZAR index.qmd) `pagedown::chrome_print("docs/index.html", output = "docs/José Martínez + Medición automatizada del tamaño superficial de gravas en llanuras de inundación mediante fotogrametría SfM y SegmentEveryGrain + 18 de noviembre + Sala LAB-FIA-408.pdf")`