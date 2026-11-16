"""Asignar grupo_fusion a las entidades seleccionadas en QGIS.

USO
1. Activar la capa vectorial que contiene el campo de texto grupo_fusion.
2. Seleccionar todos los fragmentos de UN mismo clasto.
3. Ejecutar el script desde QGIS (consola o ScriptRunner).
4. Aceptar el identificador aleatorio de seis caracteres, o escribir uno
   existente si se desea agregar fragmentos a un grupo previo.
5. Repetir para cada clasto. Cada ejecución genera un nuevo identificador.

ATENCIÓN: No usar el mismo identificador para clastos distintos. Los grupos
con idéntico grupo_fusion se unirán después mediante st_union() en R.
El script guarda las modificaciones pendientes de la capa al confirmar.
"""

import secrets

from qgis.core import QgsVectorLayer
from qgis.PyQt.QtWidgets import QInputDialog, QMessageBox

CAMPO = "grupo_fusion"
capa = iface.activeLayer()

if not isinstance(capa, QgsVectorLayer) or not capa.isValid():
    QMessageBox.warning(
        iface.mainWindow(), "Fusión de clastos",
        "Selecciona una capa vectorial válida."
    )
elif capa.fields().indexFromName(CAMPO) == -1:
    QMessageBox.warning(
        iface.mainWindow(), "Fusión de clastos",
        f"La capa no contiene el campo '{CAMPO}'."
    )
elif capa.selectedFeatureCount() == 0:
    QMessageBox.warning(
        iface.mainWindow(), "Fusión de clastos",
        "Primero selecciona los fragmentos de un mismo clasto."
    )
else:
    seleccionados = capa.selectedFeatureIds()
    n = len(seleccionados)
    idx = capa.fields().indexFromName(CAMPO)

    # Incluye valores existentes en la capa, también cambios aún sin guardar.
    existentes = {
        str(f[CAMPO]).strip()
        for f in capa.getFeatures()
        if f[CAMPO] is not None
    }

    # Generar un código nuevo, sin colisión con los grupos ya presentes.
    grupo_sugerido = secrets.token_hex(3)
    while grupo_sugerido in existentes:
        grupo_sugerido = secrets.token_hex(3)

    grupo, aceptado = QInputDialog.getText(
        iface.mainWindow(),
        "Asignar grupo de fusión",
        f"Polígonos seleccionados: {n}\n\n"
        "Identificador del clasto (nuevo código sugerido):",
        text=grupo_sugerido
    )

    if aceptado:
        grupo = grupo.strip()
        if not grupo:
            QMessageBox.warning(
                iface.mainWindow(), "Fusión de clastos",
                "El identificador no puede estar vacío."
            )
        else:
            # Permitir grupos existentes, pero pedir confirmación explícita.
            continuar = True
            if grupo in existentes:
                respuesta = QMessageBox.question(
                    iface.mainWindow(),
                    "Grupo ya existente",
                    f"El grupo '{grupo}' ya existe en la capa.\n\n"
                    "¿Quieres añadirle los polígonos seleccionados?\n"
                    "Esto hará que R los una con ese grupo.",
                    QMessageBox.Yes | QMessageBox.No,
                    QMessageBox.No
                )
                continuar = respuesta == QMessageBox.Yes

            if continuar:
                if not capa.isEditable() and not capa.startEditing():
                    QMessageBox.critical(
                        iface.mainWindow(), "Error",
                        "No se pudo iniciar la edición de la capa."
                    )
                else:
                    correctos = all(
                        capa.changeAttributeValue(fid, idx, grupo)
                        for fid in seleccionados
                    )
                    if not correctos:
                        QMessageBox.critical(
                            iface.mainWindow(), "Error",
                            "No se pudieron actualizar todos los polígonos. "
                            "La capa permanece en edición para revisión."
                        )
                    elif capa.commitChanges():
                        capa.removeSelection()
                        iface.messageBar().pushSuccess(
                            "Fusión de clastos",
                            f"{n} polígonos asignados al grupo '{grupo}'."
                        )
                    else:
                        QMessageBox.critical(
                            iface.mainWindow(), "Error al guardar",
                            "\n".join(capa.commitErrors())
                        )
