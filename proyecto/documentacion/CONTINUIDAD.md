# AAMIX Online v1.3.1

Corrige caracteres corruptos en las filas de misiones del Desafío, Misiones y Eventos: separadores, signo de cantidad y marca de recompensa entregada. Se conserva la diagramación y el funcionamiento de v1.3.

Cierra el juego y pulsa Actualizar en tu instalador habitual; después, Jugar. Versión interna 1.11.1. Sin cambios de servidor, reglas, premios o progreso.

151 comprobaciones dirigidas sin fallos, incluidas tres verificaciones de los caracteres que se muestran en pantalla. Sin pruebas nuevas entre PCs remotos.

Base: work/AAMIX_v1.11.0/. Editable nuevo: work/AAMIX_v1.11.1/. Publicación autorizada en v1.11.1. El error provenía de recodificar mission_row.gd durante la preparación. Ahora los tres símbolos se declaran con escapes Unicode y las lecturas/escrituras de preparación son UTF-8 explícitas. No repetir migraciones ni resets. Mantener user://AAMIX, protocolo 3, ruleset 1.9 y minimum_launcher 1. Continuidad anterior en CONTINUIDAD_v1.3.md.
