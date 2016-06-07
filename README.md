# Mi guia particular de containers

Desde que descubrí docker por casualidad (llevaba 1 mes liberado) me resultó altamente atractiva la idea de unir los namespaces,cgroups,capabilites e incluso seccomp en una sola tecnología. 
Si se include MAC (SElinux, AppArmor, grsec...) ya se borda.

Pues bien he probado "bastantes" tecnologías todos estos años pero siempre guardando cierta distancia curiosamente de docker por su poca madurez (todavía sigue estando muy verde en cuanto a seguridad para mi gusto y huyo de ella como de la peste).

Este documento lo queria escribir desde hace mucho tiempo pues al ir probando, vas averiguando cosas nuevas y siempre hace falta algun sitio para reunirlas todas y creo que este va a ser. 

De todo lo que he probado/usado la mas innovadora ha sido sin duda SELinux seguida de systemd-nspawn, aunque me gusta bastante lxc o libvirt para containers seguros o el reciente Clear containers de intel que hace uso de kvmtool/DAX intensivamente. 


##LXC

Hace poco me ha surgido la necesidad de probar armhf en un X86_64 en Fedora 23, despues de pelearme 4 dias para echar a andar el container como yo queria he sacado algunas conclusiones interesantes:

```bash
$dnf install lxc 
```

Para preparlo para un posible uso de libvirt editar /etc/lxc/default.conf y cambiar 'lxc.network.link' de 'lxcbr0' a 'virbr0':

```bash
lxc.network.type = veth
lxc.network.link = virbr0
lxc.network.flags = up
lxc.network.hwaddr = 00:16:3e:xx:xx:xx
```

###Instalar Fedora 23 x86_32 en Fedora 23 x86_64

```bash
$lxc-create -t download -n fedora386 -- -d fedora  --list 
Setting up the GPG keyring
Downloading the image index

---
DIST    RELEASE ARCH    VARIANT BUILD
---
fedora  22      amd64   default 20160527_01:27
fedora  22      armhf   default 20160112_01:27
fedora  22      i386    default 20160527_01:27
fedora  23      amd64   default 20160527_01:27
fedora  23      i386    default 20160527_01:27
---
$lxc-create -t download -n fedora386 -- -d fedora -r 23 -a i386
...
```
Se baja una rootfs ya preparado de internet y en apenas 1 minutos tenemos un sistema completo en local en /var/lib/lxc/fedora386. :)

Lo siguiente que podemos hacer es editar su configuración para ponerle un nombre a su interfaz de red:


```bash
cd /var/lib/lxc
echo "lxc.network.veth.pair = vethfedora386" >> fedora386/config
```
El momento que queramos levantarlo y conectarnos:

```bash
$lxc-start -n fedora386 
$lxc-info -n fedora386 
$lxc-attach -n fedora386 
```

Con esto tendremos un container CASI funcional porque no tenemos red y la verdad es que la solución no me ha sido facil de encontrarla... 

### Instalar red/network en LXC

Afortunadamente me he basado en este link, [Enable lxc networking](https://www.flockport.com/enable-lxc-networking-in-debian-jessie-fedora-and-others/)

Instalamos lo mínimo necesario en el host:

```bash
dnf install  dnsmasq bridge-utils iptables-services
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
```

Creamos un bridge y con las iputils le asignamos una ip y la levantamos (vayamos olvidandonos del viejo tandem ifconfig/route y ip que es bastante mas potente ;) ):

```bash
$brctl addbr virbr0
$ip address add 10.0.3.1/24 dev virbr0
$ip link set virbr0 up
```

Con esto ya hemos creado una interfaz puente (que es algo bastante trivial, simplemente esta en modo promiscuo y recibe todos los paquetes...), le asignamos una IP (va a ser la gw de los guests) y levantamos la interfaz. Se puede comprobar con:


```bash
$brctl show
bridge name     bridge id               STP enabled     interfaces
virbr0          8000.000000000000       no
$ip addr show virbr0
...
```

Lo siguiente que necesitamos es algo que asigne dinamicamente las ips a los guests o bien fijarlas en el archivo de configuracion. Para lo primero lanzando esto:


