#!/bin/bash

echo "=================================================================================================================================================="
echo "Validación Práctica 5 - Virtualización y Almacenamiento"
echo "=================================================================================================================================================="

# Variables
mv=mvp5
RED_1="Cluster"
RED_2="Almacenamiento"
RED_LIBVIRT="Cluster"
IP_INICIO_ESPERADA="192.168.140.2"
IP_FINAL_ESPERADA="192.168.140.149"

# Tarea 1: Creación de red NAT CLuster

echo "Tarea 1: Creacion de la red NAT $RED_1"
echo "Comprobando que existe la red NAT $RED_1..."
virsh net-list --all | grep -q "$RED_1" && echo "Existe la red $RED_1" || echo "La red $RED_1 no existe en el sistema"

echo " "
echo "Comprobando que se inicia automáticamente la red $RED_1..."
if [ "$(virsh net-list --all | grep $RED_1 | tr -s ' ' | cut -d ' ' -f 4)" = "si" ]; then
    echo "La red $RED_1 se inicia automáticamente"
else
    echo "La red $RED_1 no se activa automáticamente"
fi

echo " "
echo "Comprobando si el rango de direcciones se encuentra entre 192.168.140.2 – 192.168.140.149..."


DHCP_BLOQUE=$(virsh net-dumpxml "$RED_LIBVIRT" | awk '/<dhcp>/,/<\/dhcp>/')
IP_INICIO_REAL=$(echo "$DHCP_BLOQUE" | grep -oP "<range start='\K[^']+")
IP_FINAL_REAL=$(echo "$DHCP_BLOQUE" | grep -oP "end='\K[^']+")

if [ "$IP_INICIO_REAL" = "$IP_INICIO_ESPERADA" ] && [ "$IP_FINAL_REAL" = "$IP_FINAL_ESPERADA" ]; then
    echo "El rango DHCP de la red '$RED_LIBVIRT' es el esperado."
else
    echo "El rango DHCP de la red '$RED_LIBVIRT' NO es el esperado."
    echo "  - Inicio esperado: $IP_INICIO_ESPERADA, real: $IP_INICIO_REAL"
    echo "  - Final esperado:  $IP_FINAL_ESPERADA, real: $IP_FINAL_REAL"
fi

echo " "
echo "Comprobando que la máquina mvp5 tiene una dirección en el rango especificado..."
REMOTE_IP="192.168.140.65"

REMOTE_CMD='ip a | grep "192.168.140.*"'

virsh start "$mv" &> /dev/null
echo "Iniciando $mv"
sleep 90

echo "Esperando a que $mv esté lista para SSH..."

ssh "$REMOTE_IP" "$REMOTE_CMD" &> /dev/null

if [ $? -eq 0 ]; then
    echo "Se encontró una dirección IP en la subred 192.168.140.x."
else
    echo "No se encontró ninguna dirección IP en la subred 192.168.140.x."
fi

# Tarea 2: Primera interfaz de red en mvp5
echo "========================================================================================================================================="
echo "Tarea 2: Primera interfaz de red en mvp5"
echo "Comprobando que las red Cluster es de tipo virtio..."

virsh dumpxml mvp5 | grep -A 4 "source network='$RED_1'" | grep -q "model type='virtio'" && echo "La red $RED_1 es de tipo virtio" || echo "La red $RED_1 no es de tipo virtio"

echo " "
echo "Comprobando que la máquina esta definida con el nombre mvp5i1.vpd.com en el /etc/hosts del anfitrion..."
definicion_mv="mvp5i1.vpd.com"
hosts="/etc/hosts"

cat $hosts | grep -q "$definicion_mv" && echo "La máquina esta definida correctamente en el $hosts" || echo "La maquina no esta definida correctamente"

echo " "
echo "Comprobando que el ping hacia la maquina con el nombre definido en el $hosts..."
HOST="mvp5i1.vpd.com"

ping -c 1 -W 2 "$HOST" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "Conectividad: $HOST responde al ping."
else
    echo "Sin conectividad: $HOST no responde al ping."
fi

echo " "
echo "Comprobando que mvp5 puede hacer ping al exterior..."
REMOTE_CMD='ping -c 1 -W 2 www.google.com' &> /dev/null

ssh "$REMOTE_IP" "$REMOTE_CMD" &> /dev/null

if [ $? -eq 0 ]; then
    echo "Conectividad: se logra hacer ping al exterior"
else
    echo "Sin conectividad: la maquina no puede hacer ping al exterior"
fi


# Tarea 3: Creacion de la red aislada Almacenamiento
echo "========================================================================================================================================="
echo "Tarea 3: Creacion de la red aislada $RED_2"
echo "Comprobando que existe la red aislada $RED_2..."
virsh net-list --all | grep -q "$RED_2" && echo "Existe la red $RED_2" || echo "La red $RED_2 no existe en el sistema"

echo " "
echo "Comprobando que se inicia automáticamente la red $RED_2..."
if [ "$(virsh net-list --all | grep $RED_2 | tr -s ' ' | cut -d ' ' -f 4)" = "si" ]; then
    echo "La red $RED_2 se inicia automáticamente"
else
    echo "La red $RED_2 no se activa automáticamente"
