#!/usr/bin/env bash
#Boot a A20 system from qemu
 
usage() {
  echo "Usage: $0 [--gui]  [--m=RAM] --kernel=vmlinuz --ramfs=initramfs --image=fsimage --dtb=vexpress.dtb"
  exit 1
}

if [[ ! -f /usr/bin/qemu-system-arm ]]; then
  echo "You need to install qemu-system-arm to boot a versatile express image"
  exit 1
fi

GUI="--nographic"
MEMORY=2048

while [ $# -ne 0 ]; do
    option=$1
    shift

    optarg=""
    case $option in
    --*=*)
        optarg=`echo $option | sed -e 's/^[^=]*=//'`
        ;;
    esac

    case $option in
    -h|--h*)
        usage
        ;;
    -x|--x|--gui)
        GUI=
        ;;
    --k*)
        KERN=$optarg
        ;;
    --i*)
        IMAGE=$optarg
        ;;
    --r*)
        RAMFS=$optarg
        ;;
    --fdt*|--dtb*)
        DTB=$optarg
        ;;
    --m*)
        MEMORY=$optarg
        ;;
    *)
        echo "${0}: Invalid argument \"$option\""
        usage
        exit 1
        ;;
    esac
done
 
if [[ -z $KERN || -z $IMAGE  || -z $RAMFS || -z $DTB ]]; then
  usage
fi

if [[ ! -f $KERN ]]; then
  echo "Kernel $KERN not found"
  exit 1
fi

if [[ ! -f $IMAGE ]]; then
  echo "Filesystem image $IMAGE not found"
  exit 1
fi

if [[ ! -f $RAMFS ]]; then
  echo "Initramfs $RAMFS not found"
  exit 1
fi

if [[ ! -f $DTB ]]; then
  echo "dtb $DTB not found"
  exit 1
fi
 
qemu-system-arm $GUI -machine vexpress-a15 -m $MEMORY -nographic -net nic -net user \
    -append "console=ttyAMA0,115200n8 rw root=/dev/mmcblk0p3 rootwait physmap.enabled=0" \
    -kernel $KERN  -initrd $RAMFS  -sd  $IMAGE -dtb $DTB