```bash
/sbin/dnsmasq \
        --dhcp-leasefile=/var/run/lxc-dnsmasq.leases \
        --user=nobody \
        --group=nobody \
        --keep-in-foreground \
        --listen-address=10.0.3.1 \
        --except-interface=lo \
        --bind-interfaces \
        --dhcp-range=10.0.3.2,10.0.3.254
```

Para lo segundo (ip estática):

```bash
$cd /var/lib/lxc
$echo "lxc.network.ipv4 = 10.0.3.3" >> fedora386/config
$lxc-start -n fedora386
$lxc-info -n fedora386
```

Todo esto está muy y hasta aquí llegaba el problema era que no habia conectividad con el exterior en los containers, hacian ping hasta el gw máximo... Sospechaba del firewalld pero no estaba seguro y gracias al link despejé todas las dudas, efectivamente necesitaba por pantalones de NAT y del clasico dhcp/dns:


```bash
iptables -I INPUT -i virbr0 -p udp --dport 67 -j ACCEPT
iptables -I INPUT -i virbr0 -p tcp --dport 67 -j ACCEPT
iptables -I INPUT -i virbr0 -p tcp --dport 53 -j ACCEPT
iptables -I INPUT -i virbr0 -p udp --dport 53 -j ACCEPT
iptables -I FORWARD -i virbr0 -j ACCEPT
iptables -I FORWARD -o virbr0 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.0.3.0/24 ! -d 10.0.3.0/24 -j MASQUERADE
iptables -t mangle -A POSTROUTING -o virbr0 -p udp -m udp --dport 68 -j CHECKSUM --checksum-fill
```

Con todo esto ya deberiamos de tener internet:

```bash
$lxc-start -n fedora386
$lxc-attach -n fedora386
fedora386$ ping google.com
```

Resumen: LXC es la hostia para ejecutar multitud de variantes de containers en tu host con una consumo ridiculo y una accesibilidad inmediata. Y para muestra un botón:


```bash
$lxc-create -t download -n list
Setting up the GPG keyring
Downloading the image index

---
DIST    RELEASE ARCH    VARIANT BUILD
---
centos  6       amd64   default 20160527_02:16
centos  6       i386    default 20160527_02:16
centos  7       amd64   default 20160527_02:16
debian  jessie  amd64   default 20160526_22:42
debian  jessie  arm64   default 20160526_22:42
debian  jessie  armel   default 20160526_22:42
debian  jessie  armhf   default 20160526_22:42
debian  jessie  i386    default 20160526_22:42
debian  jessie  powerpc default 20160526_22:42
debian  jessie  ppc64el default 20160526_22:42
debian  jessie  s390x   default 20160526_22:42
debian  sid     amd64   default 20160526_22:42
debian  sid     arm64   default 20160526_22:42
debian  sid     armel   default 20160526_22:42
debian  sid     armhf   default 20160526_22:42
debian  sid     i386    default 20160526_22:42
debian  sid     powerpc default 20160526_22:42
debian  sid     ppc64el default 20160526_22:42
debian  sid     s390x   default 20160526_22:42
debian  stretch amd64   default 20160526_22:42
debian  stretch arm64   default 20160526_22:42
debian  stretch armel   default 20160526_22:42
debian  stretch armhf   default 20160526_22:42
debian  stretch i386    default 20160526_22:42
debian  stretch powerpc default 20160526_22:42
debian  stretch ppc64el default 20160526_22:42
debian  stretch s390x   default 20160527_02:48
debian  wheezy  amd64   default 20160526_22:42
debian  wheezy  armel   default 20160526_22:42
debian  wheezy  armhf   default 20160526_22:42
debian  wheezy  i386    default 20160526_22:42
debian  wheezy  powerpc default 20160526_22:42
debian  wheezy  s390x   default 20160526_22:42
fedora  22      amd64   default 20160527_01:27
fedora  22      armhf   default 20160112_01:27
fedora  22      i386    default 20160527_01:27
fedora  23      amd64   default 20160527_01:27
fedora  23      i386    default 20160527_01:27
gentoo  current amd64   default 20160526_14:12
gentoo  current i386    default 20160526_14:12
opensuse        13.2    amd64   default 20160527_00:53
oracle  6       amd64   default 20160526_11:40
oracle  6       i386    default 20160526_11:40
oracle  7       amd64   default 20160526_11:40
plamo   5.x     amd64   default 20160526_21:36
plamo   5.x     i386    default 20160526_21:36
plamo   6.x     amd64   default 20160526_21:36
plamo   6.x     i386    default 20160526_21:36
ubuntu  precise amd64   default 20160527_03:49
ubuntu  precise armel   default 20160527_03:49
ubuntu  precise armhf   default 20160527_03:49
ubuntu  precise i386    default 20160527_03:49
ubuntu  precise powerpc default 20160527_03:49
ubuntu  trusty  amd64   default 20160527_03:49
ubuntu  trusty  arm64   default 20160527_03:49
ubuntu  trusty  armhf   default 20160527_03:49
ubuntu  trusty  i386    default 20160527_03:49
ubuntu  trusty  powerpc default 20160527_03:49
ubuntu  trusty  ppc64el default 20160527_03:49
ubuntu  wily    amd64   default 20160527_03:49
ubuntu  wily    arm64   default 20160527_03:49
ubuntu  wily    armhf   default 20160527_03:49
ubuntu  wily    i386    default 20160527_03:49
ubuntu  wily    powerpc default 20160527_03:49
ubuntu  wily    ppc64el default 20160527_03:49
ubuntu  xenial  amd64   default 20160527_03:49
ubuntu  xenial  arm64   default 20160527_07:01
ubuntu  xenial  armhf   default 20160527_03:49
ubuntu  xenial  i386    default 20160527_03:49
ubuntu  xenial  powerpc default 20160527_03:49
ubuntu  xenial  ppc64el default 20160527_03:49
ubuntu  xenial  s390x   default 20160527_03:49
ubuntu  yakkety amd64   default 20160527_03:49
ubuntu  yakkety arm64   default 20160527_03:49
ubuntu  yakkety armhf   default 20160527_03:49
ubuntu  yakkety i386    default 20160527_03:49
ubuntu  yakkety powerpc default 20160527_03:49
ubuntu  yakkety ppc64el default 20160527_03:49
ubuntu  yakkety s390x   default 20160527_07:01
---

Distribution: ^C

```

