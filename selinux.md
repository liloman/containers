# Mi guia particular de  SELinux

Voy a intentar hacer un poco de guia de Selinux porque es una tecnologia que he tocado varias veces pero que se te olvida y nada mejor que una guia para eso. :)

##Install

En fedora para tener lo basico: 

```bash
$dnf install selinux-policy-devel setools-console policycoreutils-python-utils -y
[root@localhost ~]# setenforce 1
[root@localhost ~]# sestatus
SELinux status:                 enabled
SELinuxfs mount:                /sys/fs/selinux
SELinux root directory:         /etc/selinux
Loaded policy name:             targeted
Current mode:                   enforcing
Mode from config file:          permissive
Policy MLS status:              enabled
Policy deny_unknown status:     allowed
Max kernel policy version:      30
[root@localhost ~]# vi /etc/selinux/config
# This file controls the state of SELinux on the system.
# SELINUX= can take one of these three values:
#     enforcing - SELinux security policy is enforced.
#     permissive - SELinux prints warnings instead of enforcing.
#     disabled - No SELinux policy is loaded.
SELINUX=enforcing
# SELINUXTYPE= can take one of these three values:
#     targeted - Targeted processes are protected,
#     minimum - Modification of targeted policy. Only selected processes are protected.
#     mls - Multi Level Security protection.
SELINUXTYPE=targeted
[root@localhost ~]# reboot
[root@localhost ~]# sestatus
SELinux status:                 enabled
SELinuxfs mount:                /sys/fs/selinux
SELinux root directory:         /etc/selinux
Loaded policy name:             targeted
Current mode:                   enforcing
Mode from config file:          enforcing
Policy MLS status:              enabled
Policy deny_unknown status:     allowed
Max kernel policy version:      30
```

##Funcionamiento

Segun Dan Walsh, Selinux funciona como las muñecas rusas es decir:

Un usuario/grupo del sistema cualquiera puede pertenecer a un usuario de Selinux, dicho usuario de selinux tendrá uno o mas roles asociados y cada rol tendrá a su vez un tipo asociado (domain en terminologia selinux).

Por lo tanto:

usuario_sistema -> selinux_user -> * selinux_rol -> * selinux_tipo

Es de destacar que primeramente se comprueban los permisos DAC y despues los MAC (selinux) por eficacia y versatibilidad.


Al poder estar asociado un usuario de selinux a varios roles, se le tiene que asociar un rol por defecto y para poder cambiar a otro de sus roles tiene que darse las reglas que se hayan asociado. En cada rol asimismo el usuario (usando ese rol) tendrá únicamente permiso para los objetos que tenga el tipo permitido. Asimismo un usuario es imposible que pueda cambiar a otro rol al cual no tenga definido.

Como veremos a continuación el numero de usuario de selinux posibles es limitado (se pueden crear todos los que se quieran), el numero de roles es bastante mayor y la granuladidad de control sobre los tipos es simplemente enorme, por lo que cada vez que se mueve uno mas a la derecha la granuladidad es mayor y asimismo la complejidad. 


Veamos los usuarios minimos existentes (Fedora 25):

```bash
semanage user -l

                Labeling   MLS/       MLS/                          
SELinux User    Prefix     MCS Level  MCS Range                      SELinux Roles

guest_u         user       s0         s0                             guest_r
root            user       s0         s0-s0:c0.c1023                 staff_r sysadm_r system_r unconfined_r
staff_u         user       s0         s0-s0:c0.c1023                 staff_r sysadm_r system_r unconfined_r
sysadm_u        user       s0         s0-s0:c0.c1023                 sysadm_r
system_u        user       s0         s0-s0:c0.c1023                 system_r unconfined_r
unconfined_u    user       s0         s0-s0:c0.c1023                 system_r unconfined_r
user_u          user       s0         s0                             user_r
xguest_u        user       s0         s0                             xguest_r

```