fi

echo " "
echo "Comprobando que la red es de tipo aislada..."
XML_ALMACENAMIENTO=$(virsh net-dumpxml $RED_2)

if ! grep -q "forward" $XML_ALMACENAMIENTO &> /dev/null; then
	echo "La red es de tipo aislada"
elif ! grep -q "forward mode='none'" $XML_ALMACENAMIENTO &> /dev/null; then
	echo "La red es de tipo aislada"
else
	echo "La red no es de tipo aislada"
fi

echo " "
echo "Comprobando que la red no tiene DHCP..."

if ! grep -q "DHCP" $XML_ALMACENAMIENTO &> /dev/null; then
	echo "La red no tiene DHCP"
else 
	echo "La red tiene DHCP..."
fi

echo " "
echo "Comprobando en que rango opera la red..."
RANGO_ALMACENAMIENTO=$(virsh net-dumpxml $RED_2 | grep "ip address")
echo "La red opera en el siguiente rango: $RANGO_ALMACENAMIENTO"

# Tarea 4: Segunda interfaz de mvp5 conectada a Alamcenamiento
echo "========================================================================================================================================="
echo "Comprobando que la interfaz es de tipo virtio..."
virsh dumpxml mvp5 | grep -A 4 "source network='$RED_2'" | grep -q "model type='virtio'" && echo "La red $RED_2 es de tipo virtio" || echo "La red $RED_2 no es de tipo virtio"

echo " "
echo "Comprobando que esta conectada a la maquina..."
virsh dumpxml mvp5 | grep -q "Almacenamiento" && echo "La interfaz esta conectada a la maquina" || echo "La interfaz no esta conectada a la maquina"

echo " "
echo "Comprobando que la direccion ip sea 10.22.122.2..."
REMOTE_CMD="ip a | grep '10.22.122.2'"

ssh "$REMOTE_IP" "$REMOTE_CMD" &> /dev/null

if [ $? -eq 0 ]; then
    echo "La direccion ip es la correcta"
else
    echo "La direccion ip es la incorrecta"
fi

echo " "
echo "Comprobando que la máquina esta definida con el nombre mvp5i2.vpd.com en el /etc/hosts del anfitrion..."
definicion_mv="mvp5i2.vpd.com"

cat $hosts | grep -q "$definicion_mv" && echo "La máquina esta definida correctamente en el $hosts" || echo "La maquina no esta definida correctamente"

echo " "
echo "Comprobando que el ping hacia la maquina con el nombre definido en el $hosts..."
HOST="mvp5i2.vpd.com"

ping -c 1 -W 2 "$HOST" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "Conectividad: $HOST responde al ping."
else
    echo "Sin conectividad: $HOST no responde al ping."
fi

echo " "
echo "Comprobando que mvp5 puede hacer ping al exterior..."
REMOTE_CMD='ping -c 1 -W 2 10.22.122.1' &> /dev/null

ssh "$REMOTE_IP" "$REMOTE_CMD" &> /dev/null

if [ $? -eq 0 ]; then
    echo "Conectividad: se logra hacer ping al 10.22.122.1"
else
    echo "Sin conectividad: la maquina no puede hacer ping al 10.22.122.1"
fi

# Tarea 5: Tercera interfaz tipo Bridge
echo "========================================================================================================================================="
echo "Comprobando que existe una interfaz en el anfitrion conectada al bridge0..."
ip a | grep -q "bridge0" && echo "Exite una interfaz conectada a bridge0" || echo "No existe una interfaz conectada bridge0"

echo "Comprobando que se asigna una direccion de la red del anfitrion..."
REMOTE_CMD="ip a | grep '192.168.140.*'"

ssh "$REMOTE_IP" "$REMOTE_CMD" &> /dev/null

if [ $? -eq 0 ]; then
    echo "Se asigna una ip correcta"
else
    echo "No se asigna una ip correcta"
fi

echo " "
echo "Comprobando que la máquina esta definida con el nombre mvp5i3.vpd.com en el /etc/hosts del anfitrion..."
definicion_mv="mvp5i3.vpd.com"

cat $hosts | grep -q "$definicion_mv" && echo "La máquina esta definida correctamente en el $hosts" || echo "La maquina no esta definida correctamente"

echo " "
echo "Comprobando que el ping hacia la maquina con el nombre definido en el $hosts..."
HOST="mvp5i3.vpd.com"

ping -c 1 -W 2 "$HOST" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "Conectividad: $HOST responde al ping."
else
    echo "Sin conectividad: $HOST no responde al ping."
fi

echo " "
echo "Comprobando que mvp5 puede hacer ping al exterior..."
REMOTE_CMD='ping -c 1 -W 2 www.google.com' &> /dev/null

ssh "$REMOTE_IP" "$REMOTE_CMD" &> /dev/null

if [ $? -eq 0 ]; then
    echo "Conectividad: se logra hacer ping al exterior"
else
    echo "Sin conectividad: la maquina no puede hacer ping al exterior"
fi

echo " "
echo "Parando la maquina virtual..."
virsh shutdown mvp5

echo "========================================================================================================================================="
echo "SCRIPT FINALIZADO"
echo "========================================================================================================================================="