Mola, ¿no?.


###Instalar Debian jessie armhf en Fedora 23 x86_64

Mi objetivo era instalar un container con debian armhf y compilar en el el software que necesitaba y por supuesto necestivaba internet. Como se verá mas adelante todo un fail porque qemu-arm-static no dispone de netlink así que hagas lo que hagas no vas a tener connectividad en el container... :(

Lo primero que necesitas para correr armhf en x86 es un emulador y que sea estático, en fedora solo se destribuye qemu-arm (dinámico) y el estático tienes que bajartelo & compilartelo tu mismo y para ello necesitas una maquina de 32bits a ser posible. Aprovecharemos pues la maquina recien instalada o bien el mio ya preparado [qemu-arm-static](./qemu-arm-static). ;)

```bash
$lxc-start -n fedora386
$lxc-attach -n fedora386
fedora386$ dnf install @development-tools
fedora386$ dnf install glibc-static zlib-static gcc glib2-devel glib2-static pixman-devel
fedora386$ git clone git://git.qemu.org/qemu.git  --depth 1 && cd qemu
fedora386$ PKG_CONFIG_LIBDIR=/usr/lib/pkgconfig ./configure --extra-cflags="-m32" --target-list=arm-linux-user --static  --extra-ldflags="-m32"
fedora386$ cp arm-linux-user/qemu-arm ~/qemu-arm-static
fedora386$ exit
$ cp /var/lib/lxc/fedora386/rootfs/root/qemu-arm-static /usr/bin/
```

Ya lo tenemos instalado en el host. Ahora hace falta configurar binfmt de tal modo que cuando detecte un ELF que sea de arquitectura arm ejecute el qemu-arm-static en vez del qemu-arm (dinamico).

```bash
$echo ':arm:M::\x7fELF\x01\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\x28\x00:\xff\xff\xff\xff\xff\xff\xff\x00\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff\xff:/usr/bin/qemu-arm-static:' > /proc/sys/fs/binfmt_misc/register

```

Si nos diera problemas diciendo que ya está habilitado o lo que sea lo podremos borrar con:
```bash
$echo -1 > /proc/sys/fs/binfmt_misc/arm 
```