Como se puede apreciar existen varios predefinidos, los cuales como se puede observar tiene asociados al menos un rol, incluso existe un usuario root que es equivalente al usuario root del sistema por defecto. 

A simple vista observando los roles se puede apreciar que:

1. x/guest_u serán los que menos permisos tendrán, siendo la unica diferencia es que uno podrá ejecutar aplicaciones gráficas y el otro no

2. user_u será el siguiente

3. sysadm_u será el siguiente pues tiene permisos de sysadm_r

4. staff_u , system_u, unconfined_u y root serán los ultimos, pues directamente podrán pasar a unconfined_r el cual no tiene ninguna barrera (ojo que como se ha dicho primero se comprueban los DAC por lo que un usuario cualquiera como system_u se le aplicaran sus permisos de usuario y grupo en el sistema como toda la vida primeramente ... ) 

Si se requiere de un usuario que vaya a ejecutar su/sudo y cambie a root es recomendable usar el usuario predefinido staff_u de tal modo que tenga suficientes permisos para ejecutar bastantes tareas y en el momento de pasar a root aplicarle el rol unconfined_u.

Para este ejemplo comencemos creando un usuario user_u y dandole permisos pasito a pasito para ir viendo como operar. Desde hace mas de una decada todos los comandos de la coreutil admiten el flag -Z  que hace que operen con selinux nativamente (cp,mkdir,useradd,mv ...), comenzemos creado un usuario pues:

```bash
useradd -m -Z user_u uselinux
passwd uselinux
(log como uselinux efectivamente)
id -Z
user_u:user_r:user_t:s0
```

Para ver los usuarios actuales y su mapeado:

```bash
[root@localhost ~]# semanage login -l

Login Name           SELinux User         MLS/MCS Range        Service

__default__          unconfined_u         s0-s0:c0.c1023       *
root                 unconfined_u         s0-s0:c0.c1023       *
uselinux             user_u               s0                   *
```
Vemos como por defecto los usuario no estan confinados (uconfined_u) y como el usuario que se acaba de crear tiene asociado el usuario user_u de selinux.

Veamos pues que puede hacer el usuario user_u:

```bash
 semanage user -l

                Labeling   MLS/       MLS/
SELinux User    Prefix     MCS Level  MCS Range                      SELinux Roles

guest_u         user       s0         s0                             guest_r
root            user       s0         s0-s0:c0.c1023                 staff_r sysadm_r system_r unconfined_r
staff_u         user       s0         s0-s0:c0.c1023                 staff_r sysadm_r system_r unconfined_r
sysadm_u        user       s0         s0-s0:c0.c1023                 sysadm_r
system_u        user       s0         s0-s0:c0.c1023                 system_r unconfined_r
unconfined_u    user       s0         s0-s0:c0.c1023                 system_r unconfined_r
user_u          user       s0         s0                             user_r
xguest_u        user       s0         s0                             xguest_r
```

Efectivamente solo puede usar el rol user_r. Veamos pues que puede hacer el rol user_r:

```bash
[root@localhost ~]# seinfo -ruser_r -x
   user_r
      Dominated Roles:
         user_r
      Types:
         abrt_helper_t
         alsa_home_t
         antivirus_home_t
         httpd_user_content_t
         httpd_user_htaccess_t
         httpd_user_script_t
         httpd_user_script_exec_t
         httpd_user_rw_content_t
         httpd_user_ra_content_t
         auth_home_t
         chkpwd_t
         pam_timestamp_t
         updpwd_t
         utempter_t
         bluetooth_helper_t
         cdrecord_t
         chrome_sandbox_t
         chrome_sandbox_nacl_t
         chrome_sandbox_home_t
         cronjob_t
         crontab_t
         cvs_home_t
         ddclient_t
         ...
```

Emm, como se puede ver el rol user_r tiene asociados un montón de types. Comenzemos diciendo que el usuario tiene un usuario de selinux asociado pero este usuario de selinux puede lanzar procesos y dichos procesos son los que tienen asociados los roles, dichos procesos pueden acceder a una cantidad inmensa de recursos los cuales pueden ser controlados (tipos) y todo ello junto es lo que se llama contexto. 

