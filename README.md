# MT5_ticks_to_MySQL
Recopilación de ticks de MetaTrader 5 a MySQL directamente en la base de datos a través de libmysql en tiempo real 3

#MQL5 #MT5 #MySQL

<h4>Instalación:</h4>
<p> - copiar el contenido a la carpeta del terminal MQL</p> 
<p> - habilitar dll en la configuración del terminal</p>
<p> - instalar, configurar MySQL y crear una base de datos para ticks</p>

<h4>Ajustes:</h4>
De las caracteristicas:
Si el campo Lista de instrumentos se deja en blanco, se recopilarán los ticks de todos los instrumentos de Market Watch.
<p align="center">
  <img src="https://github.com/Lxbinary/MT5_ticks_to_MySQL/raw/master/image/setup.png" width="400"/>
</p>

<h4>Imprimir registro de trabajo:</h4>
<p align="center">
  <img src="https://github.com/Lxbinary/MT5_ticks_to_MySQL/raw/master/image/mt_log.png" width="600"/>
</p>

el tiempo dedicado a escribir en la base de datos se indica en ms 24

Después de conectarse a la base de datos, el propio asesor crea las tablas necesarias para cada par.
<p align="center">
  <img src="https://github.com/Lxbinary/MT5_ticks_to_MySQL/raw/master/image/bd1.png" width="600"/>
</p>

<p align="center">
  <img src="https://github.com/Lxbinary/MT5_ticks_to_MySQL/raw/master/image/bd2.png" width="600"/>
</p>

<b>ATENCIÓN:</b>
Desafortunadamente, liba funciona solo en modo síncrono, por lo que todo funciona más rápido y no hay retrasos; recomiendo ejecutar varios terminales, idealmente, un terminal separado para cada par