Finalmente comprobamos que se ha instalado correctamente:

```bash
$cat /proc/sys/fs/binfmt_misc/arm
enabled
interpreter /usr/bin/qemu-arm-static
flags: 
offset 0
magic 7f454c4601010100000000000000000002002800
mask ffffffffffffff00fffffffffffffffffeffffff
```

Con el qemu-arm-static listo podemos pasar a instalar el container arm:

```bash
$lxc-create -t download -n jessiearm -- -d debian -r jessie -a armhf
$cd /var/lib/lxc
$cp /usr/bin/qemu-arm-static  jessiearm/rootfs/usr/bin/
$lxc-start --name jessiearm
$lxc-attach --name jessiearm
jessiearm$ PATH+=:/bin:/sbin
jessiearm$ /bin/ping google.com
bash: /bin/ping: No such file or directory
jessiearm$ uname -a
Linux jessie 4.4.7-300.fc23.x86_64 #1 SMP Wed Apr 13 02:52:52 UTC 2016 armv7l GNU/Linux
```

En resumen NO hay network en LXC para arm porque qemu-arm-static todavia no soporta netlink, ni mount, ni ptrace ...

##QEMU

###Allwinner A20 (armhf/armv7)  on X86_64

Queremos emular un A20 AllWinner(una machine vexpress-a9 en qemu) concretamente para una Olinuxino Lime2.

Lo podriamos hacer para fedora del siguiente modo, notese que partimos de Fedora minimal y que utilizamos un dtb de vexpress-a15 que nos permitirá utilizar el doble de RAM.

```bash
cd /var/lib/lxc
$wget -c -nc https://ftp.fau.de/fedora/linux/releases/23/Images/armhfp/Fedora-Minimal-armhfp-23-10-sda.raw.xz
$unxz Fedora-Minimal-armhfp-23-10-sda.raw.xz 
$wget -c -nc https://dl.fedoraproject.org/pub/fedora/linux/releases/23/Server/armhfp/os/images/pxeboot/dtb/vexpress-v2p-ca15-tc1.dtb
```

Ahora necesitamos obtener el kernel y el initrd, facilmente:

```bash
$dnf install -y qemu-system-arm
$kpartx -av Fedora-Minimal-armhfp-23-10-sda.raw
add map loop0p1 (253:3): 0 585728 linear /dev/loop0 2048
add map loop0p2 (253:4): 0 499712 linear /dev/loop0 587776
add map loop0p3 (253:5): 0 2344960 linear /dev/loop0 1087488
$mkdir /tmp/boot
$mount /dev/mapper/loop0p1 /tmp/boot
$cp /tmp/boot/initramfs-4.2.3-300.fc23.armv7hl.img .
$cp /tmp/boot/vmlinuz-4.2.3-300.fc23.armv7hl .
$umount /tmp/boot
$kpartx -dv Fedora-Minimal-armhfp-23-10-sda.raw 
del devmap : loop0p3
del devmap : loop0p2
del devmap : loop0p1
loop deleted : /dev/loop0
```

Ahora hace falta juntarlo todo para arrancar la maquina, recordad que en vez de usar vexpress-a9 usaremos vexpress-a15 que permite el doble de RAM. ;)

```bash
qemu-system-arm -machine vexpress-a15 -m 2048 -nographic -net nic -net user \
        -append "console=ttyAMA0,115200n8 rw root=/dev/mmcblk0p3 rootwait physmap.enabled=0" \
        -kernel vmlinuz-4.2.3-300.fc23.armv7hl  \
        -initrd initramfs-4.2.3-300.fc23.armv7hl.img \ 
        -sd  Fedora-Minimal-armhfp-23-10-sda.raw  \
        -dtb vexpress-v2p-ca15-tc1.dtb
```

O si quereis preferis usar el script le podeis pasar --m=800 para ajustar la RAM si no disponeis de suficiente libre. ;)

```bash
./boot-vexpress.sh --kernel=vmlinuz-4.2.3-300.fc23.armv7hl --ramfs=initramfs-4.2.3-300.fc23.armv7hl.img --image=Fedora-Minimal-armhfp-23-10-sda.raw -dtb=vexpress-v2p-ca15-tc1.dtb --m=800
```