Por ejemplo veamos que se puede hacer con el primer tipo (abrt_helper_t):

```bash
[root@localhost ~]# sesearch -A -s abrt_helper_t  | head -n 5
Found 466 semantic av rules:
   allow nsswitch_domain file_context_t : dir { ioctl read getattr lock search open } ; 
   allow domain sshd_t : fifo_file { ioctl read write getattr lock append } ; 
   allow abrt_helper_t abrt_helper_t : fifo_file { ioctl read write getattr lock append open } ; 
   allow domain root_t : dir { ioctl read getattr lock search open } ;
   ...
```

Este tipo tiene simplemente 466 reglas activas, ademas he buscado por origen de abrt_helper_t y me aparece domain, sshd_t ...  ¿como puede ser posible eso?. 

Veamos primero que es lo que se puede controlar en cada rol y despues se entenderá rapidamente como puede ser posible: :)

```bash
[root@localhost ~]# seinfo --stats

Statistics for policy file: /sys/fs/selinux/policy
Policy Version & Type: v.30 (binary, mls)

   Classes:            94    Permissions:       257
   Sensitivities:       1    Categories:       1024
   Types:            4791    Attributes:        272
   Users:               8    Roles:              14
   Booleans:          305    Cond. Expr.:       354
   Allow:          102096    Neverallow:          0
   Auditallow:        155    Dontaudit:        8875
   Type_trans:      17950    Type_change:        74
   Type_member:        35    Role allow:         39
   Role_trans:        420    Range_trans:      5753
   Constraints:       109    Validatetrans:       0
   Initial SIDs:       27    Fs_use:             28
   Genfscon:          107    Portcon:           601
   Netifcon:            0    Nodecon:             0
   Permissives:        15    Polcap:              2
```

Veamos que existen 94 Clases, 4791 tipos, 1024 Categorias, 420 transiciones de tipo ...

¿Que son las clases?

Digamos que los objetos que puedes controlar, es decir desde los ficheros (file) a sus descriptores(fd) pasando por las capabilities del sistema (capability/2). Es decir muchisimas cosas.


```bash
[root@localhost ~]# seinfo -c
Object classes: 94
   netlink_audit_socket
   tcp_socket
   msgq
   x_property
   binder
   db_procedure
   dir
   peer
   blk_file
   chr_file
   db_table
   db_tuple
   dbus
   ipc
   lnk_file
   netlink_connector_socket
   process
   capability2
   fd
   packet
   socket
   cap_userns
   fifo_file
   file
   node
   x_cursor
   ...
```

¿Y que se puede controlar de cada clase?

Pues muchisimas cosas por ejemplo de cada fichero:

```bash
[root@localhost ~]# seinfo  -cfile -x
   file
      append
      create
      execute
      write
      relabelfrom
      link
      unlink
      ioctl
      getattr
      setattr
      read
      rename
      lock
      relabelto
      mounton
      quotaon
      swapon
      audit_access
      entrypoint
      execmod
      execute_no_trans
      open
```

Si se puede escribir, montar, utilizar como swap, lock, eliminar, linkar ...

¿Y de las capabilities? 

```bash
[root@localhost ~]# seinfo  -ccapability -x
   capability
      setfcap
      setpcap
      fowner
      sys_boot
      sys_tty_config
      net_raw
      sys_admin
      sys_chroot
      sys_module
      sys_rawio
      dac_override
      ipc_owner
      kill
      dac_read_search
      sys_pacct
      net_broadcast
      net_bind_service
      sys_nice
      sys_time
      fsetid
      mknod
      setgid
      setuid
      lease
      net_admin
      audit_write
      linux_immutable
      sys_ptrace
      audit_control
      ipc_lock
      sys_resource
      chown
```

