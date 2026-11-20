# Sesión recordada en Windows

`account.gd` conserva la sesión sólo cuando el jugador activa **Recuérdame**.
`motor/AAMIX.Session.exe` utiliza DPAPI con `DataProtectionScope.CurrentUser`.
El correo, nombre y token de renovación viajan mediante tuberías anónimas y se
guardan únicamente como bytes cifrados en `user://remembered_session.bin`.
Nunca se guarda el código recibido por correo ni el token de acceso.

La carpeta de usuario AAMIX y la finalidad de cifrado se mantienen entre versiones.
El archivo sólo puede recuperarse con el mismo usuario de Windows; no depende de
una dirección IP. Al abrir el juego se valida la renovación con Supabase antes de
aceptar la identidad. Los tokens renovados reemplazan el archivo de forma atómica.
Cerrar sesión o desactivar Recuérdame elimina los datos recordados.

El ayudante se compila con el compilador incluido en .NET Framework y la referencia
integrada `System.Security.dll`. El script reproducible de preparación es
`work/build_session_helper_v1.py`; el código fuente está en `SessionProtector.cs`.
La aplicación no requiere instalar bibliotecas de terceros.

Referencia del ciclo de renovación: [Sesiones de Supabase](https://supabase.com/docs/guides/auth/sessions).
