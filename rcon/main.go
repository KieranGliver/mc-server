package main

import (
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"os"
)

type RconPacket struct {
	requestID  int32
	packetType int32
	payload    string
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Requires at least one argument")
		return
	}
	command := os.Args[1]
	conn, err := net.Dial("tcp", "localhost:25575")
	if err != nil {
		fmt.Println("Failed to connect: ", err)
		os.Exit(1)
	}
	defer conn.Close()
	loginPacket := buildRconPacket(1, 3, "minecraft")
	_, err = conn.Write(loginPacket)
	if err != nil {
		fmt.Println("Failed to write login request: ", err)
		os.Exit(1)
	}
	resPacket, err := readRconPacket(conn)
	if err != nil {
		fmt.Println("Failed to read login response: ", err)
		os.Exit(1)
	}
	if resPacket.requestID == -1 {
		fmt.Println("Incorrect RCON password")
		os.Exit(1)
	}

	commandPacket := buildRconPacket(2, 2, command)
	_, err = conn.Write(commandPacket)
	if err != nil {
		fmt.Println("Failed to write command packet: ", err)
		os.Exit(1)
	}
	resPacket, err = readRconPacket(conn)
	if err != nil {
		fmt.Println("Failed to read command response: ", err)
		os.Exit(1)
	}
	if resPacket.requestID == 2 && resPacket.packetType == 0 {
		fmt.Println(resPacket.payload)
	} else {
		fmt.Println("Received unexpected packet requestID or packet type")
		os.Exit(1)
	}

}

func buildRconPacket(requestID int32, packetType int32, payload string) []byte {
	var remainingPacketLen int32 = int32(10 + len(payload))
	data := make([]byte, 4+remainingPacketLen)
	binary.LittleEndian.PutUint32(data[0:4], uint32(remainingPacketLen))
	binary.LittleEndian.PutUint32(data[4:8], uint32(requestID))
	binary.LittleEndian.PutUint32(data[8:12], uint32(packetType))
	copy(data[12:], payload)
	// Last two bytes are already set as 0 (null)
	return data
}

func readRconPacket(conn net.Conn) (RconPacket, error) {
	var remainingPacketLen int32 = 0
	var requestID int32 = 0
	var packetType int32 = 0
	if err := binary.Read(conn, binary.LittleEndian, &remainingPacketLen); err != nil {
		return RconPacket{}, err
	}
	if err := binary.Read(conn, binary.LittleEndian, &requestID); err != nil {
		return RconPacket{}, err
	}
	if err := binary.Read(conn, binary.LittleEndian, &packetType); err != nil {
		return RconPacket{}, err
	}
	payload := make([]byte, remainingPacketLen-10)
	if _, err := io.ReadFull(conn, payload); err != nil {
		return RconPacket{}, err
	}
	padding := make([]byte, 2)
	if _, err := io.ReadFull(conn, padding); err != nil {
		return RconPacket{}, err
	}
	return RconPacket{
		requestID:  requestID,
		packetType: packetType,
		payload:    string(payload),
	}, nil
}