Básicamente todas si no me equivoco, la habilidad de chroot, la de ptrace la de cambiar de dueño...
Para el que no sepa lo que son las capability (estan muy de moda con los containers) son basicamente todos los permisos superiores del sistema, basicamente root tiene todas las capabilities por defecto pero si se le quita una ya dejará de poder realizar esa acción en concreta por muy root que sea (existen muchisimas formas de establecer las capabilities de un proceso y esta es una mas). ;)


Así que basicamente el usuario uselinux ejecuta sus procesos con el rol user_r y este a su vez tiene unos permisos determinados en el sistema. Cualquier acción que realize y para la cual no tenga esos permisos explicitamente diseñados en su rol será denegada.

Al haber tantisimos tipos (4791 segun las stats de mas arriba), estos se pueden agrupar en los que se llaman atributos (272):


```bash
root@localhost ~]# seinfo -a

Attributes: 272
   cert_type
   privfd
   file_type
   boinc_domain
   ...
[root@localhost ~]# seinfo -acert_type -x 
   cert_type
      dovecot_cert_t
      fwupd_cert_t
      slapd_cert_t
      cert_t
      pki_tomcat_cert_t
      home_cert_t
```

De tal modo que se puedan operar en grupo sobre ellos, asimismo se pueden crear alias que simplemente son otro nombre para el mismo contexto, utiles por ejemplo para no romper con la compatibilidad cuando se decide cambiar el nombre a un tipo como ha pasado con anterioridad.

Normalmente los atributos terminan en _type o sin terminación, los _t pueden ser identificadores/alias o tipos de atributos que basicamente son grupos de atributos. 

Asi que tenemos:

tipos identificadores/alias (_t) -> * atributos (_type/sin sufijo) -> * tipos atributos (_t)

Comprobemoslo:

```bash
[root@localhost ~]# seinfo  -thome_cert_t -x
   home_cert_t
      file_type
      non_auth_file_type
      non_security_file_type
      polymember
      cert_type
      user_home_content_type
      user_home_type
[root@localhost ~]# seinfo  -aprivfd -x
   privfd
      auditadm_screen_t
      auditadm_su_t
      auditadm_sudo_t
      cdrecord_t
      crond_t
      dbadm_sudo_t
      getty_t
      guest_t
      local_login_t
      ..._t
[root@localhost ~]# seinfo -thttpd_sys_rw_content_t -x
   httpd_sys_rw_content_t
      httpdcontent
      httpd_content_type
      file_type
      non_auth_file_type
      non_security_file_type
   Aliases
      httpd_sys_script_rw_t
      httpd_sys_content_rw_t
      httpd_fastcgi_rw_content_t
      httpd_fastcgi_script_rw_t
```

Bien pues dicho lo cual vamos a ver que permisos tiene un tipo en concreto. Veamos el home_cert_t que parece ser algo relativo a los certificados. :)


```bash
root@localhost ~]# seinfo  -thome_cert_t -x
   home_cert_t
      file_type
      non_auth_file_type
      non_security_file_type
      polymember
      cert_type
      user_home_content_type
      user_home_type
```

Asi que home_cert_t es un tipo de atributo que engloba varios atributos. Todo esto sigue siendo un follon que no nos lleva a ningun lado. :) 

Veamos lo que puede hacer el primer tipo de atributo de privfd:


```bash
[root@localhost ~]# sesearch -A -s auditadm_screen_t -C | head -n 7
Found 556 semantic av rules:
   allow nsswitch_domain file_context_t : dir { ioctl read getattr lock search open } ; 
   allow auditadm_screen_t auditadm_screen_t : fd use ; 
   allow domain sshd_t : fifo_file { ioctl read write getattr lock append } ; 
   allow auditadm_screen_t home_root_t : lnk_file { read getattr } ; 
   allow domain root_t : dir { ioctl read getattr lock search open } ; 
   allow domain netlabel_peer_t : tcp_socket recvfrom ; 
```

