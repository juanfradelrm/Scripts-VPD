#Tarea 5: crear un contenedor NFS para volúmenes de máquinas virtuales.

#Existe un contenedor nombrado  CONT_VOL_COMP
echo -e "\n>> Verificando que existe Storage Pool $POOL3"
virsh pool-info "$POOL3" &>/dev/null && echo "✓ Pool $POOL3 existe" || echo "X Pool $POOL3 no existe"

# Comprobar si Contenedor CONT_VOL_COMP está mapeado en /var/lib/libvirt/images/COMPARTIDO
echo -e "\n>> Verificando que $POOL3 apunta a $POOL3_PATH"
ACTUAL_PATH=$(virsh pool-dumpxml "$POOL3" 2>/dev/null | xmllint --xpath 'string(//path)' - 2>/dev/null)
[[ "$ACTUAL_PATH" == "$POOL3_PATH" ]] && echo "✓ $POOL3 está mapeado a $POOL3_PATH" || echo "X $POOL3 no está mapeado correctamente. Apunta a: $ACTUAL_PATH"

# Comprobar que CONT_VOL_COMP está configurado como tipo NFS con servidor
echo -e "\n>> Comprobando que $POOL3 está configurado como tipo NFS con servidor $NFS_SERVER y export $NFS_EXPORT2"
virsh pool-dumpxml "$POOL3" | grep -q "<source>" && virsh pool-dumpxml "$POOL3" | grep -q "host name='$NFS_SERVER'" && virsh pool-dumpxml "$POOL3" 
| grep -q "dir path='$NFS_EXPORT2'" && echo "✓ $POOL3 está configurado como NFS con servidor $NFS_SERVER y export $NFS_EXPORT2" 
|| echo "X $POOL3 no está configurado correctamente para NFS"

# Comprobar que el autostart está desactivado para el CONT_VOL_COMP 
echo -e "\n>> Comprobando que autostart está desactivado para $POOL3"
virsh pool-info "$POOL3" | tr -s " " | grep -q "Autoinicio: no" && echo "✓ Autostart está desactivado para $POOL3" || echo "X Autostart está activado para $POOL3"

# Comprobar si existe un volumen pc124_LQ1_ANFITRION1_Vol3_p3 en el contenedor CONT_VOL_COMP
echo -e "\n>> Comprobando si existe un volumen nombrado $VOLUME3 en pool $POOL3..."
virsh vol-info --pool "$POOL3" "$VOLUME3" &> /dev/null && echo "✓ $VOLUME3 existe en $POOL3" || echo "X $VOLUME3 no encontrado en $POOL3"

# Comprobar si el volumen pc124_LQ1_ANFITRION1_Vol3_p3 es de 1GB
echo -e "\n>> Comprobando si el tamaño del volumen $VOLUME3 es de 1GiB"
virsh vol-list default  --details | grep $VOLUME3 | tr -s " " | cut -d " " -f5,6 | grep -q "1,00 GiB" && echo "✓ El $VOLUME3 es de 1GiB" 
|| echo "X El $VOLUME3 no es de 1GiB"

# Comprobar si el volumen pc124_LQ1_ANFITRION1_Vol3_p3 es de formato qcow2
echo -e "\n>> Verificando tipo qcow2 del volumen $VOLUME3 en el pool $POOL3"
VOL_PATH=$(virsh vol-path --pool "$POOL3" "$VOLUME3" 2>/dev/null)
[ -n "$VOL_PATH" ] && qemu-img info "$VOL_PATH" 2>/dev/null | grep -q "file format: qcow2" && echo "✓ Volumen $VOLUME3 es qcow2" 
|| echo "X Volumen $VOLUME3 no es qcow2 o no se pudo obtener información"

# Comprobar que el volumen pc124_LQ1_ANFITRION1_Vol3_p3 aparece en la MV como vdc
echo -e "\n>> Comprobando que $VOLUME3 aparece en $VM_NAME como vdc"
virsh dumpxml "$VM_NAME" | grep -A 10 "$VOLUME3" | grep target | grep virtio | grep vdc &>/dev/null && echo "✓ $VOLUME3 aparece como vdc" ||
echo "X  $VOLUME3 no aparece como vdc"

# Comprobar que en vdc existe un sistema de archivos de tipo XFS
echo -e "\n>> Comprobando que $VM_NAME tiene sistema de archivos XFS en vdc"
ssh "$VM_USER@$VM_IP" 'blkid /dev/vdc' | grep -q 'TYPE="xfs"' && echo "✓ Sistema de archivos XFS detectado en vdc" 
|| echo "X Sistema de archivos XFS NO detectado en vdc"

# Comprobar que existe archivo test.txt en el sistema de archivos montado en vdc
echo -e "\n>> Comprobando que existe un archivo test.txt en el sistema de archivos de vdc en $VM_NAME"
ssh "$VM_USER@$VM_IP" '
  mountpoint=$(lsblk -o NAME,MOUNTPOINT | grep vdc | tr -s " " | cut -d " " -f2);
  if [ -n "$mountpoint" ] && [ -f "$mountpoint/test.txt" ]; then
    echo "✓ test.txt existe en $mountpoint";
  else
    echo "X test.txt NO existe en $mountpoint o vdc no está montado";
  fi
'