Vaaale, pues tiene 556 reglas nada mas, ¿pocas no?. xD

Basicamente se leen (notación polaca inversa):

```bash
allow nsswitch_domain file_context_t : dir { ioctl read getattr lock search open } ; 
allow           -> Permitir (hemos usado el flag -A así que todas seran de allow)
nsswitch_domain -> Dominio de origen (para un proceso entonces)
file_context_t  -> tipo de atributo de destino
dir             -> Clase es decir un directorio
{ ioctl read...}-> Permisos
```

Asi que permite a un  proceso con el nsswithc_domain que acceda a un directorio con la etiqueta file_context_t acceder y ver su contenido basicamente. No permite ni borrarlo, ni cambiarle sus atributos, ni crear nada en el ...


Y os volvereis a preguntar porque vuelven a aparecer tipos que no tienen nada que ver con lo que se ha buscado (auditadm_screen_t) al igual que pasaba con abrt_helper_t (mas arriba), pues porque como acabamos de ver un tipo puede puede englobar a varios atributos por lo que auditadm_screen_t parece englobar a nsswitch_domain entre otros. Comprobemoslo:

```bash
[root@localhost ~]# seinfo  -tauditadm_screen_t -x
   auditadm_screen_t
      application_domain_type
      nsswitch_domain
      corenet_unlabeled_type
      domain
      kernel_system_state_reader
      netlabel_peer_type
      privfd
      syslog_client_type
      pcmcia_typeattr_7
      pcmcia_typeattr_6
      pcmcia_typeattr_5
      pcmcia_typeattr_4
      pcmcia_typeattr_3
      pcmcia_typeattr_2
      pcmcia_typeattr_1
      screen_domain
      userdom_home_reader_type
```


Esto se repite 556 veces mas solamente para este tipo, como vimos mas arriba el rol user_r tiene bastantes tipos asociados:


```bash
[root@localhost ~]# seinfo -ruser_r -x
   user_r
      Dominated Roles:
         user_r
      Types:
         abrt_helper_t
         alsa_home_t
         antivirus_home_t
         httpd_user_content_t
         httpd_user_htaccess_t
         httpd_user_script_t
         httpd_user_script_exec_t
         httpd_user_rw_content_t
         httpd_user_ra_content_t
         auth_home_t
         chkpwd_t
         pam_timestamp_t
         updpwd_t
         utempter_t
         bluetooth_helper_t
         cdrecord_t
         chrome_sandbox_t
         chrome_sandbox_nacl_t
         chrome_sandbox_home_t
         cronjob_t
         crontab_t
         cvs_home_t
         ddclient_t
         ...
```

Así que digamos que es practicamente imposible saber a simple vista que puede o no puede hacer dicho ususario/rol porque tienes miles de reglas asociadas. Quiere decir esto que puede realizar cualquier cosa en el sistema, ni muchisimo menos el rol user_r es un rol que limita bastante las acciones posibles del usuario. Es como pretender querer saber al detalle todos los permisos DAC que afecta a un usuario del sistema, con la cantidad de ficheros/directorios del sistema son miles aunque logicamente su complejidad es muchisimo menor que la de Selinux porque basicamente se controlan 3 permisos (r,w o x) y en este caso son cientos de posibles permisos los controlados (257 concretamente) eso contando únicamente lo que hasta ahora sabemos que no es ni muchisimo menos todo lo que se puede/tiene que controlar. ;)

Como vimos mas arriba las classes (objetos) son las que contienen los permisos y se pueden consultar los permisos de cada clase:

```bash
[root@localhost ~]# seinfo

Statistics for policy file: /sys/fs/selinux/policy
Policy Version & Type: v.30 (binary, mls)

   Classes:            94    Permissions:       257
   Sensitivities:       1    Categories:       1024
   Types:            4791    Attributes:        272
   Users:               8    Roles:              14
   Booleans:          305    Cond. Expr.:       354
   Allow:          102096    Neverallow:          0
   Auditallow:        155    Dontaudit:        8875
   Type_trans:      17950    Type_change:        74
   Type_member:        35    Role allow:         39
   Role_trans:        420    Range_trans:      5753
   Constraints:       109    Validatetrans:       0
   Initial SIDs:       27    Fs_use:             28
   Genfscon:          107    Portcon:           601
   Netifcon:            0    Nodecon:             0
   Permissives:        15    Polcap:              2
[root@localhost ~]# seinfo -csocket -x
   socket
      append
      bind
      connect
      create
      write
      relabelfrom
      ioctl
      name_bind
      sendto
      recv_msg
      send_msg
      getattr
      setattr
      accept
      getopt
      read
      setopt
      shutdown
      recvfrom
      lock
      relabelto
      listen
```

Pues bien, al igual que en el DAC/ACL hay que centrarse en un directorio/fichero en concreto en el caso del MAC es igual, hay que ir a lo concreto.


Con el comando runcon se puede ejecutar comandos cambiadole el contexto probemos a ejecutar un comando con un rol que no tenemos asociado:

```bash
[uselinux@localhost ~]$ id -Z
user_u:user_r:user_t:s0
[uselinux@localhost ~]$ runcon -r user_r echo "hola"
hola
[uselinux@localhost ~]$ runcon -r unconfined_r echo "hola"
runcon: invalid context: ‘user_u:unconfined_r:user_t:s0’: Invalid argument
```

Veamos lo que tenemos en casa:

```bash
[uselinux@localhost ~]$ ls -alZ
total 16
drwx------. 5 uselinux uselinux user_u:object_r:user_home_dir_t:s0   140 Mar 21 15:43 .
drwxr-xr-x. 4 root     root     system_u:object_r:home_root_t:s0      37 Mar 20 18:37 ..
-rw-------. 1 uselinux uselinux unconfined_u:object_r:user_home_t:s0 642 Mar 21 15:20 .bash_history
-rw-r--r--. 1 uselinux uselinux user_u:object_r:user_home_t:s0        18 Sep 30 08:25 .bash_logout
-rw-r--r--. 1 uselinux uselinux user_u:object_r:user_home_t:s0       193 Sep 30 08:25 .bash_profile
-rw-r--r--. 1 uselinux uselinux user_u:object_r:user_home_t:s0       231 Sep 30 08:25 .bashrc
drwxrwxr-x. 2 uselinux uselinux user_u:object_r:mpd_home_t:s0          6 Mar 21 15:14 .mpd
-rw-rw-r--. 1 uselinux uselinux user_u:object_r:procmail_home_t:s0     0 Mar 21 14:59 .procmailrc
drwxrwxr-x. 2 uselinux uselinux user_u:object_r:screen_home_t:s0       6 Mar 21 15:24 .screen
drwxrwxr-x. 2 uselinux uselinux user_u:object_r:home_bin_t:s0         21 Mar 21 15:44 bin
```

Como se puede ver todo esta etiquetado con nuestro usuario de selinux user_u menos el directorio anterior /home que pertenece a system_u (el usuario del sistema y system_r es su rol equivalente).
Seguidamente se comprueba que todos los objetos tienen el rol object_r y no el que se esperaría, esto es debido a que como se ha mencionado con anterioridad los roles son unicamente para procesos y en los demas casos se utiliza el rol object_r simplemente "por relleno". 
Lo tercero son los tipos y como se observa el directorio actual tiene el user_home_dir_t y los objetos del interior por defecto user_home_t a no ser que tengan alguna contexto de fichero asociado como el es el caso por ejemplo del mpd_home_t o del home_bin_t.

Las contexto de fichero son reglas que se establecen de tal modo que las rutas tienen asociado un contexto por defecto. Se pueden buscar facilmente en:

```bash
[root@localhost ~]# grep -rin mpd_home_t /etc/selinux/targeted/contexts/files/
/etc/selinux/targeted/contexts/files/file_contexts.homedirs:26:/home/[^/]+/\.mpd(/.*)?	unconfined_u:object_r:mpd_home_t:s0
/etc/selinux/targeted/contexts/files/file_contexts.homedirs:219:/home/uselinux/\.mpd(/.*)?	user_u:object_r:mpd_home_t:s0
```

En el se dice que se si crea un directorio (.mpd(/.*)?) en el /home/* se le establecera un contexto y como el ultimo es el mas especifico (/home/selinux) es el que toma efecto y en vez de asociarle un unconfined_u se le asociado el user_u y cia.
Probemos a cambiarlo:

```bash
[root@localhost ~]# semanage fcontext -a -t user_home_t "/home/uselinux/\.mpd(/.*)?"
[root@localhost ~]# grep -r mpd_home_t /etc/selinux/targeted/contexts/files/
/etc/selinux/targeted/contexts/files/file_contexts.homedirs:/home/[^/]+/\.mpd(/.*)?	unconfined_u:object_r:mpd_home_t:s0
/etc/selinux/targeted/contexts/files/file_contexts.homedirs:/home/uselinux/\.mpd(/.*)?	user_u:object_r:mpd_home_t:s0
Binary file /etc/selinux/targeted/contexts/files/file_contexts.homedirs.bin matches
[uselinux@localhost ~]$ rmdir .mpd ; mkdir .mpd ; ls -alZ .mpd -d
drwxrwxr-x. 2 uselinux uselinux user_u:object_r:user_home_t:s0 6 Mar 21 16:05 .mpd
```
Como se puede observar no se ha agregado a file_contexts.homedris sino a *.bin, ello es debido a que dichos contextos se guardan directamente como PCRE en formato binario.
Lo correcto hubiera sido modificarlo en vez de añadir uno nuevo, vamos pues a eliminar el actual y modiicar el existente. ;)


```bash
[root@localhost ~]# semanage fcontext -d -t user_home_t "/home/uselinux/\.mpd(/.*)?"
[uselinux@localhost ~]$ restorecon -v .mpd/
restorecon reset /home/uselinux/.mpd context user_u:object_r:user_home_t:s0->user_u:object_r:mpd_home_t:s0
[root@localhost ~]# semanage fcontext -m -t user_home_t "/home/uselinux/\.mpd(/.*)?"
ValueError: File context for /home/uselinux/\.mpd(/.*)? is not defined
[root@localhost ~]# matchpathcon  "/home/uselinux/\.mpd(/.*)?"
/home/uselinux/\.mpd(/.*)?	user_u:object_r:user_home_t:s0
```
Parece que se trata de un bug (https://bugzilla.redhat.com/show_bug.cgi?id=1398427) detras de otro pero bueno lo importante es que efectivamente esta aplicado la etiqueta mpd_home_t al directorio .mpd. xD

Probemos a modificar el contexto a mano:

```bash
[root@localhost ~]# vi /etc/selinux/targeted/contexts/files/file_contexts.homedirs
/home/uselinux/\.mpd(/.*)?      user_u:object_r:mozilla_home_t:s0
[uselinux@localhost ~]$ restorecon -vR .mpd/
restorecon reset /home/uselinux/.mpd context user_u:object_r:mpd_home_t:s0->user_u:object_r:mozilla_home_t:s0
```
Pues efectivamente funciona.

##Modulo con nuevo tipo

Pasemos a algo mas complicado que ¿tal si creamos un nuevo tipo de files/dirs ?

```bash
[root@localhost ~]# seinfo -tsuper_privado_t
ERROR: could not find datum for type super_privado_t
[root@localhost ~]# cd /usr/share/selinux/packages/
[root@localhost packages]# mkdir super_privado ; cd super_privado
[root@localhost super_privado]# ln -s /usr/share/selinux/devel/Makefile .
[root@localhost super_privado]# vi super_privado.te
policy_module(super_privado, 1.0)

#se importa cualquier tipo que se vaya a usar en el modulo
gen_require(`
  type user_t;
  type user_home_dir_t;
')

#definimos un tipo nuevo
type super_privado_t;
#lo hacemos tipo file/dir
files_type(super_privado_t)


#le ponemos todos los file permissions (seinfo -cfile -x ;) )
allow user_t super_privado_t:file { append create execute write relabelfrom link unlink ioctl getattr setattr read rename lock relabelto mounton quotaon swapon audit_access entrypoint execmod execute_no_trans open };
#todos los dir permissions igual que el file (no chiquitas ;) )
allow user_t super_privado_t:dir { append create execute write relabelfrom link unlink ioctl getattr setattr read rename lock relabelto mounton quotaon swapon rmdir audit_access remove_name add_name reparent execmod search open };

#name transition  ( para los fichero creados ) 
#si el user_t crea un dir llamado "super_privado" en un directorio que 
#tenga etiqueta "user_home_dir_t" este se creará con el tipo super_privado_t
type_transition user_t user_home_dir_t : dir super_privado_t "super_privado";
[root@localhost super_privado]# vi super_privado.fc
#para el restorecon solamente
/home/uselinux/super_privado(/.*)?  gen_context(user_u:object_r:super_privado_t,s0)
[root@localhost super_privado]# make
Compiling targeted super_privado module
/usr/bin/checkmodule:  loading policy configuration from tmp/super_privado.tmp
/usr/bin/checkmodule:  policy configuration loaded
/usr/bin/checkmodule:  writing binary representation (version 17) to tmp/super_privado.mod
Creating targeted super_privado.pp policy package
rm tmp/super_privado.mod.fc tmp/super_privado.mod
[root@localhost super_privado]# semodule -v -i super_privado.pp
Attempting to install module 'super_privado.pp':
Ok: return value of 0.
Committing changes:
Ok: transaction number 0.
[root@localhost super_privado]# seinfo -tsuper_privado_t -x
   super_privado_t
      file_type
      non_auth_file_type
      non_security_file_type
[uselinux@localhost ~]$ mkdir super_privado
[uselinux@localhost ~]$ ls -dZ super_privado/
user_u:object_r:super_privado_t:s0 super_privado/
[uselinux@localhost ~]$ touch super_privado/prueba
[uselinux@localhost ~]$ ls -Z super_privado/
user_u:object_r:super_privado_t:s0 prueba
[uselinux@localhost ~]$ chcon -t user_home_t super_privado/
[uselinux@localhost ~]$ restorecon -v super_privado/
restorecon reset /home/uselinux/super_privado context user_u:object_r:user_home_t:s0->user_u:object_r:super_privado_t:s0
```

Han ocurrido un monton de cosas nuevas, pero digamos que se ha creado un nuevo modulo que alberga un nuevo tipo de objetos file/dir, el cual tiene un transición de nombre y un fichero de contexto asociado. Seguidamente se instala y se comprueba que funciona tanto la transición de nombre (mkdir/touch/...) como el fichero de contexto (restorecon). :)

Destacar que si se crea un objeto sin una regla explicitamente asociada este herederá el tipo del directorio padre, de ahí que en el .te hayamos usado el tipo user_home_dir_t y de ahí que los objetos creados en super_privado/ tenga el mismo tipo que su directorio padre por defecto (super_privado_t) . ;)

Este concepto es muy importante pues es muy similar al concepto de que un fork hereda de su padre todos sus recursos, esto permitía a cualquier proceso apagar la máquina gracias al fd del init, esto pasó desapercibido por mucho años hasta que se descubrió justamente analizando las transiciones de selinux con sus padres. ;)


##Transiciones

Con las nociones básicas sobre usuarios/roles/tipos (obviando completamente toda la parte que sigue a los contextos de MLS/MCS por ahora ;) ) y las nociónes básicas de creación de un nuevo tipo, veamos a ver lo que son las transiciones.











